/// Tests for WorkflowConfig, WorkflowContext, and WorkflowStage.
import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  group('WorkflowConfig', () {
    test('defaults are correct', () {
      const config = WorkflowConfig();

      expect(config.timeout, isNull);
      expect(config.autoApprove, isFalse);
      expect(config.dryRun, isFalse);
      expect(config.publishOnSuccess, isFalse);
    });

    test('custom values are respected', () {
      const config = WorkflowConfig(
        timeout: Duration(hours: 2),
        autoApprove: true,
        dryRun: true,
        publishOnSuccess: true,
      );

      expect(config.timeout, equals(const Duration(hours: 2)));
      expect(config.autoApprove, isTrue);
      expect(config.dryRun, isTrue);
      expect(config.publishOnSuccess, isTrue);
    });
  });

  group('WorkflowContext', () {
    test('creation with required fields', () {
      final context = WorkflowContext(
        runId: 'run-1',
        workspaceId: 'ws-1',
        userId: 'user-1',
        asOf: DateTime(2024, 1, 1),
        config: const WorkflowConfig(),
      );

      expect(context.runId, equals('run-1'));
      expect(context.workspaceId, equals('ws-1'));
      expect(context.userId, equals('user-1'));
      expect(context.traceId, isNull);
    });

    test('creation with all fields including traceId', () {
      final context = WorkflowContext(
        runId: 'run-1',
        traceId: 'trace-1',
        workspaceId: 'ws-1',
        userId: 'user-1',
        asOf: DateTime(2024, 1, 1),
        config: const WorkflowConfig(autoApprove: true),
      );

      expect(context.traceId, equals('trace-1'));
      expect(context.config.autoApprove, isTrue);
    });
  });

  group('WorkflowStage', () {
    test('creation with type', () {
      const stage = WorkflowStage(
        id: 'validate',
        name: 'Validate',
        handler: 'skill.validate',
        type: WorkflowStageType.task,
        order: 1,
      );

      expect(stage.id, equals('validate'));
      expect(stage.name, equals('Validate'));
      expect(stage.handler, equals('skill.validate'));
      expect(stage.type, equals(WorkflowStageType.task));
      expect(stage.order, equals(1));
    });

    test('gate type stage', () {
      const stage = WorkflowStage(
        id: 'eval_gate',
        name: 'Evaluation Gate',
        handler: 'workflow.checkGate',
        type: WorkflowStageType.gate,
        order: 5,
        config: {'gateId': 'eval_pass'},
      );

      expect(stage.type, equals(WorkflowStageType.gate));
      expect(stage.config['gateId'], equals('eval_pass'));
    });

    test('review type with condition and timeout', () {
      const stage = WorkflowStage(
        id: 'human_review',
        name: 'Human Review',
        handler: 'approval.requestReview',
        type: WorkflowStageType.review,
        order: 7,
        condition: '!config.autoApprove',
        timeout: Duration(hours: 24),
      );

      expect(stage.type, equals(WorkflowStageType.review));
      expect(stage.condition, equals('!config.autoApprove'));
      expect(stage.timeout, equals(const Duration(hours: 24)));
    });

    test('description field', () {
      const stage = WorkflowStage(
        id: 'test',
        name: 'Test Stage',
        handler: 'test.handler',
        type: WorkflowStageType.task,
        description: 'This is a test stage',
      );

      expect(stage.description, equals('This is a test stage'));
    });
  });

  group('WorkflowStageType', () {
    test('has expected values', () {
      expect(WorkflowStageType.values, hasLength(4));
      expect(
        WorkflowStageType.values,
        containsAll([
          WorkflowStageType.task,
          WorkflowStageType.gate,
          WorkflowStageType.review,
          WorkflowStageType.approval,
        ]),
      );
    });
  });
}
