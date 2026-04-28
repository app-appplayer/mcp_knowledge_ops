/// Pipeline Tests
///
/// Tests for Pipeline, PipelineStage, PipelineConfig, and related classes.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  group('PipelineStage', () {
    test('creates with required parameters', () {
      const stage = PipelineStage(
        id: 'stage-1',
        name: 'Test Stage',
        order: 1,
        handler: 'testHandler',
      );

      expect(stage.id, equals('stage-1'));
      expect(stage.name, equals('Test Stage'));
      expect(stage.order, equals(1));
      expect(stage.handler, equals('testHandler'));
      expect(stage.inputMapping, isEmpty);
      expect(stage.outputMapping, isEmpty);
      expect(stage.condition, isNull);
      expect(stage.retryConfig, isNull);
      expect(stage.timeout, isNull);
    });

    test('creates with all parameters', () {
      const stage = PipelineStage(
        id: 'stage-1',
        name: 'Full Stage',
        order: 2,
        handler: 'handler',
        inputMapping: {'input': 'source'},
        outputMapping: {'output': 'target'},
        condition: 'data.count > 0',
        timeout: Duration(seconds: 30),
        description: 'A full stage',
      );

      expect(stage.inputMapping, containsPair('input', 'source'));
      expect(stage.outputMapping, containsPair('output', 'target'));
      expect(stage.condition, equals('data.count > 0'));
      expect(stage.timeout?.inSeconds, equals(30));
      expect(stage.description, equals('A full stage'));
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'id': 's1',
        'name': 'Stage 1',
        'order': 1,
        'handler': 'handler1',
        'inputMapping': {'a': 'b'},
        'condition': 'x > 0',
      };

      final stage = PipelineStage.fromJson(json);

      expect(stage.id, equals('s1'));
      expect(stage.name, equals('Stage 1'));
      expect(stage.order, equals(1));
      expect(stage.inputMapping, containsPair('a', 'b'));
      expect(stage.condition, equals('x > 0'));
    });

    test('toJson serializes correctly', () {
      const stage = PipelineStage(
        id: 's1',
        name: 'Stage',
        order: 1,
        handler: 'h1',
        timeout: Duration(seconds: 60),
      );

      final json = stage.toJson();

      expect(json['id'], equals('s1'));
      expect(json['name'], equals('Stage'));
      expect(json['order'], equals(1));
      expect(json['handler'], equals('h1'));
      expect(json['timeout'], equals(60000));
    });
  });

  group('PipelineConfig', () {
    test('creates with default values', () {
      const config = PipelineConfig();

      expect(config.maxConcurrency, equals(1));
      expect(config.timeout, isNull);
      expect(config.retryPolicy, isNull);
      expect(config.onError, equals(OnErrorStrategy.fail));
      expect(config.checkpointEnabled, isFalse);
      expect(config.extra, isEmpty);
    });

    test('creates with custom values', () {
      const config = PipelineConfig(
        maxConcurrency: 5,
        timeout: Duration(minutes: 10),
        onError: OnErrorStrategy.retry,
        checkpointEnabled: true,
        extra: {'key': 'value'},
      );

      expect(config.maxConcurrency, equals(5));
      expect(config.timeout?.inMinutes, equals(10));
      expect(config.onError, equals(OnErrorStrategy.retry));
      expect(config.checkpointEnabled, isTrue);
      expect(config.extra, containsPair('key', 'value'));
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'maxConcurrency': 3,
        'timeout': 60000,
        'onError': 'skip',
        'checkpointEnabled': true,
      };

      final config = PipelineConfig.fromJson(json);

      expect(config.maxConcurrency, equals(3));
      expect(config.timeout?.inMilliseconds, equals(60000));
      expect(config.onError, equals(OnErrorStrategy.skip));
      expect(config.checkpointEnabled, isTrue);
    });

    test('toJson serializes correctly', () {
      const config = PipelineConfig(
        maxConcurrency: 2,
        onError: OnErrorStrategy.fail,
      );

      final json = config.toJson();

      expect(json['maxConcurrency'], equals(2));
      expect(json['onError'], equals('fail'));
    });
  });

  group('OnErrorStrategy', () {
    test('fromString returns correct value', () {
      expect(OnErrorStrategy.fromString('fail'), equals(OnErrorStrategy.fail));
      expect(OnErrorStrategy.fromString('skip'), equals(OnErrorStrategy.skip));
      expect(OnErrorStrategy.fromString('retry'), equals(OnErrorStrategy.retry));
    });

    test('fromString returns fail for unknown', () {
      expect(OnErrorStrategy.fromString('unknown'), equals(OnErrorStrategy.fail));
    });
  });

  group('PipelineContext', () {
    test('creates with required parameters', () {
      final context = PipelineContext(
        runId: 'run-1',
        workspaceId: 'ws-1',
        config: const PipelineConfig(),
      );

      expect(context.runId, equals('run-1'));
      expect(context.workspaceId, equals('ws-1'));
      expect(context.traceId, isNull);
      expect(context.userId, isNull);
      expect(context.asOf, isNotNull);
      expect(context.state, isEmpty);
    });

    test('updateState modifies state', () {
      final context = PipelineContext(
        runId: 'run-1',
        workspaceId: 'ws-1',
        config: const PipelineConfig(),
      );

      context.updateState('key1', 'value1');
      context.updateState('key2', 42);

      expect(context.state['key1'], equals('value1'));
      expect(context.state['key2'], equals(42));
    });

    test('getState retrieves typed value', () {
      final context = PipelineContext(
        runId: 'run-1',
        workspaceId: 'ws-1',
        config: const PipelineConfig(),
      );

      context.updateState('count', 10);

      expect(context.getState<int>('count'), equals(10));
      expect(context.getState<String>('count'), isNull);
      expect(context.getState<int>('missing'), isNull);
    });

    test('copyWith creates modified copy', () {
      final original = PipelineContext(
        runId: 'run-1',
        workspaceId: 'ws-1',
        config: const PipelineConfig(),
      );

      final modified = original.copyWith(
        runId: 'run-2',
        userId: 'user-1',
      );

      expect(original.runId, equals('run-1'));
      expect(modified.runId, equals('run-2'));
      expect(modified.userId, equals('user-1'));
      expect(modified.workspaceId, equals(original.workspaceId));
    });
  });

  group('PipelineResult', () {
    test('creates success result', () {
      final result = PipelineResult<String>.success(
        output: 'Success output',
        stages: [],
        metrics: const PipelineMetrics(totalDuration: Duration(seconds: 5)),
      );

      expect(result.success, isTrue);
      expect(result.output, equals('Success output'));
      expect(result.error, isNull);
    });

    test('creates failure result', () {
      final result = PipelineResult<String>.failure(
        error: const PipelineError(
          code: 'ERR001',
          message: 'Something failed',
          stageId: 'stage-1',
        ),
        stages: [],
        metrics: const PipelineMetrics(totalDuration: Duration(seconds: 2)),
      );

      expect(result.success, isFalse);
      expect(result.output, isNull);
      expect(result.error?.code, equals('ERR001'));
      expect(result.error?.stageId, equals('stage-1'));
    });
  });

  group('PipelineError', () {
    test('creates with required parameters', () {
      const error = PipelineError(
        code: 'ERR001',
        message: 'Test error',
      );

      expect(error.code, equals('ERR001'));
      expect(error.message, equals('Test error'));
      expect(error.stageId, isNull);
      expect(error.cause, isNull);
    });

    test('toString returns readable format', () {
      const error = PipelineError(
        code: 'ERR001',
        message: 'Test message',
      );

      expect(error.toString(), contains('ERR001'));
      expect(error.toString(), contains('Test message'));
    });
  });

  group('StageResult', () {
    test('creates with required parameters', () {
      final result = StageResult(
        stageId: 'stage-1',
        status: StageStatus.completed,
        startedAt: DateTime(2024, 1, 1, 10, 0),
      );

      expect(result.stageId, equals('stage-1'));
      expect(result.status, equals(StageStatus.completed));
      expect(result.completedAt, isNull);
      expect(result.output, isNull);
      expect(result.error, isNull);
    });

    test('duration returns correct value', () {
      final result = StageResult(
        stageId: 'stage-1',
        status: StageStatus.completed,
        startedAt: DateTime(2024, 1, 1, 10, 0, 0),
        completedAt: DateTime(2024, 1, 1, 10, 0, 30),
      );

      expect(result.duration?.inSeconds, equals(30));
    });

    test('duration returns null when not completed', () {
      final result = StageResult(
        stageId: 'stage-1',
        status: StageStatus.completed,
        startedAt: DateTime(2024, 1, 1, 10, 0),
      );

      expect(result.duration, isNull);
    });

    test('toJson serializes correctly', () {
      final result = StageResult(
        stageId: 'stage-1',
        status: StageStatus.failed,
        startedAt: DateTime(2024, 1, 1, 10, 0),
        error: 'Failed to process',
      );

      final json = result.toJson();

      expect(json['stageId'], equals('stage-1'));
      expect(json['status'], equals('failed'));
      expect(json['error'], equals('Failed to process'));
    });
  });

  group('PipelineMetrics', () {
    test('creates with required parameters', () {
      const metrics = PipelineMetrics(
        totalDuration: Duration(seconds: 10),
      );

      expect(metrics.totalDuration.inSeconds, equals(10));
      expect(metrics.stageDurations, isEmpty);
      expect(metrics.itemsProcessed, equals(0));
      expect(metrics.itemsFailed, equals(0));
    });

    test('toJson serializes correctly', () {
      const metrics = PipelineMetrics(
        totalDuration: Duration(seconds: 15),
        stageDurations: {'stage1': Duration(seconds: 5)},
        itemsProcessed: 100,
        itemsFailed: 2,
        custom: {'metric1': 42},
      );

      final json = metrics.toJson();

      expect(json['totalDuration'], equals(15000));
      expect(json['itemsProcessed'], equals(100));
      expect(json['itemsFailed'], equals(2));
      expect(json['custom'], containsPair('metric1', 42));
    });
  });

  group('RetryConfig', () {
    test('creates with default values', () {
      const config = RetryConfig();

      expect(config.maxAttempts, equals(3));
      expect(config.initialDelay.inSeconds, equals(1));
      expect(config.maxDelay.inSeconds, equals(60));
      expect(config.backoffMultiplier, equals(2.0));
      expect(config.retryableErrors, isEmpty);
    });

    test('delayForAttempt calculates correctly', () {
      const config = RetryConfig(
        initialDelay: Duration(seconds: 1),
        backoffMultiplier: 2.0,
      );

      expect(config.delayForAttempt(1).inSeconds, equals(1));
      expect(config.delayForAttempt(2).inSeconds, equals(2));
      expect(config.delayForAttempt(3).inSeconds, equals(4));
    });

    test('delayForAttempt respects maxDelay', () {
      const config = RetryConfig(
        initialDelay: Duration(seconds: 10),
        maxDelay: Duration(seconds: 15),
        backoffMultiplier: 2.0,
      );

      expect(config.delayForAttempt(1).inSeconds, equals(10));
      expect(config.delayForAttempt(2).inSeconds, equals(15));
      expect(config.delayForAttempt(3).inSeconds, equals(15));
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'maxAttempts': 5,
        'initialDelay': 2000,
        'maxDelay': 30000,
        'backoffMultiplier': 1.5,
      };

      final config = RetryConfig.fromJson(json);

      expect(config.maxAttempts, equals(5));
      expect(config.initialDelay.inMilliseconds, equals(2000));
      expect(config.maxDelay.inMilliseconds, equals(30000));
      expect(config.backoffMultiplier, equals(1.5));
    });

    test('toJson serializes correctly', () {
      const config = RetryConfig(
        maxAttempts: 4,
        initialDelay: Duration(seconds: 2),
        retryableErrors: ['TIMEOUT', 'RATE_LIMIT'],
      );

      final json = config.toJson();

      expect(json['maxAttempts'], equals(4));
      expect(json['initialDelay'], equals(2000));
      expect(json['retryableErrors'], containsAll(['TIMEOUT', 'RATE_LIMIT']));
    });
  });

  group('RetryPolicy', () {
    test('creates with default config', () {
      const policy = RetryPolicy(
        defaultConfig: RetryConfig(),
      );

      expect(policy.defaultConfig, isNotNull);
      expect(policy.perStage, isEmpty);
    });

    test('getConfigForStage returns stage config when present', () {
      const policy = RetryPolicy(
        defaultConfig: RetryConfig(maxAttempts: 3),
        perStage: {
          'stage1': RetryConfig(maxAttempts: 5),
        },
      );

      expect(policy.getConfigForStage('stage1').maxAttempts, equals(5));
      expect(policy.getConfigForStage('stage2').maxAttempts, equals(3));
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'default': {'maxAttempts': 3},
        'perStage': {
          'stage1': {'maxAttempts': 5},
        },
      };

      final policy = RetryPolicy.fromJson(json);

      expect(policy.defaultConfig.maxAttempts, equals(3));
      expect(policy.perStage['stage1']?.maxAttempts, equals(5));
    });

    test('toJson serializes correctly', () {
      const policy = RetryPolicy(
        defaultConfig: RetryConfig(maxAttempts: 2),
        perStage: {
          'special': RetryConfig(maxAttempts: 10),
        },
      );

      final json = policy.toJson();

      expect(json['default']['maxAttempts'], equals(2));
      expect(json['perStage']['special']['maxAttempts'], equals(10));
    });
  });
}
