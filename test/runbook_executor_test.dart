/// Tests for RunbookExecutor.
import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  late HandlerRegistry handlers;

  setUp(() {
    handlers = HandlerRegistry();
  });

  RunbookContext _createContext() {
    return RunbookContext(
      runId: 'run-1',
      traceId: 'trace-1',
      workspaceId: 'ws-1',
    );
  }

  group('RunbookExecutor', () {
    test('execute simple runbook with pipeline step', () async {
      var pipelineCalled = false;
      final executor = RunbookExecutor(
        handlers: handlers,
        pipelineExecutor: (pipelineId, input) async {
          pipelineCalled = true;
          return {'status': 'completed'};
        },
      );

      const runbook = Runbook(
        id: 'rb-1',
        name: 'Simple Runbook',
        steps: [
          RunbookStep(
            id: 'step-1',
            name: 'Run Pipeline',
            action: RunbookAction(
              type: RunbookStepType.pipeline,
              pipelineId: 'test_pipeline',
            ),
          ),
        ],
      );

      final result = await executor.execute(
        runbook,
        {},
        _createContext(),
      );

      expect(result.success, isTrue);
      expect(result.steps, hasLength(1));
      expect(result.steps.first.success, isTrue);
      expect(pipelineCalled, isTrue);
    });

    test('variable validation rejects missing required variables', () async {
      final executor = RunbookExecutor(handlers: handlers);

      const runbook = Runbook(
        id: 'rb-1',
        name: 'Validated Runbook',
        steps: [
          RunbookStep(
            id: 'step-1',
            name: 'Step',
            action: RunbookAction(type: RunbookStepType.wait),
          ),
        ],
        variables: [
          RunbookVariable(name: 'required_var', required: true),
        ],
      );

      final result = await executor.execute(
        runbook,
        {},
        _createContext(),
      );

      expect(result.success, isFalse);
      expect(result.error, isNotNull);
      expect(result.error!.code, equals('VALIDATION_ERROR'));
      expect(result.error!.message, contains('required_var'));
    });

    test('step with condition=false is skipped (treated as success)', () async {
      final executor = RunbookExecutor(
        handlers: handlers,
        pipelineExecutor: (pipelineId, input) async {
          return {'status': 'completed'};
        },
      );

      const runbook = Runbook(
        id: 'rb-1',
        name: 'Conditional Runbook',
        steps: [
          RunbookStep(
            id: 'step-1',
            name: 'Conditional Step',
            condition: 'false',
            action: RunbookAction(
              type: RunbookStepType.pipeline,
              pipelineId: 'should_not_run',
            ),
          ),
        ],
      );

      final result = await executor.execute(
        runbook,
        {},
        _createContext(),
      );

      expect(result.success, isTrue);
      // The step is still recorded but was not actually executed
      expect(result.steps, hasLength(1));
    });

    test('onFailure=continue_ continues after step failure', () async {
      final executor = RunbookExecutor(
        handlers: handlers,
        pipelineExecutor: (pipelineId, input) async {
          if (pipelineId == 'fail_pipeline') {
            throw Exception('Pipeline failed');
          }
          return {'status': 'completed'};
        },
      );

      const runbook = Runbook(
        id: 'rb-1',
        name: 'Continue on Failure Runbook',
        steps: [
          RunbookStep(
            id: 'step-1',
            name: 'Failing Step',
            onFailure: RunbookOnFailure.continue_,
            action: RunbookAction(
              type: RunbookStepType.pipeline,
              pipelineId: 'fail_pipeline',
            ),
          ),
          RunbookStep(
            id: 'step-2',
            name: 'Next Step',
            action: RunbookAction(
              type: RunbookStepType.pipeline,
              pipelineId: 'success_pipeline',
            ),
          ),
        ],
      );

      final result = await executor.execute(
        runbook,
        {},
        _createContext(),
      );

      expect(result.success, isTrue);
      expect(result.steps, hasLength(2));
      // First step failed but execution continued
      expect(result.steps[0].success, isFalse);
      expect(result.steps[1].success, isTrue);
    });

    test('execute with workflow step', () async {
      var workflowCalled = false;
      final executor = RunbookExecutor(
        handlers: handlers,
        workflowExecutor: (workflowId, input) async {
          workflowCalled = true;
          return {'status': 'completed'};
        },
      );

      const runbook = Runbook(
        id: 'rb-1',
        name: 'Workflow Runbook',
        steps: [
          RunbookStep(
            id: 'step-1',
            name: 'Run Workflow',
            action: RunbookAction(
              type: RunbookStepType.workflow,
              workflowId: 'skill_build',
            ),
          ),
        ],
      );

      final result = await executor.execute(
        runbook,
        {},
        _createContext(),
      );

      expect(result.success, isTrue);
      expect(workflowCalled, isTrue);
    });

    test('default variables are merged with provided variables', () async {
      var capturedInput = <String, dynamic>{};
      final executor = RunbookExecutor(
        handlers: handlers,
        pipelineExecutor: (pipelineId, input) async {
          capturedInput = input;
          return {'status': 'ok'};
        },
      );

      const runbook = Runbook(
        id: 'rb-1',
        name: 'Defaults Test',
        steps: [
          RunbookStep(
            id: 'step-1',
            name: 'Step',
            action: RunbookAction(
              type: RunbookStepType.pipeline,
              pipelineId: 'test',
            ),
          ),
        ],
        variables: [
          RunbookVariable(name: 'mode', defaultValue: 'auto'),
          RunbookVariable(name: 'limit', defaultValue: 100),
        ],
      );

      await executor.execute(
        runbook,
        {'limit': 200},
        _createContext(),
      );

      // The context state should have mode=auto (default) and limit=200 (override)
      // Since the pipeline executor receives the full context state
      expect(capturedInput['mode'], equals('auto'));
      expect(capturedInput['limit'], equals(200));
    });
  });

  group('RunbookContext', () {
    test('creation with required fields', () {
      final context = RunbookContext(
        runId: 'run-1',
        workspaceId: 'ws-1',
      );

      expect(context.runId, equals('run-1'));
      expect(context.workspaceId, equals('ws-1'));
      expect(context.traceId, isNull);
      expect(context.state, isEmpty);
    });

    test('creation with state', () {
      final context = RunbookContext(
        runId: 'run-1',
        workspaceId: 'ws-1',
        state: {'key': 'value'},
      );

      expect(context.state, equals({'key': 'value'}));
    });
  });

  group('RunbookResult', () {
    test('success result', () {
      const result = RunbookResult(
        success: true,
        steps: [
          RunbookStepResult(
            stepId: 'step-1',
            success: true,
            duration: Duration(seconds: 1),
          ),
        ],
        metrics: RunbookMetrics(totalDuration: Duration(seconds: 1)),
      );

      expect(result.success, isTrue);
      expect(result.steps, hasLength(1));
      expect(result.error, isNull);
    });

    test('failure result with error', () {
      const result = RunbookResult(
        success: false,
        steps: [],
        error: RunbookError(
          code: 'EXECUTION_ERROR',
          message: 'Step failed',
          stepId: 'step-1',
        ),
        metrics: RunbookMetrics(totalDuration: Duration.zero),
      );

      expect(result.success, isFalse);
      expect(result.error, isNotNull);
      expect(result.error!.code, equals('EXECUTION_ERROR'));
      expect(result.error!.stepId, equals('step-1'));
    });
  });
}
