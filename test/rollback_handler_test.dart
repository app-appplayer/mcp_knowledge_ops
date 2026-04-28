/// Tests for RollbackHandler, RollbackConfig, RollbackResult, and RollbackStageResult.
///
/// Covers rollback with empty stages, config defaults, config copyWith,
/// result success checks, failed stage filtering, and serialization.
library;

import 'package:test/test.dart';

import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

void main() {
  group('RollbackConfig', () {
    test('has sensible defaults', () {
      const config = RollbackConfig();

      expect(config.enabled, isTrue);
      expect(config.rollbackStages, isEmpty);
      expect(config.autoRollback, isFalse);
      expect(config.rollbackTimeout, equals(const Duration(minutes: 30)));
    });

    test('copyWith replaces specified fields', () {
      const original = RollbackConfig();
      final modified = original.copyWith(
        enabled: false,
        rollbackStages: ['stage-a', 'stage-b'],
        autoRollback: true,
        rollbackTimeout: const Duration(minutes: 10),
      );

      expect(modified.enabled, isFalse);
      expect(modified.rollbackStages, equals(['stage-a', 'stage-b']));
      expect(modified.autoRollback, isTrue);
      expect(modified.rollbackTimeout, equals(const Duration(minutes: 10)));
    });

    test('copyWith preserves unmodified fields', () {
      const original = RollbackConfig(
        enabled: false,
        rollbackStages: ['stage-1'],
        autoRollback: true,
        rollbackTimeout: Duration(minutes: 5),
      );
      final modified = original.copyWith(enabled: true);

      expect(modified.enabled, isTrue);
      expect(modified.rollbackStages, equals(['stage-1']));
      expect(modified.autoRollback, isTrue);
      expect(modified.rollbackTimeout, equals(const Duration(minutes: 5)));
    });
  });

  group('RollbackStageResult', () {
    test('toJson serializes success result', () {
      const result = RollbackStageResult(
        stageId: 'stage-1',
        success: true,
        message: 'Rolled back OK',
      );

      final json = result.toJson();

      expect(json['stageId'], equals('stage-1'));
      expect(json['success'], isTrue);
      expect(json['message'], equals('Rolled back OK'));
    });

    test('toJson omits null message', () {
      const result = RollbackStageResult(
        stageId: 'stage-2',
        success: false,
      );

      final json = result.toJson();

      expect(json['stageId'], equals('stage-2'));
      expect(json['success'], isFalse);
      expect(json.containsKey('message'), isFalse);
    });
  });

  group('RollbackResult', () {
    test('isSuccessful returns true for success status', () {
      const result = RollbackResult(
        status: RollbackStatus.success,
        stageResults: [],
      );

      expect(result.isSuccessful, isTrue);
    });

    test('isSuccessful returns false for non-success statuses', () {
      for (final status in [
        RollbackStatus.failed,
        RollbackStatus.skipped,
        RollbackStatus.error,
      ]) {
        final result = RollbackResult(
          status: status,
          stageResults: const [],
        );
        expect(result.isSuccessful, isFalse,
            reason: 'Expected $status to not be successful');
      }
    });

    test('failedStages returns only failed stage results', () {
      const result = RollbackResult(
        status: RollbackStatus.failed,
        stageResults: [
          RollbackStageResult(stageId: 'stage-1', success: true),
          RollbackStageResult(stageId: 'stage-2', success: false, message: 'error'),
          RollbackStageResult(stageId: 'stage-3', success: true),
          RollbackStageResult(stageId: 'stage-4', success: false, message: 'timeout'),
        ],
      );

      final failed = result.failedStages;

      expect(failed, hasLength(2));
      expect(failed[0].stageId, equals('stage-2'));
      expect(failed[1].stageId, equals('stage-4'));
    });

    test('failedStages returns empty list when all succeed', () {
      const result = RollbackResult(
        status: RollbackStatus.success,
        stageResults: [
          RollbackStageResult(stageId: 'stage-1', success: true),
          RollbackStageResult(stageId: 'stage-2', success: true),
        ],
      );

      expect(result.failedStages, isEmpty);
    });

    test('toJson serializes all fields', () {
      const result = RollbackResult(
        status: RollbackStatus.failed,
        stageResults: [
          RollbackStageResult(stageId: 'stage-1', success: true),
          RollbackStageResult(stageId: 'stage-2', success: false, message: 'err'),
        ],
        message: 'Partial failure',
      );

      final json = result.toJson();

      expect(json['status'], equals('failed'));
      expect(json['stageResults'], isList);
      expect((json['stageResults'] as List), hasLength(2));
      expect(json['message'], equals('Partial failure'));
    });

    test('toJson omits null message', () {
      const result = RollbackResult(
        status: RollbackStatus.success,
        stageResults: [],
      );

      final json = result.toJson();

      expect(json['status'], equals('success'));
      expect(json.containsKey('message'), isFalse);
    });
  });

  group('RollbackHandler', () {
    late RollbackHandler handler;
    late ExecutionLogger logger;
    late MetricsCollector metrics;

    setUp(() {
      final loggerPair = testLogger();
      logger = loggerPair.$1;
      final testPorts = TestOpsPorts();
      final metricsPair = testMetrics();
      metrics = metricsPair.$1;

      handler = RollbackHandler(
        ports: testPorts.toOpsPorts(),
        logger: logger,
        metrics: metrics,
      );
    });

    test('rollback with disabled config returns skipped', () async {
      final context = testExecutionContext();
      final result = await handler.rollback(
        context,
        {'stage-1': 'output-1'},
        const RollbackConfig(enabled: false),
      );

      expect(result.status, equals(RollbackStatus.skipped));
      expect(result.stageResults, isEmpty);
      expect(result.message, contains('not enabled'));
    });

    test('rollback with empty stage outputs returns skipped', () async {
      final context = testExecutionContext();
      final result = await handler.rollback(
        context,
        {},
        const RollbackConfig(enabled: true),
      );

      expect(result.status, equals(RollbackStatus.skipped));
      expect(result.stageResults, isEmpty);
      expect(result.message, contains('No stages'));
    });

    test('rollback with specific stages filters by rollbackStages config',
        () async {
      final context = testExecutionContext();
      final result = await handler.rollback(
        context,
        {
          'stage-1': 'output-1',
          'stage-2': 'output-2',
          'stage-3': 'output-3',
        },
        const RollbackConfig(
          enabled: true,
          rollbackStages: ['stage-1', 'stage-3', 'stage-nonexistent'],
        ),
      );

      // Only stage-1 and stage-3 should be rolled back (stage-nonexistent
      // is not in stageOutputs)
      expect(result.stageResults, hasLength(2));
      final rolledBackIds =
          result.stageResults.map((r) => r.stageId).toList();
      expect(rolledBackIds, contains('stage-1'));
      expect(rolledBackIds, contains('stage-3'));
    });
  });
}
