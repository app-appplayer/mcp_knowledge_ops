// Recovery strategies and rollback failures.

import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

class _ThrowingKv extends MockKvStorage {
  @override
  Future<void> set(String key, dynamic value) async =>
      throw StateError('kv down');
}

class _ThrowingSink implements MetricSink {
  @override
  void record(Metric metric) {
    if (metric.name == 'ops.rollback.total') throw StateError('sink down');
  }

  @override
  Future<void> flush() async {}
  @override
  Future<void> close() async {}
}

/// Returns whatever checkpoint it is given, expired or not.
class _FixedCheckpoints extends InMemoryCheckpointManager {
  _FixedCheckpoints(this.latest);
  final Checkpoint? latest;
  @override
  Future<Checkpoint?> loadLatest(String runId) async => latest;
}

Checkpoint _cp({
  ExecutionState state = ExecutionState.paused,
  DateTime? expires,
  String? last,
  Map<String, StageOutput> outputs = const {},
}) =>
    Checkpoint(
      id: 'cp',
      runId: 'run-1',
      name: 'n',
      state: const {'k': 1},
      stageOutputs: outputs,
      lastCompletedStage: last,
      executionState: state,
      createdAt: DateTime.now(),
      expiresAt: expires,
    );

void main() {
  RollbackHandler handler({MockKvStorage? kv, MetricsCollector? metrics}) =>
      RollbackHandler(
          ports: TestOpsPorts(kvStorage: kv).toOpsPorts(),
          logger: testLogger().$1,
          metrics: metrics ?? testMetrics().$1);

  RecoveryManager manager(CheckpointManager cp, {RollbackHandler? rollback}) =>
      RecoveryManager(
          checkpointManager: cp,
          rollbackHandler: rollback ?? handler(),
          logger: testLogger().$1);

  group('rollback failures', () {
    test('a stage whose storage write fails is reported, not thrown', () async {
      final r = await handler(kv: _ThrowingKv())
          .rollback(testExecutionContext(), {'a': 1}, const RollbackConfig());
      expect(r.status, RollbackStatus.failed);
      expect(r.failedStages.single.message, contains('kv down'));
      expect(r.message, contains('1 failure(s) out of 1 stage(s)'));
    });

    test('an unexpected error becomes an error result', () async {
      final r = await handler(metrics: MetricsCollector(sink: _ThrowingSink()))
          .rollback(testExecutionContext(), {'a': 1}, const RollbackConfig());
      expect(r.status, RollbackStatus.error);
      expect(r.message, contains('unexpected error'));
    });

    test('stage kinds choose their record type', () async {
      final kv = MockKvStorage();
      await handler(kv: kv).rollback(
          testExecutionContext(),
          {'evidence_x': 1, 'bundle_y': 2, 'publish_z': 3, 'plain': 4},
          const RollbackConfig());
      final keys = await kv.keys(prefix: 'rollback:');
      expect(
          keys,
          containsAll([
            'rollback:evidence:evidence_x',
            'rollback:bundle:bundle_y',
            'rollback:publish:publish_z',
            'rollback:stage:plain',
          ]));
    });
  });

  group('recovery', () {
    test('resume: no checkpoint, expired, not resumable, ok', () async {
      final ctx = testExecutionContext();
      await expectLater(
          manager(_FixedCheckpoints(null))
              .recover('run-1', RecoveryStrategy.resumeFromCheckpoint, ctx),
          throwsA(isA<PermanentOpsException>()));
      await expectLater(
          manager(_FixedCheckpoints(_cp(
                  expires: DateTime.now().subtract(const Duration(hours: 1)))))
              .recover('run-1', RecoveryStrategy.resumeFromCheckpoint, ctx),
          throwsA(isA<PermanentOpsException>()));
      await expectLater(
          manager(_FixedCheckpoints(_cp(state: ExecutionState.completed)))
              .recover('run-1', RecoveryStrategy.resumeFromCheckpoint, ctx),
          throwsA(isA<PermanentOpsException>()));
      final ok = await manager(_FixedCheckpoints(_cp(last: 's1')))
          .recover('run-1', RecoveryStrategy.resumeFromCheckpoint, ctx);
      expect(ok.isSuccessful, isTrue);
      expect(ok.message, contains('after stage s1'));
      expect(ok.toJson()['resumeFromStage'], 's1');
      final noStage = await manager(_FixedCheckpoints(_cp()))
          .recover('run-1', RecoveryStrategy.resumeFromCheckpoint, ctx);
      expect(noStage.message, isNot(contains('after stage')));
    });

    test('rollback and retry: with and without a checkpoint', () async {
      final bare = testExecutionContext();
      final empty = await manager(_FixedCheckpoints(null))
          .recover('run-1', RecoveryStrategy.rollbackAndRetry, bare);
      expect(empty.status, RecoveryStatus.readyForRetry);

      final withState = testExecutionContext(state: {
        'stages': {'a': 1}
      });
      final fromContext = await manager(_FixedCheckpoints(null))
          .recover('run-1', RecoveryStrategy.rollbackAndRetry, withState);
      expect(fromContext.status, RecoveryStatus.readyForRetry);
      expect(fromContext.message, contains('Rollback completed'));

      final fromCheckpoint = await manager(_FixedCheckpoints(_cp(outputs: {
        'a': const StageOutput(data: 1, status: StageStatus.completed),
      }))).recover('run-1', RecoveryStrategy.rollbackAndRetry, bare);
      expect(fromCheckpoint.message, contains('from the beginning'));
    });

    test('a failing rollback raises, with and without a checkpoint', () async {
      final failing = handler(metrics: MetricsCollector(sink: _ThrowingSink()));
      final ctx = testExecutionContext(state: {
        'stages': {'a': 1}
      });
      await expectLater(
          manager(_FixedCheckpoints(null), rollback: failing)
              .recover('run-1', RecoveryStrategy.rollbackAndRetry, ctx),
          throwsA(isA<PermanentOpsException>()));
      await expectLater(
          manager(
                  _FixedCheckpoints(_cp(outputs: {
                    'a': const StageOutput(
                        data: 1, status: StageStatus.completed),
                  })),
                  rollback: failing)
              .recover('run-1', RecoveryStrategy.rollbackAndRetry, ctx),
          throwsA(isA<PermanentOpsException>()));
    });

    test('skip and continue, manual intervention, unexpected errors', () async {
      final ctx = testExecutionContext();
      await expectLater(
          manager(_FixedCheckpoints(null))
              .recover('run-1', RecoveryStrategy.skipAndContinue, ctx),
          throwsA(isA<PermanentOpsException>()));
      final skip = await manager(_FixedCheckpoints(_cp(last: 's1')))
          .recover('run-1', RecoveryStrategy.skipAndContinue, ctx);
      expect(skip.state!['_skipNextStage'], isTrue);
      expect(skip.message, contains('after stage s1'));
      final skipStart = await manager(_FixedCheckpoints(_cp()))
          .recover('run-1', RecoveryStrategy.skipAndContinue, ctx);
      expect(skipStart.message, contains('from the beginning'));
      final manual = await manager(_FixedCheckpoints(null))
          .recover('run-1', RecoveryStrategy.manualIntervention, ctx);
      expect(manual.status, RecoveryStatus.awaitingManual);
      expect(manual.isSuccessful, isFalse);

      final broken = await manager(_ExplodingCheckpoints())
          .recover('run-1', RecoveryStrategy.resumeFromCheckpoint, ctx);
      expect(broken.status, RecoveryStatus.failed);
      expect(broken.message, contains('Recovery failed'));
    });
  });
}

class _ExplodingCheckpoints extends InMemoryCheckpointManager {
  @override
  Future<Checkpoint?> loadLatest(String runId) async =>
      throw StateError('store gone');
}
