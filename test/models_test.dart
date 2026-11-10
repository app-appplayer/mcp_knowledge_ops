/// Models Tests - Tests for all model classes.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';
// Import model events directly - these are hidden from barrel due to
// name conflicts with typed OpsEvent subclasses in events_arch.
import 'package:mcp_knowledge_ops/src/models/events.dart' as model_events;

void main() {
  // ═══════════════════════════════════════════════════════════════
  // ExecutionContext
  // ═══════════════════════════════════════════════════════════════

  group('ExecutionContext', () {
    test('creates with required parameters', () {
      final ctx = ExecutionContext(
        runId: 'run-1',
        traceId: 'trace-1',
        workspaceId: 'ws-1',
        asOf: DateTime(2024, 1, 1),
        config: const ExecutionConfig(),
      );

      expect(ctx.runId, equals('run-1'));
      expect(ctx.traceId, equals('trace-1'));
      expect(ctx.workspaceId, equals('ws-1'));
      expect(ctx.parentSpanId, isNull);
      expect(ctx.userId, isNull);
      expect(ctx.variables, isEmpty);
      expect(ctx.state, isEmpty);
      expect(ctx.resumeFromStage, isNull);
      expect(ctx.currentCheckpoint, isNull);
    });

    test('state management', () {
      final ctx = ExecutionContext(
        runId: 'run-1',
        traceId: 'trace-1',
        workspaceId: 'ws-1',
        asOf: DateTime(2024, 1, 1),
        config: const ExecutionConfig(),
      );

      ctx.setState('key1', 'value1');
      expect(ctx.getState<String>('key1'), equals('value1'));

      ctx.updateState({'key2': 42, 'key3': true});
      expect(ctx.getState<int>('key2'), equals(42));
      expect(ctx.getState<bool>('key3'), isTrue);
    });

    test('child context inherits state', () {
      final ctx = ExecutionContext(
        runId: 'run-1',
        traceId: 'trace-1',
        workspaceId: 'ws-1',
        asOf: DateTime(2024, 1, 1),
        config: const ExecutionConfig(),
      );
      ctx.setState('inherited', 'yes');

      final child = ctx.child(stageName: 'stage-1');
      expect(child.runId, equals('run-1/stage-1'));
      expect(child.traceId, equals('trace-1'));
      expect(child.getState<String>('inherited'), equals('yes'));
      expect(child.resumeFromStage, isNull);
    });

    test('child context with additional state', () {
      final ctx = ExecutionContext(
        runId: 'run-1',
        traceId: 'trace-1',
        workspaceId: 'ws-1',
        asOf: DateTime(2024, 1, 1),
        config: const ExecutionConfig(),
      );

      final child = ctx.child(
        stageName: 'step',
        additionalState: {'extra': true},
      );
      expect(child.getState<bool>('extra'), isTrue);
    });

    test('checkpoint creation', () {
      final ctx = ExecutionContext(
        runId: 'run-1',
        traceId: 'trace-1',
        workspaceId: 'ws-1',
        asOf: DateTime(2024, 1, 1),
        config: const ExecutionConfig(),
      );
      ctx.setState('data', 'hello');

      ctx.checkpoint('cp-1', {'additional': 42});

      final cp = ctx.currentCheckpoint;
      expect(cp, isNotNull);
      expect(cp!.runId, equals('run-1'));
      expect(cp.name, equals('cp-1'));
      expect(cp.state['data'], equals('hello'));
      expect(cp.state['additional'], equals(42));
    });

    test('recordStageOutput and getStageOutput', () {
      final ctx = ExecutionContext(
        runId: 'run-1',
        traceId: 'trace-1',
        workspaceId: 'ws-1',
        asOf: DateTime(2024, 1, 1),
        config: const ExecutionConfig(),
      );

      const output =
          StageOutput(data: {'result': 'ok'}, status: StageStatus.completed);
      ctx.recordStageOutput('stage-1', output);

      final retrieved = ctx.getStageOutput('stage-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.data, equals({'result': 'ok'}));
      expect(retrieved.status, equals(StageStatus.completed));

      // Also check state integration
      expect(ctx.getState<Map>('stages'), isNotNull);
    });

    test('copyWith creates modified copy', () {
      final ctx = ExecutionContext(
        runId: 'run-1',
        traceId: 'trace-1',
        workspaceId: 'ws-1',
        asOf: DateTime(2024, 1, 1),
        config: const ExecutionConfig(),
      );

      final copy = ctx.copyWith(runId: 'run-2', userId: 'user-1');
      expect(copy.runId, equals('run-2'));
      expect(copy.userId, equals('user-1'));
      expect(copy.traceId, equals('trace-1'));
    });

    test('fromCheckpoint creates context from checkpoint', () {
      final cp = Checkpoint(
        id: 'cp-1',
        runId: 'run-1',
        name: 'test-cp',
        state: {
          'workspaceId': 'ws-1',
          'variables': {'key': 'val'}
        },
        stageOutputs: {},
        lastCompletedStage: 'stage-2',
        createdAt: DateTime(2024, 1, 1),
      );

      final ctx = ExecutionContext.fromCheckpoint(
        cp,
        config: const ExecutionConfig(),
      );

      expect(ctx.runId, equals('run-1'));
      expect(ctx.resumeFromStage, equals('stage-2'));
      expect(ctx.variables['key'], equals('val'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // ExecutionConfig
  // ═══════════════════════════════════════════════════════════════

  group('ExecutionConfig', () {
    test('defaults', () {
      const config = ExecutionConfig();
      expect(config.timeout, equals(const Duration(hours: 1)));
      expect(config.checkpointEnabled, isTrue);
      expect(config.dryRun, isFalse);
      expect(config.maxConcurrency, equals(1));
      expect(config.autoApprove, isFalse);
    });

    test('copyWith', () {
      const config = ExecutionConfig();
      final copy = config.copyWith(dryRun: true, maxConcurrency: 4);
      expect(copy.dryRun, isTrue);
      expect(copy.maxConcurrency, equals(4));
      expect(copy.timeout, equals(const Duration(hours: 1)));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // RetryConfig
  // ═══════════════════════════════════════════════════════════════

  group('RetryConfig', () {
    test('defaults', () {
      const config = RetryConfig();
      expect(config.maxAttempts, equals(3));
      expect(config.initialDelay, equals(const Duration(seconds: 1)));
      expect(config.maxDelay, equals(const Duration(seconds: 60)));
      expect(config.backoffMultiplier, equals(2.0));
      expect(config.jitterFactor, equals(0.0));
    });

    test('delayForAttempt with backoff', () {
      const config = RetryConfig(
        initialDelay: Duration(seconds: 1),
        backoffMultiplier: 2.0,
        maxDelay: Duration(seconds: 60),
      );

      expect(config.delayForAttempt(0), equals(Duration.zero));
      expect(config.delayForAttempt(1), equals(const Duration(seconds: 1)));
      expect(config.delayForAttempt(2), equals(const Duration(seconds: 2)));
      expect(config.delayForAttempt(3), equals(const Duration(seconds: 4)));
    });

    test('delayForAttempt capped by maxDelay', () {
      const config = RetryConfig(
        initialDelay: Duration(seconds: 10),
        backoffMultiplier: 10.0,
        maxDelay: Duration(seconds: 30),
      );

      final delay = config.delayForAttempt(5);
      expect(delay.inSeconds, lessThanOrEqualTo(30));
    });

    test('isRetryable with empty list returns true', () {
      const config = RetryConfig();
      expect(config.isRetryable('any-code'), isTrue);
    });

    test('isRetryable with specific codes', () {
      const config = RetryConfig(retryableErrors: ['ERR-001', 'ERR-002']);
      expect(config.isRetryable('ERR-001'), isTrue);
      expect(config.isRetryable('ERR-999'), isFalse);
    });

    test('isExceptionRetryable with empty list returns true', () {
      const config = RetryConfig();
      expect(config.isExceptionRetryable(Exception('test')), isTrue);
    });

    test('isExceptionRetryable with specific types', () {
      const config = RetryConfig(retryableExceptions: ['FormatException']);
      expect(config.isExceptionRetryable(const FormatException()), isTrue);
      expect(config.isExceptionRetryable(StateError('test')), isFalse);
    });

    test('toJson and fromJson roundtrip', () {
      const config = RetryConfig(maxAttempts: 5, backoffMultiplier: 1.5);
      final json = config.toJson();
      final restored = RetryConfig.fromJson(json);
      expect(restored.maxAttempts, equals(5));
      expect(restored.backoffMultiplier, equals(1.5));
    });

    test('copyWith', () {
      const config = RetryConfig();
      final copy = config.copyWith(maxAttempts: 10);
      expect(copy.maxAttempts, equals(10));
      expect(copy.initialDelay, equals(const Duration(seconds: 1)));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Checkpoint
  // ═══════════════════════════════════════════════════════════════

  group('Checkpoint', () {
    test('creation', () {
      final cp = Checkpoint(
        id: 'cp-1',
        runId: 'run-1',
        name: 'test',
        state: {'key': 'value'},
        stageOutputs: {},
        createdAt: DateTime(2024, 1, 1),
      );
      expect(cp.id, equals('cp-1'));
      expect(cp.executionState, equals(ExecutionState.paused));
      expect(cp.schemaVersion, equals('1.0.0'));
    });

    test('isExpired returns false when no expiresAt', () {
      final cp = Checkpoint(
        id: 'cp-1',
        runId: 'run-1',
        name: 'test',
        state: {},
        stageOutputs: {},
        createdAt: DateTime(2024, 1, 1),
      );
      expect(cp.isExpired, isFalse);
    });

    test('isExpired returns true when past expiresAt', () {
      final cp = Checkpoint(
        id: 'cp-1',
        runId: 'run-1',
        name: 'test',
        state: {},
        stageOutputs: {},
        createdAt: DateTime(2024, 1, 1),
        expiresAt: DateTime(2020, 1, 1),
      );
      expect(cp.isExpired, isTrue);
    });

    test('isResumable for paused state', () {
      final cp = Checkpoint(
        id: 'cp-1',
        runId: 'run-1',
        name: 'test',
        state: {},
        stageOutputs: {},
        executionState: ExecutionState.paused,
        createdAt: DateTime(2024, 1, 1),
      );
      expect(cp.isResumable, isTrue);
    });

    test('isResumable false for completed state', () {
      final cp = Checkpoint(
        id: 'cp-1',
        runId: 'run-1',
        name: 'test',
        state: {},
        stageOutputs: {},
        executionState: ExecutionState.completed,
        createdAt: DateTime(2024, 1, 1),
      );
      expect(cp.isResumable, isFalse);
    });

    test('toJson and fromJson roundtrip', () {
      final original = Checkpoint(
        id: 'cp-1',
        runId: 'run-1',
        name: 'test',
        state: {'key': 'value'},
        stageOutputs: {
          'stage-1':
              const StageOutput(data: 'output', status: StageStatus.completed),
        },
        lastCompletedStage: 'stage-1',
        executionState: ExecutionState.paused,
        createdAt: DateTime(2024, 1, 1),
        metadata: {'tag': 'test'},
      );

      final json = original.toJson();
      final restored = Checkpoint.fromJson(json);
      expect(restored.id, equals('cp-1'));
      expect(restored.lastCompletedStage, equals('stage-1'));
      expect(restored.executionState, equals(ExecutionState.paused));
      expect(restored.metadata?['tag'], equals('test'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Enums
  // ═══════════════════════════════════════════════════════════════

  group('ExecutionState', () {
    test('has all 10 values', () {
      expect(ExecutionState.values.length, equals(10));
      expect(
          ExecutionState.values,
          containsAll([
            ExecutionState.pending,
            ExecutionState.validating,
            ExecutionState.running,
            ExecutionState.waitingReview,
            ExecutionState.waitingApproval,
            ExecutionState.paused,
            ExecutionState.completed,
            ExecutionState.failed,
            ExecutionState.cancelled,
            ExecutionState.rolledBack,
          ]));
    });
  });

  group('CheckpointStatus', () {
    test('has all 5 values', () {
      expect(CheckpointStatus.values.length, equals(5));
      expect(
          CheckpointStatus.values,
          containsAll([
            CheckpointStatus.active,
            CheckpointStatus.resumed,
            CheckpointStatus.expired,
            CheckpointStatus.superseded,
            CheckpointStatus.invalidated,
          ]));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Stage
  // ═══════════════════════════════════════════════════════════════

  group('Stage', () {
    test('creates with defaults', () {
      const stage = Stage(id: 's1', name: 'Stage 1', handler: 'h1');
      expect(stage.order, equals(0));
      expect(stage.inputMapping, isEmpty);
      expect(stage.outputMapping, isEmpty);
      expect(stage.condition, isNull);
      expect(stage.dependsOn, isNull);
      expect(stage.timeout, isNull);
      expect(stage.retryConfig, isNull);
      expect(stage.onFailure, equals(OnFailure.fail));
      expect(stage.config, isEmpty);
    });

    test('copyWith', () {
      const stage = Stage(id: 's1', name: 'Stage 1', handler: 'h1');
      final copy = stage.copyWith(order: 5, onFailure: OnFailure.skip);
      expect(copy.order, equals(5));
      expect(copy.onFailure, equals(OnFailure.skip));
      expect(copy.id, equals('s1'));
    });
  });

  group('OnFailure', () {
    test('has all values', () {
      expect(
          OnFailure.values,
          containsAll([
            OnFailure.fail,
            OnFailure.skip,
            OnFailure.retry,
            OnFailure.manualOverride,
          ]));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // StageRetryConfig
  // ═══════════════════════════════════════════════════════════════

  group('StageRetryConfig', () {
    test('delayForAttempt with maxDelay cap', () {
      const config = StageRetryConfig(
        initialDelay: Duration(seconds: 10),
        backoffMultiplier: 10.0,
        maxDelay: Duration(seconds: 30),
      );
      final delay = config.delayForAttempt(5);
      expect(delay.inSeconds, lessThanOrEqualTo(30));
    });

    test('delayForAttempt returns zero for attempt 0', () {
      const config = StageRetryConfig();
      expect(config.delayForAttempt(0), equals(Duration.zero));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // StageResult
  // ═══════════════════════════════════════════════════════════════

  group('StageResult', () {
    test('completed factory', () {
      final result = StageResult.completed('s1', 'output');
      expect(result.stageId, equals('s1'));
      expect(result.status, equals(StageStatus.completed));
      expect(result.output, equals('output'));
      expect(result.duration, isNotNull);
    });

    test('skipped factory', () {
      final result = StageResult.skipped('s1', 'condition not met');
      expect(result.status, equals(StageStatus.skipped));
      expect(result.error, equals('condition not met'));
    });

    test('failed factory', () {
      final result = StageResult.failed('s1', 'boom');
      expect(result.status, equals(StageStatus.failed));
      expect(result.error, equals('boom'));
    });

    test('pending factory', () {
      final result = StageResult.pending('s1', 'waiting');
      expect(result.status, equals(StageStatus.waitingOverride));
      expect(result.completedAt, isNull);
    });

    test('toJson', () {
      final result = StageResult.completed('s1', 'data');
      final json = result.toJson();
      expect(json['stageId'], equals('s1'));
      expect(json['status'], equals('completed'));
    });

    test('fromJson roundtrip', () {
      final original = StageResult.completed('s1', 'data');
      final json = original.toJson();
      final restored = StageResult.fromJson(json);
      expect(restored.stageId, equals('s1'));
      expect(restored.status, equals(StageStatus.completed));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // StageOutput
  // ═══════════════════════════════════════════════════════════════

  group('StageOutput', () {
    test('toJson and fromJson roundtrip', () {
      const output = StageOutput(
        data: {'key': 'value'},
        status: StageStatus.completed,
        metadata: {'tag': 'test'},
      );
      final json = output.toJson();
      final restored = StageOutput.fromJson(json);
      expect(restored.status, equals(StageStatus.completed));
      expect(restored.metadata?['tag'], equals('test'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Gate
  // ═══════════════════════════════════════════════════════════════

  group('Gate', () {
    test('creation with conditions', () {
      const gate = Gate(
        id: 'g1',
        name: 'Quality Gate',
        afterStage: 's1',
        conditions: [
          GateCondition(
              type: ConditionType.threshold, metric: 'coverage', value: 80),
          GateCondition(type: ConditionType.approval, approvers: ['user-1']),
        ],
      );
      expect(gate.conditions.length, equals(2));
      expect(gate.onFailure, equals(GateFailure.block));
    });
  });

  group('GateCondition', () {
    test('all ConditionType values', () {
      expect(
          ConditionType.values,
          containsAll([
            ConditionType.threshold,
            ConditionType.expression,
            ConditionType.approval,
          ]));
    });
  });

  group('GateFailure', () {
    test('all values', () {
      expect(
          GateFailure.values,
          containsAll([
            GateFailure.block,
            GateFailure.warn,
            GateFailure.log,
          ]));
    });
  });

  group('GateResult', () {
    test('passed factory', () {
      final result = GateResult.passed('g1', [
        ConditionResult.passed('c1'),
      ]);
      expect(result.passed, isTrue);
      expect(result.conditionResults.length, equals(1));
    });

    test('failed factory', () {
      final result = GateResult.failed('g1', [
        ConditionResult.failed('c1', actual: 50, expected: 80),
      ]);
      expect(result.passed, isFalse);
    });

    test('toJson', () {
      final result = GateResult.passed('g1', [ConditionResult.passed('c1')]);
      final json = result.toJson();
      expect(json['gateId'], equals('g1'));
      expect(json['passed'], isTrue);
    });
  });

  group('ConditionResult', () {
    test('passed factory', () {
      final result = ConditionResult.passed('c1', message: 'OK');
      expect(result.passed, isTrue);
      expect(result.message, equals('OK'));
    });

    test('failed factory', () {
      final result = ConditionResult.failed('c1',
          actual: 50, expected: 80, message: 'Below threshold');
      expect(result.passed, isFalse);
      expect(result.actual, equals(50));
      expect(result.expected, equals(80));
    });

    test('toJson', () {
      final result = ConditionResult.failed('c1', actual: 50, expected: 80);
      final json = result.toJson();
      expect(json['conditionId'], equals('c1'));
      expect(json['passed'], isFalse);
      expect(json['actual'], equals(50));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Execution Results
  // ═══════════════════════════════════════════════════════════════

  group('PipelineResult', () {
    test('success factory', () {
      final result = PipelineResult<String>.success(
        output: 'done',
        stages: [],
        metrics: PipelineMetrics.empty(),
      );
      expect(result.success, isTrue);
      expect(result.output, equals('done'));
      expect(result.error, isNull);
    });

    test('failure factory', () {
      final result = PipelineResult<String>.failure(
        error: const PipelineError(code: 'ERR', message: 'failed'),
        stages: [],
        metrics: PipelineMetrics.empty(),
      );
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });
  });

  group('PipelineMetrics', () {
    test('empty factory', () {
      final metrics = PipelineMetrics.empty();
      expect(metrics.totalDuration, equals(Duration.zero));
      expect(metrics.itemsProcessed, equals(0));
    });

    test('toJson', () {
      const metrics = PipelineMetrics(
        totalDuration: Duration(seconds: 10),
        itemsProcessed: 5,
        itemsFailed: 1,
      );
      final json = metrics.toJson();
      expect(json['totalDuration'], equals(10000));
      expect(json['itemsProcessed'], equals(5));
    });
  });

  group('WorkflowResult', () {
    test('success factory', () {
      final result = WorkflowResult<String>.success(
        output: 'done',
        stages: [],
        metrics: WorkflowMetrics.empty(),
      );
      expect(result.success, isTrue);
      expect(result.artifacts, isEmpty);
    });

    test('failure factory', () {
      final result = WorkflowResult<String>.failure(
        error: const WorkflowError(code: 'ERR', message: 'failed'),
        stages: [],
        metrics: WorkflowMetrics.empty(),
      );
      expect(result.success, isFalse);
    });
  });

  group('WorkflowMetrics', () {
    test('empty factory', () {
      final metrics = WorkflowMetrics.empty();
      expect(metrics.totalDuration, equals(Duration.zero));
      expect(metrics.reviewCount, equals(0));
    });

    test('toJson', () {
      const metrics = WorkflowMetrics(
        totalDuration: Duration(seconds: 5),
        reviewCount: 2,
        approvalCount: 1,
      );
      final json = metrics.toJson();
      expect(json['totalDuration'], equals(5000));
      expect(json['reviewCount'], equals(2));
    });
  });

  group('Artifact', () {
    test('toJson', () {
      final artifact = Artifact(
        id: 'a1',
        type: 'skill_bundle',
        path: '/bundles/a1',
        checksum: 'abc123',
        createdAt: DateTime(2024, 1, 1),
      );
      final json = artifact.toJson();
      expect(json['id'], equals('a1'));
      expect(json['type'], equals('skill_bundle'));
      expect(json['checksum'], equals('abc123'));
    });
  });

  group('RunbookResult', () {
    test('with summary', () {
      const result = RunbookResult(
        success: true,
        steps: [],
        summary: 'All steps passed',
        metrics: RunbookMetrics(totalDuration: Duration(seconds: 10)),
      );
      expect(result.summary, equals('All steps passed'));
      expect(result.output, isEmpty);
    });
  });

  group('RunbookMetrics', () {
    test('empty factory', () {
      final metrics = RunbookMetrics.empty();
      expect(metrics.totalDuration, equals(Duration.zero));
      expect(metrics.manualTime, equals(Duration.zero));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Events (models/events.dart)
  // ═══════════════════════════════════════════════════════════════

  group('PipelineStartedEvent (model)', () {
    test('creation and toJson', () {
      final event = model_events.PipelineStartedEvent(
        timestamp: DateTime(2024, 1, 1),
        runId: 'run-1',
        pipelineId: 'pipe-1',
        inputSummary: {'count': 5},
      );
      expect(event.type, equals('pipeline.started'));
      final json = event.toJson();
      expect(json['pipelineId'], equals('pipe-1'));
      expect(json['inputSummary'], containsPair('count', 5));
    });
  });

  group('PipelineCompletedEvent (model)', () {
    test('creation and toJson', () {
      final event = model_events.PipelineCompletedEvent(
        timestamp: DateTime(2024, 1, 1),
        runId: 'run-1',
        pipelineId: 'pipe-1',
        success: true,
        duration: const Duration(seconds: 10),
      );
      final json = event.toJson();
      expect(json['success'], isTrue);
      expect(json['durationMs'], equals(10000));
    });
  });

  group('StageStartedEvent', () {
    test('creation and toJson', () {
      final event = StageStartedEvent(
        timestamp: DateTime(2024, 1, 1),
        runId: 'run-1',
        pipelineId: 'pipe-1',
        stageId: 'stage-1',
      );
      expect(event.type, equals('stage.started'));
      expect(event.toJson()['stageId'], equals('stage-1'));
    });
  });

  group('StageCompletedEvent', () {
    test('creation and toJson', () {
      final event = StageCompletedEvent(
        timestamp: DateTime(2024, 1, 1),
        runId: 'run-1',
        pipelineId: 'pipe-1',
        stageId: 'stage-1',
        duration: const Duration(seconds: 5),
      );
      expect(event.toJson()['durationMs'], equals(5000));
    });
  });

  group('StageFailedEvent', () {
    test('creation and toJson', () {
      final event = StageFailedEvent(
        timestamp: DateTime(2024, 1, 1),
        runId: 'run-1',
        pipelineId: 'pipe-1',
        stageId: 'stage-1',
        error: 'boom',
        willRetry: true,
      );
      final json = event.toJson();
      expect(json['willRetry'], isTrue);
    });
  });

  group('StageSkippedEvent', () {
    test('creation and toJson', () {
      final event = StageSkippedEvent(
        timestamp: DateTime(2024, 1, 1),
        runId: 'run-1',
        pipelineId: 'pipe-1',
        stageId: 'stage-1',
        reason: 'condition not met',
      );
      expect(event.toJson()['reason'], equals('condition not met'));
    });
  });

  group('GateEvaluatedEvent', () {
    test('creation and toJson', () {
      final event = GateEvaluatedEvent(
        timestamp: DateTime(2024, 1, 1),
        runId: 'run-1',
        pipelineId: 'pipe-1',
        gateId: 'g1',
        passed: true,
        conditions: {'c1': true, 'c2': false},
      );
      expect(event.toJson()['passed'], isTrue);
    });
  });

  group('CheckpointCreatedEvent (model)', () {
    test('creation and toJson', () {
      final event = model_events.CheckpointCreatedEvent(
        timestamp: DateTime(2024, 1, 1),
        runId: 'run-1',
        checkpointId: 'cp-1',
        name: 'checkpoint',
        lastStage: 'stage-2',
      );
      expect(event.toJson()['checkpointId'], equals('cp-1'));
    });
  });

  group('ExecutionResumedEvent', () {
    test('creation and toJson', () {
      final event = ExecutionResumedEvent(
        timestamp: DateTime(2024, 1, 1),
        runId: 'run-1',
        checkpointId: 'cp-1',
        resumeFromStage: 'stage-2',
      );
      expect(event.toJson()['resumeFromStage'], equals('stage-2'));
    });
  });

  group('WorkflowStartedEvent (model)', () {
    test('creation and toJson', () {
      final event = model_events.WorkflowStartedEvent(
        timestamp: DateTime(2024, 1, 1),
        runId: 'run-1',
        workflowId: 'wf-1',
      );
      expect(event.type, equals('workflow.started'));
    });
  });

  group('WorkflowCompletedEvent (model)', () {
    test('creation and toJson', () {
      final event = model_events.WorkflowCompletedEvent(
        timestamp: DateTime(2024, 1, 1),
        runId: 'run-1',
        workflowId: 'wf-1',
        success: true,
        duration: const Duration(seconds: 30),
      );
      expect(event.toJson()['durationMs'], equals(30000));
    });
  });

  group('ReviewRequestedEvent', () {
    test('creation and toJson', () {
      final event = ReviewRequestedEvent(
        timestamp: DateTime(2024, 1, 1),
        runId: 'run-1',
        stageId: 'stage-1',
        reviewers: ['user-1', 'user-2'],
      );
      expect(event.toJson()['reviewers'], equals(['user-1', 'user-2']));
    });
  });

  group('ReviewCompletedEvent', () {
    test('creation and toJson', () {
      final event = ReviewCompletedEvent(
        timestamp: DateTime(2024, 1, 1),
        runId: 'run-1',
        stageId: 'stage-1',
        decision: 'approve',
        reviewer: 'user-1',
      );
      expect(event.toJson()['decision'], equals('approve'));
    });
  });

  group('ApprovalRequestedEvent', () {
    test('creation and toJson', () {
      final event = ApprovalRequestedEvent(
        timestamp: DateTime(2024, 1, 1),
        runId: 'run-1',
        stageId: 'stage-1',
        approvers: ['user-1'],
        requiredApprovals: 1,
      );
      expect(event.toJson()['requiredApprovals'], equals(1));
    });
  });

  group('ApprovalCompletedEvent', () {
    test('creation and toJson', () {
      final event = ApprovalCompletedEvent(
        timestamp: DateTime(2024, 1, 1),
        runId: 'run-1',
        stageId: 'stage-1',
        approved: true,
        approver: 'user-1',
      );
      expect(event.toJson()['approved'], isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // WorkflowStage
  // ═══════════════════════════════════════════════════════════════

  group('WorkflowStage', () {
    test('creation with type', () {
      const stage = WorkflowStage(
        id: 'ws1',
        name: 'Review',
        handler: 'reviewHandler',
        type: WorkflowStageType.review,
        description: 'Code review stage',
      );
      expect(stage.type, equals(WorkflowStageType.review));
      expect(stage.description, equals('Code review stage'));
    });
  });

  group('WorkflowStageType', () {
    test('has all values', () {
      expect(
          WorkflowStageType.values,
          containsAll([
            WorkflowStageType.task,
            WorkflowStageType.gate,
            WorkflowStageType.review,
            WorkflowStageType.approval,
          ]));
    });
  });
}
