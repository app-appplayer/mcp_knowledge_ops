/// Typed Events Tests - Tests for all 28 typed OpsEvent subclasses.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';
// Import typed events directly for names hidden from barrel export
// (they conflict with scheduler_events.dart canonical versions).
import 'package:mcp_knowledge_ops/src/events/typed_events.dart' as typed;

void main() {
  // Common test meta and correlation context
  final meta = OpsEventMeta(source: 'test');

  // ═══════════════════════════════════════════════════════════════
  // Pipeline Events
  // ═══════════════════════════════════════════════════════════════

  group('Pipeline Events', () {
    test('PipelineStartedEvent.create()', () {
      final event = PipelineStartedEvent.create(
        pipelineId: 'pipe-1',
        input: {'data': 'hello'},
        pipelineName: 'Test Pipeline',
        pipelineVersion: '1.0.0',
        stages: ['stage-a', 'stage-b'],
        config: {'timeout': 30},
        correlationId: 'corr-1',
        runId: 'run-1',
        workspaceId: 'ws-1',
        meta: meta,
      );

      expect(event.eventType, equals('ops.pipeline.started'));
      expect(event.pipelineId, equals('pipe-1'));
      expect(event.pipelineName, equals('Test Pipeline'));
      expect(event.payload['pipelineId'], equals('pipe-1'));
      expect(event.payload['stages'], equals(['stage-a', 'stage-b']));
      expect(event.eventId, isNotEmpty);
      expect(event.correlationId, equals('corr-1'));
    });

    test('PipelineStageCompletedEvent.create()', () {
      final event = PipelineStageCompletedEvent.create(
        pipelineId: 'pipe-2',
        stageId: 'stage-1',
        output: {'result': 'ok'},
        stageName: 'Ingestion',
        stageIndex: 0,
        result: {'processed': 10},
        duration: const Duration(milliseconds: 500),
        correlationId: 'corr-2',
        runId: 'run-2',
        workspaceId: 'ws-2',
        meta: meta,
      );

      expect(event.eventType, equals('ops.pipeline.stage_completed'));
      expect(event.pipelineId, equals('pipe-2'));
      expect(event.stageId, equals('stage-1'));
      expect(event.payload['stageId'], equals('stage-1'));
      expect(event.payload['durationMs'], equals(500));
    });

    test('PipelineCompletedEvent.create()', () {
      final event = PipelineCompletedEvent.create(
        pipelineId: 'pipe-3',
        result: {'summary': 'done'},
        pipelineName: 'Curation',
        status: 'success',
        stagesCompleted: 3,
        totalStages: 3,
        duration: const Duration(seconds: 5),
        output: {'items': 42},
        metrics: {'avgDuration': 1.5},
        correlationId: 'corr-3',
        runId: 'run-3',
        workspaceId: 'ws-3',
        meta: meta,
      );

      expect(event.eventType, equals('ops.pipeline.completed'));
      expect(event.pipelineId, equals('pipe-3'));
      expect(event.payload['pipelineId'], equals('pipe-3'));
      expect(event.payload['stagesCompleted'], equals(3));
      expect(event.payload['durationMs'], equals(5000));
    });

    test('PipelineFailedEvent.create()', () {
      final event = PipelineFailedEvent.create(
        pipelineId: 'pipe-4',
        error: 'Stage timeout',
        failedStage: 'stage-2',
        pipelineName: 'IndexRebuild',
        stageIndex: 1,
        errorCode: 'TIMEOUT',
        errorStack: 'at line 42',
        partialOutput: {'partial': true},
        retryable: true,
        correlationId: 'corr-4',
        runId: 'run-4',
        workspaceId: 'ws-4',
        meta: meta,
      );

      expect(event.eventType, equals('ops.pipeline.failed'));
      expect(event.pipelineId, equals('pipe-4'));
      expect(event.error, equals('Stage timeout'));
      expect(event.payload['error'], equals('Stage timeout'));
      expect(event.payload['retryable'], isTrue);
      expect(event.payload['failedStage'], equals('stage-2'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Workflow Events
  // ═══════════════════════════════════════════════════════════════

  group('Workflow Events', () {
    test('WorkflowStartedEvent.create()', () {
      final event = WorkflowStartedEvent.create(
        workflowId: 'wf-1',
        input: {'source': 'manual'},
        workflowName: 'Skill Build',
        workflowVersion: '2.0',
        steps: ['compile', 'test', 'package'],
        gates: ['quality-gate'],
        correlationId: 'corr-wf1',
        runId: 'run-wf1',
        workspaceId: 'ws-wf1',
        meta: meta,
      );

      expect(event.eventType, equals('ops.workflow.started'));
      expect(event.workflowId, equals('wf-1'));
      expect(event.workflowName, equals('Skill Build'));
      expect(event.payload['workflowId'], equals('wf-1'));
      expect(event.payload['steps'], equals(['compile', 'test', 'package']));
    });

    test('WorkflowStepCompletedEvent.create()', () {
      final event = WorkflowStepCompletedEvent.create(
        workflowId: 'wf-2',
        stepId: 'step-compile',
        output: {'artifact': 'build.zip'},
        correlationId: 'corr-wf2',
        runId: 'run-wf2',
        workspaceId: 'ws-wf2',
        meta: meta,
      );

      expect(event.eventType, equals('ops.workflow.step_completed'));
      expect(event.workflowId, equals('wf-2'));
      expect(event.stepId, equals('step-compile'));
      expect(event.payload['stepId'], equals('step-compile'));
    });

    test('WorkflowGateEvaluatedEvent.create()', () {
      final event = WorkflowGateEvaluatedEvent.create(
        workflowId: 'wf-3',
        gateId: 'gate-quality',
        passed: true,
        gateName: 'Quality Gate',
        resultState: 'approved',
        conditions: [
          {'metric': 'coverage', 'threshold': 80, 'actual': 95}
        ],
        action: 'proceed',
        correlationId: 'corr-wf3',
        runId: 'run-wf3',
        workspaceId: 'ws-wf3',
        meta: meta,
      );

      expect(event.eventType, equals('ops.workflow.gate_evaluated'));
      expect(event.workflowId, equals('wf-3'));
      expect(event.gateId, equals('gate-quality'));
      expect(event.passed, isTrue);
      expect(event.payload['passed'], isTrue);
      expect(event.payload['gateName'], equals('Quality Gate'));
    });

    test('WorkflowApprovalRequestedEvent.create()', () {
      final deadline = DateTime(2024, 12, 31);
      final event = WorkflowApprovalRequestedEvent.create(
        workflowId: 'wf-4',
        approvalId: 'appr-1',
        approvers: ['user-a', 'user-b'],
        gateId: 'gate-review',
        deadline: deadline,
        context: {'priority': 'high'},
        correlationId: 'corr-wf4',
        runId: 'run-wf4',
        workspaceId: 'ws-wf4',
        meta: meta,
      );

      expect(event.eventType, equals('ops.workflow.approval_requested'));
      expect(event.workflowId, equals('wf-4'));
      expect(event.approvalId, equals('appr-1'));
      expect(event.approvers, equals(['user-a', 'user-b']));
      expect(event.payload['approvers'], equals(['user-a', 'user-b']));
      expect(event.payload['gateId'], equals('gate-review'));
    });

    test('WorkflowApprovalReceivedEvent.create()', () {
      final decisionTime = DateTime(2024, 12, 25, 14, 30);
      final event = WorkflowApprovalReceivedEvent.create(
        workflowId: 'wf-5',
        approvalId: 'appr-2',
        approved: false,
        approver: 'user-b',
        decision: 'rejected',
        comment: 'Needs more tests',
        decisionTimestamp: decisionTime,
        correlationId: 'corr-wf5',
        runId: 'run-wf5',
        workspaceId: 'ws-wf5',
        meta: meta,
      );

      expect(event.eventType, equals('ops.workflow.approval_received'));
      expect(event.workflowId, equals('wf-5'));
      expect(event.approved, isFalse);
      expect(event.approver, equals('user-b'));
      expect(event.payload['approved'], isFalse);
      expect(event.payload['comment'], equals('Needs more tests'));
    });

    test('WorkflowCompletedEvent.create()', () {
      final event = WorkflowCompletedEvent.create(
        workflowId: 'wf-6',
        result: {'final': 'output'},
        workflowName: 'Bundle Build',
        status: 'completed',
        stepsCompleted: 5,
        gatesPassed: 2,
        duration: const Duration(minutes: 10),
        output: {'bundleId': 'b-1'},
        artifacts: [
          {'name': 'bundle.tar', 'size': 1024}
        ],
        correlationId: 'corr-wf6',
        runId: 'run-wf6',
        workspaceId: 'ws-wf6',
        meta: meta,
      );

      expect(event.eventType, equals('ops.workflow.completed'));
      expect(event.workflowId, equals('wf-6'));
      expect(event.payload['workflowId'], equals('wf-6'));
      expect(event.payload['stepsCompleted'], equals(5));
      expect(event.payload['durationMs'], equals(600000));
    });

    test('WorkflowFailedEvent.create()', () {
      final event = WorkflowFailedEvent.create(
        workflowId: 'wf-7',
        error: 'Gate not passed',
        correlationId: 'corr-wf7',
        runId: 'run-wf7',
        workspaceId: 'ws-wf7',
        meta: meta,
      );

      expect(event.eventType, equals('ops.workflow.failed'));
      expect(event.workflowId, equals('wf-7'));
      expect(event.error, equals('Gate not passed'));
      expect(event.payload['error'], equals('Gate not passed'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Schedule Events (from typed_events.dart, prefixed as typed)
  // ═══════════════════════════════════════════════════════════════

  group('Schedule Events (typed)', () {
    test('ScheduleRegisteredEvent.create()', () {
      final event = ScheduleRegisteredEvent.create(
        scheduleId: 'sched-1',
        name: 'Nightly Refresh',
        correlationId: 'corr-s1',
        runId: 'run-s1',
        workspaceId: 'ws-s1',
        meta: meta,
      );

      expect(event.eventType, equals('ops.schedule.registered'));
      expect(event.scheduleId, equals('sched-1'));
      expect(event.name, equals('Nightly Refresh'));
      expect(event.payload['scheduleId'], equals('sched-1'));
      expect(event.payload['name'], equals('Nightly Refresh'));
    });

    test('typed.ScheduleTriggeredEvent.create()', () {
      final event = typed.ScheduleTriggeredEvent.create(
        scheduleId: 'sched-2',
        executionId: 'exec-2',
        correlationId: 'corr-s2',
        runId: 'run-s2',
        workspaceId: 'ws-s2',
        meta: meta,
      );

      expect(event.eventType, equals('ops.schedule.triggered'));
      expect(event.scheduleId, equals('sched-2'));
      expect(event.executionId, equals('exec-2'));
      expect(event.payload['executionId'], equals('exec-2'));
    });

    test('typed.SchedulePausedEvent.create()', () {
      final event = typed.SchedulePausedEvent.create(
        scheduleId: 'sched-3',
        correlationId: 'corr-s3',
        runId: 'run-s3',
        workspaceId: 'ws-s3',
        meta: meta,
      );

      expect(event.eventType, equals('ops.schedule.paused'));
      expect(event.scheduleId, equals('sched-3'));
      expect(event.payload['scheduleId'], equals('sched-3'));
    });

    test('typed.ScheduleResumedEvent.create()', () {
      final event = typed.ScheduleResumedEvent.create(
        scheduleId: 'sched-4',
        correlationId: 'corr-s4',
        runId: 'run-s4',
        workspaceId: 'ws-s4',
        meta: meta,
      );

      expect(event.eventType, equals('ops.schedule.resumed'));
      expect(event.scheduleId, equals('sched-4'));
      expect(event.payload['scheduleId'], equals('sched-4'));
    });

    test('typed.ScheduleDeletedEvent.create()', () {
      final event = typed.ScheduleDeletedEvent.create(
        scheduleId: 'sched-5',
        correlationId: 'corr-s5',
        runId: 'run-s5',
        workspaceId: 'ws-s5',
        meta: meta,
      );

      expect(event.eventType, equals('ops.schedule.deleted'));
      expect(event.scheduleId, equals('sched-5'));
      expect(event.payload['scheduleId'], equals('sched-5'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Execution Events (some prefixed as typed due to barrel conflicts)
  // ═══════════════════════════════════════════════════════════════

  group('Execution Events (typed)', () {
    test('typed.ExecutionQueuedEvent.create()', () {
      final scheduledFor = DateTime(2024, 7, 1, 8, 0);
      final event = typed.ExecutionQueuedEvent.create(
        executionId: 'exec-q1',
        scheduleId: 'sched-q1',
        targetType: 'pipeline',
        targetId: 'pipe-target',
        priority: 5,
        scheduledFor: scheduledFor,
        triggeredBy: 'user-admin',
        correlationId: 'corr-eq1',
        runId: 'run-eq1',
        workspaceId: 'ws-eq1',
        meta: meta,
      );

      expect(event.eventType, equals('ops.execution.queued'));
      expect(event.executionId, equals('exec-q1'));
      expect(event.payload['executionId'], equals('exec-q1'));
      expect(event.payload['priority'], equals(5));
      expect(event.payload['triggeredBy'], equals('user-admin'));
    });

    test('typed.ExecutionStartedEvent.create()', () {
      final event = typed.ExecutionStartedEvent.create(
        executionId: 'exec-s1',
        correlationId: 'corr-es1',
        runId: 'run-es1',
        workspaceId: 'ws-es1',
        meta: meta,
      );

      expect(event.eventType, equals('ops.execution.started'));
      expect(event.executionId, equals('exec-s1'));
      expect(event.payload['executionId'], equals('exec-s1'));
    });

    test('CheckpointCreatedEvent.create()', () {
      final event = CheckpointCreatedEvent.create(
        executionId: 'exec-cp1',
        checkpointId: 'cp-1',
        stageId: 'stage-3',
        state: {'counter': 10},
        recoverable: true,
        correlationId: 'corr-cp1',
        runId: 'run-cp1',
        workspaceId: 'ws-cp1',
        meta: meta,
      );

      expect(event.eventType, equals('ops.execution.checkpoint_created'));
      expect(event.executionId, equals('exec-cp1'));
      expect(event.checkpointId, equals('cp-1'));
      expect(event.payload['checkpointId'], equals('cp-1'));
      expect(event.payload['recoverable'], isTrue);
    });

    test('CheckpointRestoredEvent.create()', () {
      final event = CheckpointRestoredEvent.create(
        executionId: 'exec-cr1',
        checkpointId: 'cp-2',
        correlationId: 'corr-cr1',
        runId: 'run-cr1',
        workspaceId: 'ws-cr1',
        meta: meta,
      );

      expect(event.eventType, equals('ops.execution.checkpoint_restored'));
      expect(event.executionId, equals('exec-cr1'));
      expect(event.checkpointId, equals('cp-2'));
      expect(event.payload['executionId'], equals('exec-cr1'));
      expect(event.payload['checkpointId'], equals('cp-2'));
    });

    test('typed.ExecutionCompletedEvent.create()', () {
      final event = typed.ExecutionCompletedEvent.create(
        executionId: 'exec-c1',
        success: true,
        correlationId: 'corr-ec1',
        runId: 'run-ec1',
        workspaceId: 'ws-ec1',
        meta: meta,
      );

      expect(event.eventType, equals('ops.execution.completed'));
      expect(event.executionId, equals('exec-c1'));
      expect(event.success, isTrue);
      expect(event.payload['success'], isTrue);
    });

    test('typed.ExecutionFailedEvent.create()', () {
      final event = typed.ExecutionFailedEvent.create(
        executionId: 'exec-f1',
        error: 'Out of memory',
        correlationId: 'corr-ef1',
        runId: 'run-ef1',
        workspaceId: 'ws-ef1',
        meta: meta,
      );

      expect(event.eventType, equals('ops.execution.failed'));
      expect(event.executionId, equals('exec-f1'));
      expect(event.error, equals('Out of memory'));
      expect(event.payload['error'], equals('Out of memory'));
    });

    test('ExecutionRolledBackEvent.create()', () {
      final event = ExecutionRolledBackEvent.create(
        executionId: 'exec-rb1',
        reason: 'Data corruption detected',
        checkpointId: 'cp-restore',
        rollbackReason: 'integrity-check-failed',
        affectedStages: ['stage-2', 'stage-3'],
        compensatingActions: ['revert-writes', 'notify-admin'],
        correlationId: 'corr-rb1',
        runId: 'run-rb1',
        workspaceId: 'ws-rb1',
        meta: meta,
      );

      expect(event.eventType, equals('ops.execution.rolled_back'));
      expect(event.executionId, equals('exec-rb1'));
      expect(event.payload['executionId'], equals('exec-rb1'));
      expect(event.payload['reason'], equals('Data corruption detected'));
      expect(event.payload['affectedStages'], equals(['stage-2', 'stage-3']));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Integration Events
  // ═══════════════════════════════════════════════════════════════

  group('Integration Events', () {
    test('FactGraphUpdatedEvent.create()', () {
      final event = FactGraphUpdatedEvent.create(
        factId: 'fact-1',
        operation: 'update',
        entityType: 'KnowledgeItem',
        entityId: 'item-42',
        changes: [
          {'field': 'title', 'oldValue': 'old', 'newValue': 'new'}
        ],
        triggeredBy: 'pipeline-ingest',
        correlationId: 'corr-fg1',
        runId: 'run-fg1',
        workspaceId: 'ws-fg1',
        meta: meta,
      );

      expect(event.eventType, equals('ops.integration.factgraph_updated'));
      expect(event.factId, equals('fact-1'));
      expect(event.operation, equals('update'));
      expect(event.payload['factId'], equals('fact-1'));
      expect(event.payload['operation'], equals('update'));
      expect(event.payload['entityType'], equals('KnowledgeItem'));
    });

    test('SkillExecutedEvent.create()', () {
      final event = SkillExecutedEvent.create(
        skillId: 'skill-1',
        result: {'output': 'generated'},
        skillVersion: '1.2.0',
        status: 'success',
        duration: const Duration(seconds: 3),
        inputSummary: 'summarized input',
        outputSummary: 'summarized output',
        claims: ['claim-a', 'claim-b'],
        correlationId: 'corr-se1',
        runId: 'run-se1',
        workspaceId: 'ws-se1',
        meta: meta,
      );

      expect(event.eventType, equals('ops.integration.skill_executed'));
      expect(event.skillId, equals('skill-1'));
      expect(event.payload['skillId'], equals('skill-1'));
      expect(event.payload['durationMs'], equals(3000));
      expect(event.payload['claims'], equals(['claim-a', 'claim-b']));
    });

    test('ProfileAppliedEvent.create()', () {
      final event = ProfileAppliedEvent.create(
        profileId: 'profile-1',
        profileVersion: '3.0',
        skillId: 'skill-target',
        appraisalResult: 'accepted',
        decisionsApplied: ['apply-weights', 'update-thresholds'],
        correlationId: 'corr-pa1',
        runId: 'run-pa1',
        workspaceId: 'ws-pa1',
        meta: meta,
      );

      expect(event.eventType, equals('ops.integration.profile_applied'));
      expect(event.profileId, equals('profile-1'));
      expect(event.payload['profileId'], equals('profile-1'));
      expect(event.payload['profileVersion'], equals('3.0'));
      expect(event.payload['decisionsApplied'],
          equals(['apply-weights', 'update-thresholds']));
    });

    test('BundlePublishedEvent.create()', () {
      final event = BundlePublishedEvent.create(
        bundleId: 'bundle-1',
        bundleVersion: '1.0.0',
        bundleType: 'skill',
        publishTarget: 'registry',
        checksum: 'sha256:abc123',
        size: 2048,
        correlationId: 'corr-bp1',
        runId: 'run-bp1',
        workspaceId: 'ws-bp1',
        meta: meta,
      );

      expect(event.eventType, equals('ops.integration.bundle_published'));
      expect(event.bundleId, equals('bundle-1'));
      expect(event.bundleVersion, equals('1.0.0'));
      expect(event.payload['bundleId'], equals('bundle-1'));
      expect(event.payload['size'], equals(2048));
      expect(event.payload['checksum'], equals('sha256:abc123'));
    });

    test('NotificationSentEvent.create()', () {
      final event = NotificationSentEvent.create(
        channel: 'email',
        recipientCount: 5,
        correlationId: 'corr-ns1',
        runId: 'run-ns1',
        workspaceId: 'ws-ns1',
        meta: meta,
      );

      expect(event.eventType, equals('ops.integration.notification_sent'));
      expect(event.channel, equals('email'));
      expect(event.recipientCount, equals(5));
      expect(event.payload['channel'], equals('email'));
      expect(event.payload['recipientCount'], equals(5));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Common behavior: all typed events inherit from OpsEvent
  // ═══════════════════════════════════════════════════════════════

  group('Common typed event behavior', () {
    test('typed events carry correlationId and runId', () {
      final event = PipelineStartedEvent.create(
        pipelineId: 'pipe-inherit',
        correlationId: 'corr-inherit',
        causationId: 'cause-inherit',
        runId: 'run-inherit',
        workspaceId: 'ws-inherit',
        meta: meta,
      );

      expect(event.correlationId, equals('corr-inherit'));
      expect(event.causationId, equals('cause-inherit'));
      expect(event.runId, equals('run-inherit'));
      expect(event.workspaceId, equals('ws-inherit'));
      expect(event.meta.source, equals('test'));
    });

    test('typed events auto-generate eventId', () {
      final event = WorkflowFailedEvent.create(
        workflowId: 'wf-autoid',
        error: 'test error',
        correlationId: 'corr-autoid',
        runId: 'run-autoid',
        workspaceId: 'ws-autoid',
        meta: meta,
      );

      expect(event.eventId, isNotEmpty);
      expect(event.eventId, startsWith('evt_'));
    });

    test('typed events are instances of OpsEvent', () {
      final event = ScheduleRegisteredEvent.create(
        scheduleId: 'sched-isa',
        name: 'ISA Test',
        correlationId: 'corr-isa',
        runId: 'run-isa',
        workspaceId: 'ws-isa',
        meta: meta,
      );

      expect(event, isA<OpsEvent>());
      expect(event, isA<ScheduleRegisteredEvent>());
    });

    test('typed events with minimal required fields', () {
      // ExecutionRolledBackEvent with only executionId (reason is optional)
      final event = ExecutionRolledBackEvent.create(
        executionId: 'exec-min',
        correlationId: 'corr-min',
        runId: 'run-min',
        workspaceId: 'ws-min',
        meta: meta,
      );

      expect(event.eventType, equals('ops.execution.rolled_back'));
      expect(event.executionId, equals('exec-min'));
      expect(event.reason, isNull);
      expect(event.checkpointId, isNull);
    });

    test('typed events inherit toJson from OpsEvent', () {
      final event = FactGraphUpdatedEvent.create(
        factId: 'fact-json',
        operation: 'create',
        correlationId: 'corr-json',
        runId: 'run-json',
        workspaceId: 'ws-json',
        meta: meta,
      );

      final json = event.toJson();
      expect(json['eventType'], equals('ops.integration.factgraph_updated'));
      expect(json['eventId'], isNotEmpty);
      expect(json['correlationId'], equals('corr-json'));
      expect(json['payload'], isA<Map<String, dynamic>>());
      expect((json['payload'] as Map<String, dynamic>)['factId'],
          equals('fact-json'));
    });

    test('typed events inherit toPortEvent from OpsEvent', () {
      final event = NotificationSentEvent.create(
        channel: 'slack',
        recipientCount: 10,
        correlationId: 'corr-port',
        runId: 'run-port',
        workspaceId: 'ws-port',
        meta: meta,
      );

      final portEvent = event.toPortEvent();
      expect(portEvent.type, equals('ops.integration.notification_sent'));
      expect(portEvent.source, equals('test'));
      expect(portEvent.payload['correlationId'], equals('corr-port'));
    });
  });
}
