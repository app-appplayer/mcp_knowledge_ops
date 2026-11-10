/// Rollback Handler - Orchestrates rollback of completed pipeline stages.
///
/// Iterates through completed stages in reverse order and executes
/// logical rollback operations via [KvStoragePort].
library;

import '../models/execution_context.dart';
import '../observability/logger.dart';
import '../observability/metrics_collector.dart';
import '../ports/ops_port.dart';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/// Configuration for rollback behavior.
class RollbackConfig {
  /// Whether rollback is enabled.
  final bool enabled;

  /// Specific stages to rollback (empty means all completed stages).
  final List<String> rollbackStages;

  /// Whether to automatically rollback on failure.
  final bool autoRollback;

  /// Maximum time allowed for the entire rollback operation.
  final Duration rollbackTimeout;

  const RollbackConfig({
    this.enabled = true,
    this.rollbackStages = const [],
    this.autoRollback = false,
    this.rollbackTimeout = const Duration(minutes: 30),
  });

  /// Copy with modifications.
  RollbackConfig copyWith({
    bool? enabled,
    List<String>? rollbackStages,
    bool? autoRollback,
    Duration? rollbackTimeout,
  }) {
    return RollbackConfig(
      enabled: enabled ?? this.enabled,
      rollbackStages: rollbackStages ?? this.rollbackStages,
      autoRollback: autoRollback ?? this.autoRollback,
      rollbackTimeout: rollbackTimeout ?? this.rollbackTimeout,
    );
  }
}

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// Status of a rollback operation.
enum RollbackStatus {
  /// All stages rolled back successfully.
  success,

  /// One or more stage rollbacks failed.
  failed,

  /// Rollback was skipped (not enabled or no stages to rollback).
  skipped,

  /// An unexpected error occurred during rollback.
  error,
}

/// Result of rolling back a single stage.
class RollbackStageResult {
  /// Stage that was rolled back.
  final String stageId;

  /// Whether the rollback for this stage succeeded.
  final bool success;

  /// Descriptive message (error detail if failed, confirmation if success).
  final String? message;

  const RollbackStageResult({
    required this.stageId,
    required this.success,
    this.message,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'stageId': stageId,
        'success': success,
        if (message != null) 'message': message,
      };
}

/// Aggregate result of a rollback operation across all stages.
class RollbackResult {
  /// Overall status.
  final RollbackStatus status;

  /// Per-stage rollback results.
  final List<RollbackStageResult> stageResults;

  /// Human-readable summary message.
  final String? message;

  const RollbackResult({
    required this.status,
    required this.stageResults,
    this.message,
  });

  /// Whether the rollback completed without any failures.
  bool get isSuccessful => status == RollbackStatus.success;

  /// Stages that failed rollback.
  List<RollbackStageResult> get failedStages =>
      stageResults.where((r) => !r.success).toList();

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'status': status.name,
        'stageResults': stageResults.map((r) => r.toJson()).toList(),
        if (message != null) 'message': message,
      };
}

// ---------------------------------------------------------------------------
// Rollback handler
// ---------------------------------------------------------------------------

/// Orchestrates rollback of completed pipeline stages.
///
/// For each completed stage (processed in reverse order), the handler
/// records a logical rollback entry in [KvStoragePort] using the key
/// convention `rollback:{type}:{id}`. This allows downstream systems
/// to detect and compensate for rolled-back operations.
class RollbackHandler {
  final OpsPorts _ports;
  final ExecutionLogger _logger;
  final MetricsCollector _metrics;

  /// Creates a [RollbackHandler].
  ///
  /// Requires [OpsPorts] for storage access, [ExecutionLogger] for
  /// structured logging, and [MetricsCollector] for observability.
  RollbackHandler({
    required OpsPorts ports,
    required ExecutionLogger logger,
    required MetricsCollector metrics,
  })  : _ports = ports,
        _logger = logger,
        _metrics = metrics;

