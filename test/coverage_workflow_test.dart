// Workflow value classes, the deprecated executor stubs, cancellation, the
// approval router's `in` operator and the declarative workflows' `run`.

// ignore_for_file: deprecated_member_use_from_same_package

import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart' as ops;
import 'package:mcp_knowledge_ops/src/workflow/approval_router.dart';
import 'package:mcp_knowledge_ops/src/workflow/cancellation.dart';
import 'package:mcp_knowledge_ops/src/workflow/review_models.dart';
import 'package:mcp_knowledge_ops/src/workflow/workflow.dart'
    show WorkflowConfig, WorkflowContext;
import 'package:mcp_knowledge_ops/src/workflow/workflow_executor.dart' as we;
import 'package:mcp_knowledge_ops/src/workflow/workflows/bundle_build_workflow.dart';
import 'package:mcp_knowledge_ops/src/workflow/workflows/profile_build_workflow.dart';
import 'package:mcp_knowledge_ops/src/workflow/workflows/skill_build_workflow.dart';
import 'package:test/test.dart';

WorkflowContext _ctx() => WorkflowContext(
    runId: 'r',
    workspaceId: 'w',
    userId: 'u',
    asOf: DateTime.utc(2026),
    config: const WorkflowConfig());

void main() {
  final t = DateTime.utc(2026);

  test('review and approval records', () {
    expect(
        ReviewRequest(
                id: 's',
                workflowId: 's',
                stepId: 's',
                title: 's',
                reviewers: const [],
                createdAt: t)
            .id,
        's');
    expect(
        ReviewResponse(
                requestId: 's', reviewer: 's', decision: 's', respondedAt: t)
            .decision,
        's');
    expect(
        WorkflowApprovalRequest(
                id: 's',
                workflowId: 's',
                gateId: 's',
                title: 's',
                approvers: const [],
                createdAt: t)
            .gateId,
        's');
    expect(
        WorkflowApprovalResponse(
                requestId: 's', approver: 's', approved: true, respondedAt: t)
            .approved,
        isTrue);
  });

  group('approval router', () {
    test('records', () {
      expect(EscalationPolicy(levels: const []).levels, isEmpty);
      expect(
          EscalationLevel(after: Duration.zero, notifyAdditional: const [])
              .after,
          Duration.zero);
      expect(
          DelegationRequest(approvalId: 's', fromApprover: 's', toApprover: 's')
              .toApprover,
          's');
      expect(DelegationResult(success: true).success, isTrue);
      expect(DelegationPolicy().toString(), isNotEmpty);
      expect(DelegateeRestriction(type: 's').type, 's');
      expect(
          ApprovalTimeoutConfig(
                  timeout: Duration.zero, action: TimeoutAction.autoApprove)
              .action,
          TimeoutAction.autoApprove);
      expect(
          PreTimeoutWarning(before: Duration.zero, notifyChannels: const [])
              .before,
          Duration.zero);
    });

    test('the in, contains and unknown operators, and a missing context',
        () async {
      StandardApprovalRouter router(String op, dynamic value) =>
          StandardApprovalRouter(
            rules: ApprovalRoutingRules(rules: [
              RoutingRule(
                  name: 'r',
                  condition: RoutingCondition(
                      field: 'env', operator: op, value: value),
                  approver: ApproverSpec(type: 'role', value: 'boss')),
            ], defaultApprovers: const [
              'fallback'
            ]),
          );
      Future<List<String>> resolve(
              StandardApprovalRouter r, Map<String, dynamic>? c) =>
          r.resolveApprovers(ApprovalRoutingRequest(
              workflowId: 'w', gateId: 'g', type: 't', context: c));
      expect(await resolve(router('in', ['prod', 'stage']), {'env': 'prod'}),
          ['boss']);
      expect(
          await resolve(router('in', ['prod']), {'env': 'dev'}), ['fallback']);
      expect(await resolve(router('in', null), {'env': 'dev'}), ['fallback']);
      expect(await resolve(router('contains', 'pro'), {'env': 'production'}),
          ['boss']);
      expect(await resolve(router('contains', 'pro'), {}), ['fallback']);
      expect(await resolve(router('weird', 'x'), {'env': 'x'}), ['fallback']);
      expect(await resolve(router('equals', 'x'), null), ['fallback']);
    });
  });

  group('cancellation', () {
    test('the executor runs its five phases', () async {
      const config = CompensationConfig();
      final request = CancellationRequest(
          workflowId: 'w',
          executionId: 'e',
          reason: const UserRequested(userId: 'u', comment: 'c'),
          requestedAt: t);
      final result =
          await CancellationExecutor(config: config).execute(request);
      expect(result.workflowId, 'w');
      expect(result.haltResult.halted, isTrue);
      expect(result.compensationResult.success, isTrue);
      expect(result.cleanupResult.success, isTrue);
    });

    test('records and reasons', () {
      expect(
          StageCompensation(stageId: 's', action: const NoOp()).stageId, 's');
      expect(
          StageCompensation(
                  stageId: 's', action: const InvokeHandler(handlerName: 'h'))
              .action,
          isA<InvokeHandler>());
      expect(
          ResourceCleanup(
                  resourceType: 's', resourceId: 's', cleanupAction: 's')
              .resourceId,
          's');
      final halt = HaltResult(
          halted: true,
          stageResults: [StageHaltResult(stageId: 's', halted: true)],
          haltedAt: t);
      final comp = CompensationResult(
          success: false,
          compensatedStages: const [],
          failures: [
            CompensationFailure(stageId: 's', error: 'e', attemptCount: 2)
          ]);
      final cleanup = CleanupResult(success: true, cleanedResources: [
        ResourceCleanupResult(resourceId: 's', resourceType: 's', cleaned: true)
      ]);
      final done = CancellationResult(
          workflowId: 'w',
          executionId: 'e',
          haltResult: halt,
          compensationResult: comp,
          cleanupResult: cleanup,
          completedAt: t);
      expect(done.compensationResult.failures.single.attemptCount, 2);
      final audit = CancellationAuditEvent(
          workflowId: 'w',
          executionId: 'e',
          reason: const SystemShutdown(message: 'bye'),
          cancelledAt: t,
          compensationResult: comp,
          cleanupResult: cleanup);
      expect(audit.reason, isA<SystemShutdown>());
      expect(
          const TimeoutExceeded(elapsed: Duration.zero, limit: Duration.zero),
          isA<CancellationReason>());
      expect(const DependencyFailed(dependencyId: 'd', error: 'e').error, 'e');
      expect(const RunScript(script: 's').script, 's');
    });
  });

  group('deprecated workflow executor', () {
    test('every operation says to use the engine', () async {
      final executor =
          we.WorkflowExecutor(handlers: we.WorkflowActionHandlerRegistry());
      await expectLater(executor.start(null, {}), throwsUnimplementedError);
      await expectLater(
          executor.sendEvent('e', 'ev'), throwsUnimplementedError);
      await expectLater(executor.cancel('e'), throwsUnimplementedError);
      expect(executor.getExecution('e'), isNull);
      expect(executor.listActiveExecutions(), isEmpty);
    });

    test('events and exceptions', () {
      expect(we.WorkflowException(code: 'C', message: 'm').toString(),
          'WorkflowException(C): m');
      final ctx = we.ActionExecutionContext(
          executionId: 's',
          workflowId: 's',
          stateId: 's',
          actionId: 's',
          parameters: const {},
          data: const {});
      expect(ctx.actionId, 's');
      expect(
          we.WorkflowStartedEvent(
                  executionId: 's', workflowId: 's', timestamp: t)
              .executionId,
          's');
      expect(
          we.WorkflowStateEnteredEvent(
                  executionId: 's', workflowId: 's', stateId: 's', timestamp: t)
              .stateId,
          's');
      expect(
          we.WorkflowStateExitedEvent(
                  executionId: 's', workflowId: 's', stateId: 's', timestamp: t)
              .stateId,
          's');
      expect(
          we.WorkflowTransitionEvent(
                  executionId: 's',
                  workflowId: 's',
                  transitionId: 's',
                  fromState: 'a',
                  toState: 'b',
                  timestamp: t)
              .toState,
          'b');
      expect(
          we.WorkflowEventIgnoredEvent(
                  executionId: 's',
                  workflowId: 's',
                  event: 's',
                  currentState: 's',
                  timestamp: t)
              .event,
          's');
      expect(
          we.WorkflowTransitionGuardedEvent(
                  executionId: 's',
                  workflowId: 's',
                  transitionId: 's',
                  guard: 'g',
                  timestamp: t)
              .guard,
          'g');
      expect(
          we.WorkflowCompletedEvent(
                  executionId: 's', workflowId: 's', timestamp: t)
              .workflowId,
          's');
      expect(
          we.WorkflowFailedEvent(
                  executionId: 's', workflowId: 's', timestamp: t)
              .workflowId,
          's');
      expect(
          we.WorkflowCancelledEvent(
                  executionId: 's', workflowId: 's', timestamp: t)
              .workflowId,
          's');
    });
  });

  group('declarative workflows', () {
    test('profile and bundle workflows return their placeholder output',
        () async {
      final profile = await ProfileBuildWorkflow()
          .run(const ProfileBuildInput(source: 'manual'), _ctx());
      expect(profile.success, isTrue);
      expect(profile.output!.profileId, startsWith('profile-'));
      final bundle = await BundleBuildWorkflow().run(
          const BundleBuildInput(
              manifestId: 'm', components: BundleComponents()),
          _ctx());
      expect(bundle.output!.bundleId, startsWith('bundle-'));
      expect(bundle.output!.integrity.checksum, '');
    });

    test('value classes', () {
      expect(const EvaluationConfig().toString(), isNotEmpty);
      expect(EvaluationResult(evalSetId: 's', passRate: 0.5).passRate, 0.5);
      expect(const ProfileEvaluationConfig().toString(), isNotEmpty);
      expect(ProfileTestCase(id: 's', context: const {}).id, 's');
      expect(ProfileEvaluationResult(testCaseId: 's', passed: true).passed,
          isTrue);
      expect(BundleIntegrity(checksum: 's', timestamp: t).checksum, 's');
      final out = ProfileBuildOutput(
          profileId: 's',
          version: 's',
          bundle: ProfileBundle(
              id: '', profileId: '', version: '', path: '', checksum: ''),
          evaluationResults: const []);
      expect(out.version, 's');
      final b = BundleBuildOutput(
          bundleId: 's',
          version: 's',
          bundle: McpBundle(id: '', version: '', path: ''),
          integrity: BundleIntegrity(checksum: 's', timestamp: t));
      expect(b.bundleId, 's');
      expect(ops.SkillBuildWorkflow, isNotNull);
    });
  });
}
