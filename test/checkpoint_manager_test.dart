/// CheckpointManager Tests - Tests for checkpoint persistence and lifecycle.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

/// Helper to create a test checkpoint with required fields.
Checkpoint testCheckpoint({
  String id = 'cp-1',
  String runId = 'run-1',
  String name = 'test-checkpoint',
  Map<String, dynamic> state = const {},
  DateTime? createdAt,
  DateTime? expiresAt,
  ExecutionState executionState = ExecutionState.paused,
  Map<String, dynamic>? metadata,
}) {
  return Checkpoint(
    id: id,
    runId: runId,
    name: name,
    state: state,
    stageOutputs: const {},
    createdAt: createdAt ?? DateTime.now(),
    expiresAt: expiresAt,
    executionState: executionState,
    metadata: metadata,
  );
}

void main() {
  // ═══════════════════════════════════════════════════════════════
  // InMemoryCheckpointManager
  // ═══════════════════════════════════════════════════════════════

  group('InMemoryCheckpointManager', () {
    late InMemoryCheckpointManager manager;

    setUp(() {
      manager = InMemoryCheckpointManager();
    });

    test('save stores checkpoint', () async {
      final cp = testCheckpoint();
      final saved = await manager.save(cp);
      expect(saved.id, equals('cp-1'));

      final loaded = await manager.load('cp-1');
      expect(loaded, isNotNull);
      expect(loaded!.id, equals('cp-1'));
    });

    test('load returns null for nonexistent checkpoint', () async {
      final result = await manager.load('nonexistent');
      expect(result, isNull);
    });

    test('load returns null for expired checkpoint', () async {
      final cp = testCheckpoint(
        id: 'cp-expired',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      await manager.save(cp);

      final loaded = await manager.load('cp-expired');
      expect(loaded, isNull);
    });

    test('loadLatest returns most recent active checkpoint for runId',
        () async {
      final cp1 = testCheckpoint(
        id: 'cp-old',
        runId: 'run-1',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      await manager.save(cp1);

      final cp2 = testCheckpoint(
        id: 'cp-new',
        runId: 'run-1',
        createdAt: DateTime.now(),
      );
      await manager.save(cp2);

      final latest = await manager.loadLatest('run-1');
      expect(latest, isNotNull);
      expect(latest!.id, equals('cp-new'));
    });

    test('loadLatest returns null when no active checkpoints exist',
        () async {
      final result = await manager.loadLatest('nonexistent-run');
      expect(result, isNull);
    });

    test('save marks previous checkpoints as superseded', () async {
      final cp1 = testCheckpoint(id: 'cp-1', runId: 'run-1');
      await manager.save(cp1);
      expect(manager.getStatus('cp-1'), equals(CheckpointStatus.active));

      final cp2 = testCheckpoint(id: 'cp-2', runId: 'run-1');
      await manager.save(cp2);

      expect(manager.getStatus('cp-1'), equals(CheckpointStatus.superseded));
      expect(manager.getStatus('cp-2'), equals(CheckpointStatus.active));
    });

    test('listForRun returns all checkpoints for run', () async {
      await manager.save(testCheckpoint(id: 'cp-1', runId: 'run-1'));
      await manager.save(testCheckpoint(id: 'cp-2', runId: 'run-1'));
      await manager.save(testCheckpoint(id: 'cp-3', runId: 'run-2'));

      final run1Checkpoints = await manager.listForRun('run-1');
      expect(run1Checkpoints.length, equals(2));
    });

    test('listForRun with status filter', () async {
      await manager.save(testCheckpoint(id: 'cp-1', runId: 'run-1'));
      await manager.save(testCheckpoint(id: 'cp-2', runId: 'run-1'));

      // cp-1 is superseded after cp-2 is saved
      final active = await manager.listForRun(
        'run-1',
        status: CheckpointStatus.active,
      );
      expect(active.length, equals(1));
      expect(active.first.id, equals('cp-2'));

      final superseded = await manager.listForRun(
        'run-1',
        status: CheckpointStatus.superseded,
      );
      expect(superseded.length, equals(1));
      expect(superseded.first.id, equals('cp-1'));
    });

    test('listForRun with limit', () async {
      await manager.save(testCheckpoint(
        id: 'cp-1',
        runId: 'run-1',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ));
      await manager.save(testCheckpoint(
        id: 'cp-2',
        runId: 'run-1',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ));
      await manager.save(testCheckpoint(
        id: 'cp-3',
        runId: 'run-1',
        createdAt: DateTime.now(),
      ));

      final limited = await manager.listForRun('run-1', limit: 2);
      expect(limited.length, equals(2));
    });

    test('markResumed changes status', () async {
      await manager.save(testCheckpoint(id: 'cp-1'));
      expect(manager.getStatus('cp-1'), equals(CheckpointStatus.active));

      await manager.markResumed('cp-1');
      expect(manager.getStatus('cp-1'), equals(CheckpointStatus.resumed));
    });

    test('invalidate changes status to invalidated', () async {
      await manager.save(testCheckpoint(id: 'cp-1'));
      await manager.invalidate('cp-1');
      expect(manager.getStatus('cp-1'), equals(CheckpointStatus.invalidated));
    });

    test('invalidateForRun invalidates all checkpoints for run', () async {
      await manager.save(testCheckpoint(id: 'cp-1', runId: 'run-1'));
      await manager.save(testCheckpoint(id: 'cp-2', runId: 'run-1'));
      await manager.save(testCheckpoint(id: 'cp-3', runId: 'run-2'));

      await manager.invalidateForRun('run-1');

      expect(
          manager.getStatus('cp-1'), equals(CheckpointStatus.invalidated));
      expect(
          manager.getStatus('cp-2'), equals(CheckpointStatus.invalidated));
      // run-2 should remain unaffected
      expect(manager.getStatus('cp-3'), equals(CheckpointStatus.active));
    });

    test('cleanupExpired removes old checkpoints', () async {
      final old = testCheckpoint(
        id: 'cp-old',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      await manager.save(old);

      final recent = testCheckpoint(
        id: 'cp-recent',
        createdAt: DateTime.now(),
      );
      await manager.save(recent);

      final count = await manager.cleanupExpired(
        olderThan: const Duration(days: 5),
      );
      expect(count, equals(1));

      final loaded = await manager.load('cp-old');
      expect(loaded, isNull);

      final recentLoaded = await manager.load('cp-recent');
      expect(recentLoaded, isNotNull);
    });

    test('cleanupExpired removes expired checkpoints', () async {
      final expired = testCheckpoint(
        id: 'cp-expired',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      await manager.save(expired);

      final count = await manager.cleanupExpired();
      expect(count, equals(1));
    });

    test('getStatus returns null for unknown checkpoint', () {
      expect(manager.getStatus('nonexistent'), isNull);
    });

    test('clear removes all checkpoints', () async {
      await manager.save(testCheckpoint(id: 'cp-1'));
      await manager.save(testCheckpoint(id: 'cp-2'));

      manager.clear();

      expect(await manager.load('cp-1'), isNull);
      expect(await manager.load('cp-2'), isNull);
      expect(manager.getStatus('cp-1'), isNull);
      expect(manager.getStatus('cp-2'), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // PersistentCheckpointManager
  // ═══════════════════════════════════════════════════════════════

  group('PersistentCheckpointManager', () {
    late MockKvStorage storage;
    late PersistentCheckpointManager manager;

    setUp(() {
      storage = MockKvStorage();
      manager = PersistentCheckpointManager(
        storage: storage,
        namespace: 'test-cp',
      );
    });

    test('save stores checkpoint via KvStoragePort', () async {
      final cp = testCheckpoint(id: 'pcp-1', runId: 'run-1');
      await manager.save(cp);

      final loaded = await manager.load('pcp-1');
      expect(loaded, isNotNull);
      expect(loaded!.id, equals('pcp-1'));
    });

    test('load returns null for nonexistent checkpoint', () async {
      final result = await manager.load('nonexistent');
      expect(result, isNull);
    });

    test('load returns null for expired checkpoint', () async {
      final cp = testCheckpoint(
        id: 'pcp-expired',
        runId: 'run-1',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      await manager.save(cp);

      final loaded = await manager.load('pcp-expired');
      expect(loaded, isNull);
    });

    test('loadLatest returns most recent active checkpoint', () async {
      final cp1 = testCheckpoint(
        id: 'pcp-old',
        runId: 'run-1',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      await manager.save(cp1);

      final cp2 = testCheckpoint(
        id: 'pcp-new',
        runId: 'run-1',
        createdAt: DateTime.now(),
      );
      await manager.save(cp2);

      final latest = await manager.loadLatest('run-1');
      expect(latest, isNotNull);
      expect(latest!.id, equals('pcp-new'));
    });

    test('loadLatest returns null for nonexistent run', () async {
      final result = await manager.loadLatest('nonexistent-run');
      expect(result, isNull);
    });

    test('save marks previous checkpoints as superseded', () async {
      await manager.save(testCheckpoint(id: 'pcp-1', runId: 'run-1'));
      await manager.save(testCheckpoint(id: 'pcp-2', runId: 'run-1'));

      // pcp-1 should be superseded, pcp-2 should be active
      final latest = await manager.loadLatest('run-1');
      expect(latest, isNotNull);
      expect(latest!.id, equals('pcp-2'));
    });

    test('listForRun returns checkpoints for run', () async {
      await manager.save(testCheckpoint(id: 'pcp-1', runId: 'run-1'));
      await manager.save(testCheckpoint(id: 'pcp-2', runId: 'run-1'));
      await manager.save(testCheckpoint(id: 'pcp-3', runId: 'run-2'));

      final results = await manager.listForRun('run-1');
      expect(results.length, equals(2));
    });

    test('markResumed changes checkpoint status', () async {
      await manager.save(testCheckpoint(id: 'pcp-1', runId: 'run-1'));
      await manager.markResumed('pcp-1');

      // After marking resumed, loadLatest should not find it as active
      final latest = await manager.loadLatest('run-1');
      expect(latest, isNull);
    });

    test('invalidateForRun invalidates all checkpoints for run', () async {
      await manager.save(testCheckpoint(id: 'pcp-1', runId: 'run-1'));
      await manager.save(testCheckpoint(id: 'pcp-2', runId: 'run-1'));

      await manager.invalidateForRun('run-1');

      final latest = await manager.loadLatest('run-1');
      expect(latest, isNull);
    });

    test('invalidate changes single checkpoint status', () async {
      await manager.save(testCheckpoint(id: 'pcp-1', runId: 'run-1'));
      await manager.invalidate('pcp-1');

      final latest = await manager.loadLatest('run-1');
      expect(latest, isNull);
    });

    test('cleanupExpired removes old checkpoints', () async {
      final old = testCheckpoint(
        id: 'pcp-old',
        runId: 'run-1',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      await manager.save(old);

      final recent = testCheckpoint(
        id: 'pcp-recent',
        runId: 'run-2',
        createdAt: DateTime.now(),
      );
      await manager.save(recent);

      final count = await manager.cleanupExpired(
        olderThan: const Duration(days: 5),
      );
      expect(count, equals(1));

      final loaded = await manager.load('pcp-old');
      expect(loaded, isNull);

      final recentLoaded = await manager.load('pcp-recent');
      expect(recentLoaded, isNotNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Checkpoint model
  // ═══════════════════════════════════════════════════════════════

  group('Checkpoint', () {
    test('isExpired returns false when no expiresAt set', () {
      final cp = testCheckpoint();
      expect(cp.isExpired, isFalse);
    });

    test('isExpired returns true when past expiresAt', () {
      final cp = testCheckpoint(
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(cp.isExpired, isTrue);
    });

    test('isExpired returns false when before expiresAt', () {
      final cp = testCheckpoint(
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(cp.isExpired, isFalse);
    });

    test('isResumable returns true for paused non-expired checkpoint', () {
      final cp = testCheckpoint(executionState: ExecutionState.paused);
      expect(cp.isResumable, isTrue);
    });

    test('isResumable returns true for waitingReview', () {
      final cp = testCheckpoint(executionState: ExecutionState.waitingReview);
      expect(cp.isResumable, isTrue);
    });

    test('isResumable returns true for waitingApproval', () {
      final cp =
          testCheckpoint(executionState: ExecutionState.waitingApproval);
      expect(cp.isResumable, isTrue);
    });

    test('isResumable returns false for completed checkpoint', () {
      final cp = testCheckpoint(executionState: ExecutionState.completed);
      expect(cp.isResumable, isFalse);
    });

    test('isResumable returns false for expired checkpoint', () {
      final cp = testCheckpoint(
        executionState: ExecutionState.paused,
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(cp.isResumable, isFalse);
    });

    test('toJson serializes correctly', () {
      final now = DateTime(2024, 6, 15, 12, 0, 0);
      final cp = Checkpoint(
        id: 'cp-json',
        runId: 'run-1',
        name: 'json-test',
        state: {'key': 'value'},
        stageOutputs: const {},
        createdAt: now,
        executionState: ExecutionState.paused,
        metadata: {'info': 'test'},
      );

      final json = cp.toJson();
      expect(json['id'], equals('cp-json'));
      expect(json['runId'], equals('run-1'));
      expect(json['name'], equals('json-test'));
      expect(json['state'], equals({'key': 'value'}));
      expect(json['executionState'], equals('paused'));
      expect(json['metadata'], equals({'info': 'test'}));
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'id': 'cp-from-json',
        'runId': 'run-1',
        'name': 'from-json',
        'state': {'key': 'value'},
        'stageOutputs': <String, dynamic>{},
        'executionState': 'running',
        'createdAt': '2024-06-15T12:00:00.000',
        'schemaVersion': '1.0.0',
      };

      final cp = Checkpoint.fromJson(json);
      expect(cp.id, equals('cp-from-json'));
      expect(cp.runId, equals('run-1'));
      expect(cp.name, equals('from-json'));
      expect(cp.state['key'], equals('value'));
      expect(cp.executionState, equals(ExecutionState.running));
    });

    test('toJson -> fromJson roundtrip', () {
      final original = Checkpoint(
        id: 'cp-roundtrip',
        runId: 'run-1',
        name: 'roundtrip',
        state: {'data': 42},
        stageOutputs: const {},
        createdAt: DateTime(2024, 6, 15),
        executionState: ExecutionState.paused,
      );

      final json = original.toJson();
      final restored = Checkpoint.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.runId, equals(original.runId));
      expect(restored.name, equals(original.name));
      expect(restored.state['data'], equals(42));
      expect(restored.executionState, equals(original.executionState));
    });
  });
}
