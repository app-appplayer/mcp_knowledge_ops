/// Tests for StandardApprovalRouter and approval routing models.
import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  group('StandardApprovalRouter', () {
    test('resolveApprovers returns approver for matching rule', () async {
      final router = StandardApprovalRouter(
        rules: ApprovalRoutingRules(
          rules: [
            RoutingRule(
              name: 'production_rule',
              condition: RoutingCondition(
                field: 'environment',
                operator: 'equals',
                value: 'production',
              ),
              approver: ApproverSpec(
                type: 'role',
                value: 'senior-engineer',
              ),
            ),
          ],
          defaultApprovers: ['fallback-user'],
        ),
      );

      final approvers = await router.resolveApprovers(
        ApprovalRoutingRequest(
          workflowId: 'wf-1',
          gateId: 'gate-1',
          type: 'production_release',
          context: {'environment': 'production'},
        ),
      );

      expect(approvers, hasLength(1));
      expect(approvers.first, equals('senior-engineer'));
    });

    test('resolveApprovers returns defaultApprovers when no rules match',
        () async {
      final router = StandardApprovalRouter(
        rules: ApprovalRoutingRules(
          rules: [
            RoutingRule(
              name: 'production_rule',
              condition: RoutingCondition(
                field: 'environment',
                operator: 'equals',
                value: 'production',
              ),
              approver: ApproverSpec(
                type: 'role',
                value: 'senior-engineer',
              ),
            ),
          ],
          defaultApprovers: ['fallback-user'],
        ),
      );

      final approvers = await router.resolveApprovers(
        ApprovalRoutingRequest(
          workflowId: 'wf-1',
          gateId: 'gate-1',
          type: 'staging_release',
          context: {'environment': 'staging'},
        ),
      );

      expect(approvers, hasLength(1));
      expect(approvers.first, equals('fallback-user'));
    });

    test('resolveApprovers returns empty when no rules match and no defaults',
        () async {
      final router = StandardApprovalRouter(
        rules: ApprovalRoutingRules(
          rules: [
            RoutingRule(
              name: 'never_match',
              condition: RoutingCondition(
                field: 'env',
                operator: 'equals',
                value: 'never',
              ),
              approver: ApproverSpec(type: 'user', value: 'admin'),
            ),
          ],
        ),
      );

      final approvers = await router.resolveApprovers(
        ApprovalRoutingRequest(
          workflowId: 'wf-1',
          gateId: 'gate-1',
          type: 'test',
          context: {'env': 'dev'},
        ),
      );

      expect(approvers, isEmpty);
    });

    test('resolveApprovers returns empty when context is null', () async {
      final router = StandardApprovalRouter(
        rules: ApprovalRoutingRules(
          rules: [
            RoutingRule(
              name: 'rule',
              condition: RoutingCondition(
                field: 'env',
                operator: 'equals',
                value: 'prod',
              ),
              approver: ApproverSpec(type: 'user', value: 'admin'),
            ),
          ],
          defaultApprovers: ['default-approver'],
        ),
      );

      final approvers = await router.resolveApprovers(
        ApprovalRoutingRequest(
          workflowId: 'wf-1',
          gateId: 'gate-1',
          type: 'test',
        ),
      );

      // No context means no rule matches, falls back to defaults
      expect(approvers, contains('default-approver'));
    });

    test('contains operator matches substring', () async {
      final router = StandardApprovalRouter(
        rules: ApprovalRoutingRules(
          rules: [
            RoutingRule(
              name: 'contains_rule',
              condition: RoutingCondition(
                field: 'description',
                operator: 'contains',
                value: 'critical',
              ),
              approver: ApproverSpec(type: 'user', value: 'security-lead'),
            ),
          ],
        ),
      );

      final approvers = await router.resolveApprovers(
        ApprovalRoutingRequest(
          workflowId: 'wf-1',
          gateId: 'gate-1',
          type: 'deployment',
          context: {'description': 'This is a critical deployment'},
        ),
      );

      expect(approvers, contains('security-lead'));
    });
  });

  group('ApprovalRoutingRequest', () {
    test('creation with required fields', () {
      const request = ApprovalRoutingRequest(
        workflowId: 'wf-1',
        gateId: 'gate-1',
        type: 'production_release',
      );

      expect(request.workflowId, equals('wf-1'));
      expect(request.gateId, equals('gate-1'));
      expect(request.type, equals('production_release'));
      expect(request.context, isNull);
    });
  });

  group('ApproverSpec', () {
    test('creation with quorum policy', () {
      const spec = ApproverSpec(
        type: 'group',
        value: 'team-leads',
        quorum: QuorumPolicy(minimum: 2, percentage: 50),
      );

      expect(spec.type, equals('group'));
      expect(spec.value, equals('team-leads'));
      expect(spec.quorum, isNotNull);
      expect(spec.quorum!.minimum, equals(2));
      expect(spec.quorum!.percentage, equals(50));
    });
  });
}
