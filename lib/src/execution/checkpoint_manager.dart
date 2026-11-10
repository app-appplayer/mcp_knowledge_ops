/// Checkpoint Manager - Manages execution checkpoints for resumable execution.
///
/// Handles checkpoint creation, storage, and resume operations.
/// Provides InMemoryCheckpointManager for testing and
/// PersistentCheckpointManager via KvStoragePort for production.
library;

import '../models/execution_context.dart';
import '../ports/ops_port.dart';

/// Checkpoint manager interface for persistence operations.
abstract class CheckpointManager {
  /// Save a checkpoint.
  Future<Checkpoint> save(Checkpoint checkpoint);

  /// Load checkpoint by ID.
  Future<Checkpoint?> load(String checkpointId);

  /// Load latest checkpoint for a run.
  Future<Checkpoint?> loadLatest(String runId);

  /// List checkpoints for a run.
  Future<List<Checkpoint>> listForRun(
    String runId, {
    CheckpointStatus? status,
    int? limit,
  });

  /// Mark checkpoint as resumed.
  Future<void> markResumed(String checkpointId);

  /// Invalidate checkpoint.
  Future<void> invalidate(String checkpointId);

  /// Invalidate all checkpoints for a run.
  Future<void> invalidateForRun(String runId);

  /// Clean up expired checkpoints.
  Future<int> cleanupExpired({Duration? olderThan});
}

/// In-memory checkpoint manager for testing.
class InMemoryCheckpointManager implements CheckpointManager {
  final Map<String, Checkpoint> _checkpoints = {};
  final Map<String, CheckpointStatus> _statusMap = {};

  @override
  Future<Checkpoint> save(Checkpoint checkpoint) async {
    _checkpoints[checkpoint.id] = checkpoint;
    _statusMap[checkpoint.id] = CheckpointStatus.active;

    // Mark previous checkpoints as superseded
    for (final entry in _checkpoints.entries) {
      if (entry.value.runId == checkpoint.runId &&
          entry.key != checkpoint.id &&
          _statusMap[entry.key] == CheckpointStatus.active) {
        _statusMap[entry.key] = CheckpointStatus.superseded;
      }
    }

    return checkpoint;
  }

  @override
  Future<Checkpoint?> load(String checkpointId) async {
    final checkpoint = _checkpoints[checkpointId];
    if (checkpoint == null) return null;
    if (checkpoint.isExpired) {
      _statusMap[checkpointId] = CheckpointStatus.expired;
      return null;
    }
    return checkpoint;
  }

  @override
  Future<Checkpoint?> loadLatest(String runId) async {
    final candidates = _checkpoints.values
        .where((c) => c.runId == runId && !c.isExpired)
        .where((c) => _statusMap[c.id] == CheckpointStatus.active)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return candidates.isNotEmpty ? candidates.first : null;
  }

  @override
  Future<List<Checkpoint>> listForRun(
    String runId, {
    CheckpointStatus? status,
    int? limit,
  }) async {
    var results = _checkpoints.values
        .where((c) => c.runId == runId)
        .where((c) => status == null || _statusMap[c.id] == status)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (limit != null && results.length > limit) {
      results = results.take(limit).toList();
    }

    return results;
  }

  @override
  Future<void> markResumed(String checkpointId) async {
    _statusMap[checkpointId] = CheckpointStatus.resumed;
  }

  @override
  Future<void> invalidate(String checkpointId) async {
    _statusMap[checkpointId] = CheckpointStatus.invalidated;
  }

  @override
  Future<void> invalidateForRun(String runId) async {
    for (final entry in _checkpoints.entries) {
      if (entry.value.runId == runId) {
        _statusMap[entry.key] = CheckpointStatus.invalidated;
      }
    }
  }

  @override
  Future<int> cleanupExpired({Duration? olderThan}) async {
    final cutoff = DateTime.now().subtract(olderThan ?? Duration.zero);
    var count = 0;

    _checkpoints.removeWhere((id, checkpoint) {
      if (checkpoint.createdAt.isBefore(cutoff) || checkpoint.isExpired) {
        count++;
        _statusMap.remove(id);
        return true;
      }
      return false;
    });

    return count;
  }

  /// Get checkpoint status.
  CheckpointStatus? getStatus(String checkpointId) {
    return _statusMap[checkpointId];
  }

  /// Clear all checkpoints.
  void clear() {
    _checkpoints.clear();
    _statusMap.clear();
  }
}

/// Persistent checkpoint manager using KvStoragePort.
///
/// Stores checkpoints and their status in key-value storage for
/// durable, cross-session checkpoint persistence.
/// Key conventions:
///   - `{namespace}:{id}` for checkpoint data
///   - `{namespace}:status:{id}` for checkpoint status
///   - `{namespace}:run:{runId}` for run index (list of checkpoint IDs)
class PersistentCheckpointManager implements CheckpointManager {
  /// Key-value storage port.
  final KvStoragePort storage;

  /// Key namespace prefix.
  final String namespace;

  PersistentCheckpointManager({
    required this.storage,
    this.namespace = 'checkpoints',
  });