  /// Execute rollback for completed stages.
  ///
  /// Iterates [stageOutputs] keys in reverse order, determines whether
  /// each stage should be rolled back (based on [config]), and performs
  /// a logical rollback via the KV storage port.
  ///
  /// Returns a [RollbackResult] describing the outcome.
  Future<RollbackResult> rollback(
    ExecutionContext context,
    Map<String, dynamic> stageOutputs,
    RollbackConfig config,
  ) async {
    if (!config.enabled) {
      _logger.info('Rollback skipped: not enabled', {
        'runId': context.runId,
      });
      return const RollbackResult(
        status: RollbackStatus.skipped,
        stageResults: [],
        message: 'Rollback is not enabled',
      );
    }

    final stagesToRollback = _resolveStagesToRollback(stageOutputs, config);

    if (stagesToRollback.isEmpty) {
      _logger.info('Rollback skipped: no stages to rollback', {
        'runId': context.runId,
      });
      return const RollbackResult(
        status: RollbackStatus.skipped,
        stageResults: [],
        message: 'No stages to rollback',
      );
    }

    _logger.info('Starting rollback', {
      'runId': context.runId,
      'stageCount': stagesToRollback.length,
      'stages': stagesToRollback,
    });

    final timer = _metrics.timer('ops.rollback.duration', {
      'runId': context.runId,
    });

    final stageResults = <RollbackStageResult>[];
    var hasFailures = false;

    try {
      // Process stages in reverse order
      for (final stageId in stagesToRollback.reversed) {
        final result = await _rollbackStage(
          context,
          stageId,
          stageOutputs[stageId],
          config,
        );
        stageResults.add(result);

        if (!result.success) {
          hasFailures = true;
          _logger.warn('Stage rollback failed', {
            'runId': context.runId,
            'stageId': stageId,
            'message': result.message,
          });
        }
      }

      timer.observeDuration();

      final status =
          hasFailures ? RollbackStatus.failed : RollbackStatus.success;
      final failedCount = stageResults.where((r) => !r.success).length;

      _metrics.increment('ops.rollback.total', 1, {
        'runId': context.runId,
        'status': status.name,
      });

      final message = hasFailures
          ? 'Rollback completed with $failedCount failure(s) '
              'out of ${stageResults.length} stage(s)'
          : 'Rollback completed successfully for '
              '${stageResults.length} stage(s)';

      _logger.info(message, {
        'runId': context.runId,
        'status': status.name,
      });

      return RollbackResult(
        status: status,
        stageResults: stageResults,
        message: message,
      );
    } catch (e, stack) {
      timer.observeDuration();

      _logger.error(
        'Unexpected error during rollback',
        error: e,
        context: {'stackTrace': stack.toString()},
      );

      _metrics.increment('ops.rollback.errors', 1, {
        'runId': context.runId,
      });

      return RollbackResult(
        status: RollbackStatus.error,
        stageResults: stageResults,
        message: 'Rollback failed with unexpected error: $e',
      );
    }
  }

  /// Determine which stages to rollback based on configuration.
  List<String> _resolveStagesToRollback(
    Map<String, dynamic> stageOutputs,
    RollbackConfig config,
  ) {
    if (config.rollbackStages.isNotEmpty) {
      // Only rollback explicitly listed stages that have outputs
      return config.rollbackStages.where(stageOutputs.containsKey).toList();
    }
    // Rollback all stages that produced output
    return stageOutputs.keys.toList();
  }

  /// Rollback a single stage by recording a logical rollback entry.
  Future<RollbackStageResult> _rollbackStage(
    ExecutionContext context,
    String stageId,
    dynamic stageOutput,
    RollbackConfig config,
  ) async {
    final kvStorage = _ports.kvStorage;

    try {
      final stageTimer = _metrics.timer('ops.rollback.stage.duration', {
        'runId': context.runId,
        'stageId': stageId,
      });

      // Determine type-specific rollback key and status
      final rollbackType = _resolveRollbackType(stageId, stageOutput);
      final rollbackKey = 'rollback:${rollbackType.keySegment}:$stageId';
      final rollbackData = <String, dynamic>{
        'runId': context.runId,
        'stageId': stageId,
        'rolledBackAt': DateTime.now().toIso8601String(),
        'originalOutput': stageOutput,
        'status': rollbackType.status,
      };

      await kvStorage.set(rollbackKey, rollbackData);

      // Also record an index entry for the run
      final indexKey = 'rollback:index:${context.runId}';
      final existingIndex = await kvStorage.get(indexKey);
      final indexList = (existingIndex is List)
          ? List<String>.from(existingIndex)
          : <String>[];

      if (!indexList.contains(stageId)) {
        indexList.add(stageId);
        await kvStorage.set(indexKey, indexList);
      }

      stageTimer.observeDuration();

      _logger.info('Stage rolled back successfully', {
        'runId': context.runId,
        'stageId': stageId,
        'rollbackKey': rollbackKey,
      });

      return RollbackStageResult(
        stageId: stageId,
        success: true,
        message: 'Logical rollback recorded (${rollbackType.status})',
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to rollback stage: $stageId',
        error: e,
        context: {'stackTrace': stack.toString()},
      );

      return RollbackStageResult(
        stageId: stageId,
        success: false,
        message: 'Rollback failed: $e',
      );
    }
  }

  /// Resolve the type-specific rollback key segment and status
  /// based on stage semantics and output content.
  _RollbackType _resolveRollbackType(String stageId, dynamic stageOutput) {
    // Evidence-related stages use 'retracted' status
    if (stageId.contains('evidence') || stageId.contains('ingest')) {
      return const _RollbackType(keySegment: 'evidence', status: 'retracted');
    }

    // Bundle-related stages use 'invalid' status
    if (stageId.contains('bundle') || stageId.contains('build')) {
      return const _RollbackType(keySegment: 'bundle', status: 'invalid');
    }

    // Publish-related stages use 'unpublished' status
    if (stageId.contains('publish') || stageId.contains('release')) {
      return const _RollbackType(keySegment: 'publish', status: 'unpublished');
    }

    // Default: generic stage rollback
    return const _RollbackType(keySegment: 'stage', status: 'rolled_back');
  }
}

/// Type-specific rollback metadata.
class _RollbackType {
  /// Key segment for the KV storage key convention.
  final String keySegment;

  /// Status value to record (e.g., 'retracted', 'invalid', 'unpublished').
  final String status;

  const _RollbackType({required this.keySegment, required this.status});
}
