/// ExecutionEngine Tests - Tests for pipeline and workflow execution.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // ExecutionEngine - Pipeline Execution
  // ═══════════════════════════════════════════════════════════════

  group('ExecutionEngine - executePipeline', () {
    late HandlerRegistry handlers;
    late ExecutionEngine engine;

    setUp(() {
      handlers = HandlerRegistry();
      engine = ExecutionEngine(
        config: const ExecutionEngineConfig(),
        handlers: handlers,
      );
    });

    test('single stage pipeline - handler executes and returns result',
        () async {
      handlers.register(
        'echo',
        FunctionHandler(
          name: 'echo',
          handler: (input, ctx) async {
            ctx.executionContext?.setState('_output', input);
            return input;
          },
        ),
      );

      final pipeline = PipelineDefinition(
        id: 'pipe-1',
        name: 'Echo Pipeline',
        stages: [
          const Stage(id: 'stage-1', name: 'Echo', handler: 'echo'),
        ],
      );

      final context = testExecutionContext(
        config: const ExecutionConfig(checkpointEnabled: false),
      );
      final result = await engine.executePipeline(pipeline, 'hello', context);

      expect(result.success, isTrue);
      expect(result.stages.length, equals(1));
      expect(result.stages.first.status, equals(StageStatus.completed));
    });

    test('multiple stages execute in order', () async {
      final executionOrder = <String>[];

      handlers.register(
        'step-1',
        FunctionHandler(
          name: 'step-1',
          handler: (input, ctx) async {
            executionOrder.add('step-1');
            return 'output-1';
          },
        ),
      );

      handlers.register(
        'step-2',
        FunctionHandler(
          name: 'step-2',
          handler: (input, ctx) async {
            executionOrder.add('step-2');
            return 'output-2';
          },
        ),
      );

      handlers.register(
        'step-3',
        FunctionHandler(
          name: 'step-3',
          handler: (input, ctx) async {
            executionOrder.add('step-3');
            return 'output-3';
          },
        ),
      );

      final pipeline = PipelineDefinition(
        id: 'pipe-multi',
        name: 'Multi-stage Pipeline',
        stages: [
          const Stage(
              id: 'stage-1', name: 'Step 1', handler: 'step-1', order: 0),
          const Stage(
              id: 'stage-2', name: 'Step 2', handler: 'step-2', order: 1),
          const Stage(
              id: 'stage-3', name: 'Step 3', handler: 'step-3', order: 2),
        ],
      );

      final context = testExecutionContext(
        config: const ExecutionConfig(checkpointEnabled: false),
      );
      final result = await engine.executePipeline(pipeline, null, context);

      expect(result.success, isTrue);
      expect(result.stages.length, equals(3));
      expect(executionOrder, equals(['step-1', 'step-2', 'step-3']));
    });

    test('pipeline with failing stage returns failure result', () async {
      handlers.register(
        'fail-handler',
        FunctionHandler(
          name: 'fail-handler',
          handler: (input, ctx) async {
            throw Exception('Stage failed');
          },
        ),
      );

      final pipeline = PipelineDefinition(
        id: 'pipe-fail',
        name: 'Failing Pipeline',
        stages: [
          const Stage(
              id: 'stage-fail', name: 'Fail Stage', handler: 'fail-handler'),
        ],
      );

      final context = testExecutionContext(
        config: const ExecutionConfig(checkpointEnabled: false),
      );
      final result = await engine.executePipeline(pipeline, null, context);

      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });

    test('pipeline with missing handler returns failure result', () async {
      final pipeline = PipelineDefinition(
        id: 'pipe-missing',
        name: 'Missing Handler Pipeline',
        stages: [
          const Stage(
            id: 'stage-1',
            name: 'Missing',
            handler: 'nonexistent',
          ),
        ],
      );

      final context = testExecutionContext(
        config: const ExecutionConfig(checkpointEnabled: false),
      );
      final result = await engine.executePipeline(pipeline, null, context);

      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });

    test('pipeline stops at failed stage', () async {
      final executedStages = <String>[];

      handlers.register(
        'ok-handler',
        FunctionHandler(
          name: 'ok-handler',
          handler: (input, ctx) async {
            executedStages.add(ctx.stageId);
            return 'ok';
          },
        ),
      );

      handlers.register(
        'bad-handler',
        FunctionHandler(
          name: 'bad-handler',
          handler: (input, ctx) async {
            executedStages.add(ctx.stageId);
            throw Exception('failure');
          },
        ),
      );

      final pipeline = PipelineDefinition(
        id: 'pipe-stop',
        name: 'Stop on Fail Pipeline',
        stages: [
          const Stage(
              id: 'stage-ok', name: 'OK', handler: 'ok-handler'),
          const Stage(
              id: 'stage-bad', name: 'Bad', handler: 'bad-handler'),
          const Stage(
              id: 'stage-after', name: 'After', handler: 'ok-handler'),
        ],
      );

      final context = testExecutionContext(
        config: const ExecutionConfig(checkpointEnabled: false),
      );
      final result = await engine.executePipeline(pipeline, null, context);

      expect(result.success, isFalse);
      // stage-after should not have executed
      expect(executedStages, contains('stage-ok'));
      expect(executedStages, contains('stage-bad'));
      expect(executedStages, isNot(contains('stage-after')));
    });

    test('pipeline with gate - gate evaluates after stage', () async {
      handlers.register(
        'score-handler',
        FunctionHandler(
          name: 'score-handler',
          handler: (input, ctx) async {
            return {'score': 0.95};
          },
        ),
      );

      final pipeline = PipelineDefinition(
        id: 'pipe-gate',
        name: 'Pipeline with Gate',
        stages: [
          const Stage(
            id: 'stage-1',
            name: 'Score Stage',
            handler: 'score-handler',
          ),
        ],
        gates: [
          Gate(
            id: 'quality-gate',
            name: 'Quality Check',
            afterStage: 'stage-1',
            conditions: [
              const GateCondition(
                type: ConditionType.expression,
                expression: 'true',
              ),
            ],
          ),
        ],
      );

      final context = testExecutionContext(
        config: const ExecutionConfig(checkpointEnabled: false),
      );
      final result = await engine.executePipeline(pipeline, null, context);

      expect(result.success, isTrue);
      expect(result.gates.length, equals(1));
      expect(result.gates.first.passed, isTrue);
    });

    test('pipeline with blocking gate failure stops execution', () async {
      handlers.register(
        'handler-a',
        FunctionHandler(
          name: 'handler-a',
          handler: (input, ctx) async => 'a-output',
        ),
      );
      handlers.register(
        'handler-b',
        FunctionHandler(
          name: 'handler-b',
          handler: (input, ctx) async => 'b-output',
        ),
      );

      final pipeline = PipelineDefinition(
        id: 'pipe-block',
        name: 'Blocking Gate Pipeline',
        stages: [
          const Stage(
              id: 'stage-a', name: 'Stage A', handler: 'handler-a'),
          const Stage(
              id: 'stage-b', name: 'Stage B', handler: 'handler-b'),
        ],
        gates: [
          Gate(
            id: 'block-gate',
            name: 'Blocking Gate',
            afterStage: 'stage-a',
            onFailure: GateFailure.block,
            conditions: [
              const GateCondition(
                type: ConditionType.expression,
                expression: 'false',
              ),
            ],
          ),
        ],
      );

      final context = testExecutionContext(
        config: const ExecutionConfig(checkpointEnabled: false),
      );
      final result = await engine.executePipeline(pipeline, null, context);

      expect(result.success, isFalse);
      // Only first stage should have run
      expect(result.stages.length, equals(1));
    });

    test('pipeline metrics include total duration', () async {
      handlers.register(
        'fast-handler',
        FunctionHandler(
          name: 'fast-handler',
          handler: (input, ctx) async => 'fast',
        ),
      );

      final pipeline = PipelineDefinition(
        id: 'pipe-metrics',
        name: 'Metrics Pipeline',
        stages: [
          const Stage(
              id: 'stage-1', name: 'Fast', handler: 'fast-handler'),
        ],
      );

      final context = testExecutionContext(
        config: const ExecutionConfig(checkpointEnabled: false),
      );
      final result = await engine.executePipeline(pipeline, null, context);

      expect(result.metrics.totalDuration, isA<Duration>());
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // ExecutionEngine - Workflow Execution
  // ═══════════════════════════════════════════════════════════════

  group('ExecutionEngine - executeWorkflow', () {
    late HandlerRegistry handlers;
    late ExecutionEngine engine;

    setUp(() {
      handlers = HandlerRegistry();
      engine = ExecutionEngine(
        config: const ExecutionEngineConfig(),
        handlers: handlers,
      );
    });

    test('single task stage workflow executes', () async {
      handlers.register(
        'build-handler',
        FunctionHandler(
          name: 'build-handler',
          handler: (input, ctx) async {
            ctx.executionContext?.setState('_output', 'built');
            return 'built';
          },
        ),
      );

      final workflow = WorkflowDefinition(
        id: 'wf-1',
        name: 'Build Workflow',
        stages: [
          const WorkflowStage(
            id: 'build',
            name: 'Build',
            handler: 'build-handler',
            type: WorkflowStageType.task,
          ),
        ],
      );

      final context = testExecutionContext(
        config: const ExecutionConfig(checkpointEnabled: false),
      );
      final result = await engine.executeWorkflow(workflow, null, context);

      expect(result.success, isTrue);
      expect(result.stages.length, equals(1));
      expect(result.stages.first.status, equals(StageStatus.completed));
    });

    test('workflow with failing stage returns failure', () async {
      handlers.register(
        'fail-build',
        FunctionHandler(
          name: 'fail-build',
          handler: (input, ctx) async {
            throw Exception('Build failed');
          },
        ),
      );

      final workflow = WorkflowDefinition(
        id: 'wf-fail',
        name: 'Failing Workflow',
        stages: [
          const WorkflowStage(
            id: 'build',
            name: 'Build',
            handler: 'fail-build',
            type: WorkflowStageType.task,
          ),
        ],
      );

      final context = testExecutionContext(
        config: const ExecutionConfig(checkpointEnabled: false),
      );
      final result = await engine.executeWorkflow(workflow, null, context);

      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });

    test('workflow with multiple stages executes in order', () async {
      final executionOrder = <String>[];

      handlers.register(
        'wf-step-1',
        FunctionHandler(
          name: 'wf-step-1',
          handler: (input, ctx) async {
            executionOrder.add('step-1');
            return 'output-1';
          },
        ),
      );

      handlers.register(
        'wf-step-2',
        FunctionHandler(
          name: 'wf-step-2',
          handler: (input, ctx) async {
            executionOrder.add('step-2');
            return 'output-2';
          },
        ),
      );

      final workflow = WorkflowDefinition(
        id: 'wf-multi',
        name: 'Multi-stage Workflow',
        stages: [
          const WorkflowStage(
            id: 'stage-1',
            name: 'Step 1',
            handler: 'wf-step-1',
            type: WorkflowStageType.task,
          ),
          const WorkflowStage(
            id: 'stage-2',
            name: 'Step 2',
            handler: 'wf-step-2',
            type: WorkflowStageType.task,
          ),
        ],
      );

      final context = testExecutionContext(
        config: const ExecutionConfig(checkpointEnabled: false),
      );
      final result = await engine.executeWorkflow(workflow, null, context);

      expect(result.success, isTrue);
      expect(executionOrder, equals(['step-1', 'step-2']));
    });

    test('workflow metrics include total duration', () async {
      handlers.register(
        'wf-handler',
        FunctionHandler(
          name: 'wf-handler',
          handler: (input, ctx) async => 'done',
        ),
      );

      final workflow = WorkflowDefinition(
        id: 'wf-metrics',
        name: 'Metrics Workflow',
        stages: [
          const WorkflowStage(
            id: 'stage-1',
            name: 'Step 1',
            handler: 'wf-handler',
            type: WorkflowStageType.task,
          ),
        ],
      );

      final context = testExecutionContext(
        config: const ExecutionConfig(checkpointEnabled: false),
      );
      final result = await engine.executeWorkflow(workflow, null, context);

      expect(result.metrics.totalDuration, isA<Duration>());
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // ExecutionEngine - Event Listener
  // ═══════════════════════════════════════════════════════════════

  group('ExecutionEngine - event listener', () {
    test('event listener receives pipeline lifecycle events', () async {
      final events = <String>[];
      final listener = _TestEventListener(events: events);

      final handlers = HandlerRegistry();
      handlers.register(
        'handler',
        FunctionHandler(
          name: 'handler',
          handler: (input, ctx) async => 'result',
        ),
      );

      final engine = ExecutionEngine(
        config: const ExecutionEngineConfig(),
        handlers: handlers,
        eventListener: listener,
      );

      final pipeline = PipelineDefinition(
        id: 'pipe-events',
        name: 'Events Pipeline',
        stages: [
          const Stage(
              id: 'stage-1', name: 'Stage 1', handler: 'handler'),
        ],
      );

      final context = testExecutionContext(
        config: const ExecutionConfig(checkpointEnabled: false),
      );
      await engine.executePipeline(pipeline, null, context);

      expect(events, contains('pipelineStarted:pipe-events'));
      expect(events, contains('stageStarted:stage-1'));
      expect(events, contains('stageCompleted:stage-1'));
      expect(events, contains('pipelineCompleted:pipe-events'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // ExecutionEngineConfig
  // ═══════════════════════════════════════════════════════════════

  group('ExecutionEngineConfig', () {
    test('default values', () {
      const config = ExecutionEngineConfig();
      expect(config.maxConcurrentExecutions, equals(4));
      expect(config.executionDefaults, isA<ExecutionConfig>());
    });

    test('custom values', () {
      const config = ExecutionEngineConfig(
        maxConcurrentExecutions: 8,
        executionDefaults: ExecutionConfig(dryRun: true),
      );
      expect(config.maxConcurrentExecutions, equals(8));
      expect(config.executionDefaults.dryRun, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // PipelineDefinition / WorkflowDefinition
  // ═══════════════════════════════════════════════════════════════

  group('PipelineDefinition', () {
    test('creates with required fields', () {
      const pipeline = PipelineDefinition(
        id: 'p-1',
        name: 'Test Pipeline',
        stages: [],
      );
      expect(pipeline.id, equals('p-1'));
      expect(pipeline.name, equals('Test Pipeline'));
      expect(pipeline.version, equals('1.0.0'));
      expect(pipeline.description, isNull);
      expect(pipeline.stages, isEmpty);
      expect(pipeline.gates, isEmpty);
      expect(pipeline.config, isEmpty);
    });
  });

  group('WorkflowDefinition', () {
    test('creates with required fields', () {
      const workflow = WorkflowDefinition(
        id: 'w-1',
        name: 'Test Workflow',
        stages: [],
      );
      expect(workflow.id, equals('w-1'));
      expect(workflow.name, equals('Test Workflow'));
      expect(workflow.version, equals('1.0.0'));
      expect(workflow.description, isNull);
      expect(workflow.stages, isEmpty);
      expect(workflow.gates, isEmpty);
      expect(workflow.config, isEmpty);
    });
  });
}

/// Test event listener that records event names.
class _TestEventListener extends ExecutionEventListener {
  final List<String> events;

  _TestEventListener({required this.events});

  @override
  void onPipelineStarted(String pipelineId, String runId) {
    events.add('pipelineStarted:$pipelineId');
  }

  @override
  void onPipelineCompleted(
      String pipelineId, String runId, PipelineMetrics metrics) {
    events.add('pipelineCompleted:$pipelineId');
  }

  @override
  void onPipelineFailed(String pipelineId, String runId, Object error) {
    events.add('pipelineFailed:$pipelineId');
  }

  @override
  void onStageStarted(String stageId, String runId) {
    events.add('stageStarted:$stageId');
  }

  @override
  void onStageCompleted(String stageId, String runId, Duration duration) {
    events.add('stageCompleted:$stageId');
  }

  @override
  void onStageFailed(String stageId, String runId, Object error) {
    events.add('stageFailed:$stageId');
  }

  @override
  void onStageSkipped(String stageId, String runId, String reason) {
    events.add('stageSkipped:$stageId');
  }

  @override
  void onWorkflowStarted(String workflowId, String runId) {
    events.add('workflowStarted:$workflowId');
  }

  @override
  void onWorkflowCompleted(
      String workflowId, String runId, WorkflowMetrics metrics) {
    events.add('workflowCompleted:$workflowId');
  }

  @override
  void onWorkflowFailed(String workflowId, String runId, Object error) {
    events.add('workflowFailed:$workflowId');
  }

  @override
  void onGateEvaluated(String gateId, GateResult result) {
    events.add('gateEvaluated:$gateId');
  }

  @override
  void onGateWarning(String gateId, GateResult result) {
    events.add('gateWarning:$gateId');
  }

  @override
  void onGateLogged(String gateId, GateResult result) {
    events.add('gateLogged:$gateId');
  }

  @override
  void onCheckpoint(String runId, Checkpoint checkpoint) {
    events.add('checkpoint:$runId');
  }
}