  String _key(String id) => '$namespace:$id';
  String _statusKey(String id) => '$namespace:status:$id';
  String _runKey(String runId) => '$namespace:run:$runId';

  @override
  Future<Checkpoint> save(Checkpoint checkpoint) async {
    await storage.set(_key(checkpoint.id), checkpoint.toJson());
    await storage.set(_statusKey(checkpoint.id), CheckpointStatus.active.name);

    // Update run index
    final runIndex = await _getRunIndex(checkpoint.runId);
    if (!runIndex.contains(checkpoint.id)) {
      runIndex.add(checkpoint.id);
      await storage.set(_runKey(checkpoint.runId), runIndex);
    }

    // Mark previous checkpoints as superseded
    for (final existingId in runIndex) {
      if (existingId != checkpoint.id) {
        final existingStatus = await _getStatus(existingId);
        if (existingStatus == CheckpointStatus.active) {
          await storage.set(
              _statusKey(existingId), CheckpointStatus.superseded.name);
        }
      }
    }

    return checkpoint;
  }

  @override
  Future<Checkpoint?> load(String checkpointId) async {
    final data = await storage.get(_key(checkpointId));
    if (data == null) return null;

    final checkpoint = Checkpoint.fromJson(data as Map<String, dynamic>);
    if (checkpoint.isExpired) {
      await storage.set(
          _statusKey(checkpointId), CheckpointStatus.expired.name);
      return null;
    }
    return checkpoint;
  }

  @override
  Future<Checkpoint?> loadLatest(String runId) async {
    final runIndex = await _getRunIndex(runId);
    Checkpoint? latest;

    // Iterate in reverse (newest first) to find the latest active checkpoint
    for (var i = runIndex.length - 1; i >= 0; i--) {
      final id = runIndex[i];
      final status = await _getStatus(id);
      if (status != CheckpointStatus.active) continue;

      final checkpoint = await load(id);
      if (checkpoint != null) {
        latest = checkpoint;
        break; // Since we iterate newest first, first match is latest
      }
    }

    return latest;
  }

  @override
  Future<List<Checkpoint>> listForRun(
    String runId, {
    CheckpointStatus? status,
    int? limit,
  }) async {
    final runIndex = await _getRunIndex(runId);
    final results = <Checkpoint>[];

    for (final id in runIndex) {
      if (status != null) {
        final cpStatus = await _getStatus(id);
        if (cpStatus != status) continue;
      }

      final data = await storage.get(_key(id));
      if (data != null) {
        results.add(Checkpoint.fromJson(data as Map<String, dynamic>));
      }
    }

    // Sort by creation time (newest first)
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (limit != null && results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }

  @override
  Future<void> markResumed(String checkpointId) async {
    await storage.set(_statusKey(checkpointId), CheckpointStatus.resumed.name);
  }

  @override
  Future<void> invalidate(String checkpointId) async {
    await storage.set(
        _statusKey(checkpointId), CheckpointStatus.invalidated.name);
  }

  @override
  Future<void> invalidateForRun(String runId) async {
    final runIndex = await _getRunIndex(runId);
    for (final id in runIndex) {
      await storage.set(_statusKey(id), CheckpointStatus.invalidated.name);
    }
  }

  @override
  Future<int> cleanupExpired({Duration? olderThan}) async {
    final cutoff = DateTime.now().subtract(olderThan ?? Duration.zero);
    var count = 0;

    // Find all checkpoint keys using prefix scan
    final allKeys = await storage.keys(prefix: '$namespace:');
    final checkpointKeys = allKeys
        .where((k) => !k.contains(':status:') && !k.contains(':run:'))
        .toList();

    for (final key in checkpointKeys) {
      final data = await storage.get(key);
      if (data == null) continue;

      final checkpoint = Checkpoint.fromJson(data as Map<String, dynamic>);
      if (checkpoint.isExpired || checkpoint.createdAt.isBefore(cutoff)) {
        // Remove checkpoint data and status
        await storage.remove(key);
        await storage.remove(_statusKey(checkpoint.id));

        // Remove from run index
        final runIndex = await _getRunIndex(checkpoint.runId);
        runIndex.remove(checkpoint.id);
        if (runIndex.isEmpty) {
          await storage.remove(_runKey(checkpoint.runId));
        } else {
          await storage.set(_runKey(checkpoint.runId), runIndex);
        }

        count++;
      }
    }

    return count;
  }

  Future<List<String>> _getRunIndex(String runId) async {
    final data = await storage.get(_runKey(runId));
    if (data == null) return [];
    return List<String>.from(data as List);
  }

  Future<CheckpointStatus?> _getStatus(String checkpointId) async {
    final statusStr = await storage.get(_statusKey(checkpointId));
    if (statusStr == null) return null;
    return CheckpointStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => CheckpointStatus.active,
    );
  }
}

/// Checkpoint exception.
class CheckpointException implements Exception {
  final String message;
  final String? checkpointId;

  CheckpointException(this.message, {this.checkpointId});

  @override
  String toString() => 'CheckpointException: $message';
}
