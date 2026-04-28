/// Tests for RecoveryManager and its recovery strategies.
///
/// Covers all four recovery strategies: resumeFromCheckpoint,
/// rollbackAndRetry, skipAndContinue, and manualIntervention.
/// Also tests RecoveryResult serialization and status checks.
library;

import 'package:test/test.dart';

import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

void main() {
  group('RecoveryResult', () {
    test('isSuccessful returns true for resumed status', () {
      const result = RecoveryResult(
        runId: 'run-1',
        status: RecoveryStatus.resumed,
        message: 'Resumed ok',
      );

      expect(result.isSuccessful, isTrue);
    });

    test('isSuccessful returns true for readyForRetry status', () {
      const result = RecoveryResult(
        runId: 'run-1',
        status: RecoveryStatus.readyForRetry,
        message: 'Ready to retry',
      );

      expect(result.isSuccessful, isTrue);
    });

    test('isSuccessful returns false for failed status', () {
      const result = RecoveryResult(
        runId: 'run-1',
        status: RecoveryStatus.failed,
        message: 'Failed',
      );

      expect(result.isSuccessful, isFalse);
    });

    test('isSuccessful returns false for awaitingManual status', () {
      const result = RecoveryResult(
        runId: 'run-1',
        status: RecoveryStatus.awaitingManual,
        message: 'Awaiting manual',
      );

      expect(result.isSuccessful, isFalse);
    });

    test('toJson() serializes all fields', () {
      const result = RecoveryResult(
        runId: 'run-1',
        status: RecoveryStatus.resumed,
        resumeFromStage: 'stage-2',
        state: {'key': 'value'},
        message: 'Resumed from checkpoint',
      );

      final json = result.toJson();

      expect(json['runId'], equals('run-1'));
      expect(json['status'], equals('resumed'));
      expect(json['resumeFromStage'], equals('stage-2'));
      expect(json['state'], equals({'key': 'value'}));
      expect(json['message'], equals('Resumed from checkpoint'));
    });

    test('toJson() omits null fields', () {
      const result = RecoveryResult(
        runId: 'run-1',
        status: RecoveryStatus.failed,
      );

      final json = result.toJson();

      expect(json['runId'], equals('run-1'));
      expect(json['status'], equals('failed'));
      expect(json.containsKey('resumeFromStage'), isFalse);
      expect(json.containsKey('state'), isFalse);
      expect(json.containsKey('message'), isFalse);
    });
  });

  group('RecoveryStrategy enum', () {
    test('has all four strategies', () {
      expect(RecoveryStrategy.values, hasLength(4));
      expect(RecoveryStrategy.values, contains(RecoveryStrategy.resumeFromCheckpoint));
      expect(RecoveryStrategy.values, contains(RecoveryStrategy.rollbackAndRetry));
      expect(RecoveryStrategy.values, contains(RecoveryStrategy.skipAndContinue));
      expect(RecoveryStrategy.values, contains(RecoveryStrategy.manualIntervention));
    });
  });

  group('RecoveryStatus enum', () {
    test('has all four statuses', () {
      expect(RecoveryStatus.values, hasLength(4));
      expect(RecoveryStatus.values, contains(RecoveryStatus.resumed));
      expect(RecoveryStatus.values, contains(RecoveryStatus.readyForRetry));
      expect(RecoveryStatus.values, contains(RecoveryStatus.failed));
      expect(RecoveryStatus.values, contains(RecoveryStatus.awaitingManual));
    });
  });

  group('RecoveryManager', () {
    late InMemoryCheckpointManager checkpointManager;
    late RollbackHandler rollbackHandler;
    late ExecutionLogger logger;
    late RecoveryManager recoveryManager;
    late TestOpsPorts testPorts;

    setUp(() {
      final loggerPair = testLogger();
      logger = loggerPair.$1;
      testPorts = TestOpsPorts();
      final metricsPair = testMetrics();

      checkpointManager = InMemoryCheckpointManager();
      rollbackHandler = RollbackHandler(
        ports: testPorts.toOpsPorts(),
        logger: logger,
        metrics: metricsPair.$1,
      );
      recoveryManager = RecoveryManager(
        checkpointManager: checkpointManager,
        rollbackHandler: rollbackHandler,
        logger: logger,
      );
    });

    test('resumeFromCheckpoint with existing valid checkpoint', () async {
      // Save a valid, resumable checkpoint
      final checkpoint = Checkpoint(
        id: 'cp-1',
        runId: 'run-1',
        name: 'test-checkpoint',
        state: {'progress': 50},
        stageOutputs: {},
        lastCompletedStage: 'stage-2',
        executionState: ExecutionState.paused,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await checkpointManager.save(checkpoint);

      final context = testExecutionContext(runId: 'run-1');
      final result = await recoveryManager.recover(
        'run-1',
        RecoveryStrategy.resumeFromCheckpoint,
        context,
      );

      expect(result.status, equals(RecoveryStatus.resumed));
      expect(result.runId, equals('run-1'));
      expect(result.resumeFromStage, equals('stage-2'));
      expect(result.state, isNotNull);
      expect(result.state!['progress'], equals(50));
      expect(result.isSuccessful, isTrue);
    });

    test('resumeFromCheckpoint with no checkpoint throws PermanentOpsException',
        () async {
      final context = testExecutionContext(runId: 'run-no-cp');

      expect(
        () => recoveryManager.recover(
          'run-no-cp',
          RecoveryStrategy.resumeFromCheckpoint,
          context,
        ),
        throwsA(isA<PermanentOpsException>()),
      );
    });

    test('skipAndContinue strategy returns resumed with skip marker', () async {
      // Save a checkpoint so skip-and-continue can determine what to skip
      final checkpoint = Checkpoint(
        id: 'cp-skip-1',
        runId: 'run-skip',
        name: 'skip-checkpoint',
        state: {'data': 'preserved'},
        stageOutputs: {},
        lastCompletedStage: 'stage-1',
        executionState: ExecutionState.paused,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await checkpointManager.save(checkpoint);

      final context = testExecutionContext(runId: 'run-skip');
      final result = await recoveryManager.recover(
        'run-skip',
        RecoveryStrategy.skipAndContinue,
        context,
      );

      expect(result.status, equals(RecoveryStatus.resumed));
      expect(result.isSuccessful, isTrue);
      expect(result.resumeFromStage, equals('stage-1'));
      expect(result.state, isNotNull);
      expect(result.state!['_skipNextStage'], isTrue);
      expect(result.message, contains('skipped'));
    });

    test('manualIntervention strategy returns awaitingManual', () async {
      final context = testExecutionContext(runId: 'run-manual');
      final result = await recoveryManager.recover(
        'run-manual',
        RecoveryStrategy.manualIntervention,
        context,
      );

      expect(result.status, equals(RecoveryStatus.awaitingManual));
      expect(result.isSuccessful, isFalse);
      expect(result.runId, equals('run-manual'));
      expect(result.message, contains('manual intervention'));
    });

    test('rollbackAndRetry with no checkpoint and no stages returns readyForRetry',
        () async {
      final context = testExecutionContext(runId: 'run-rollback');
      final result = await recoveryManager.recover(
        'run-rollback',
        RecoveryStrategy.rollbackAndRetry,
        context,
      );

      expect(result.status, equals(RecoveryStatus.readyForRetry));
      expect(result.isSuccessful, isTrue);
      expect(result.message, contains('retry'));
    });
  });
}
