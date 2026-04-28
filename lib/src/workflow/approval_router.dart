/// Approval Router - Routes approval requests to appropriate approvers.
///
/// Provides rule-based routing, escalation, and delegation logic
/// on top of the ApprovalPort contract (spec section 8).
///
/// Architecture Note: ApprovalRouter is an ops-internal service that wraps
/// ApprovalPort. It is NOT a separate mcp_bundle port. The router provides
/// rule-based routing, escalation, and delegation logic on top of the simple
/// ApprovalPort.requestApproval() contract.
library;

/// Routes approval requests to appropriate approvers.
///
/// Determines who should approve based on workflow context,
/// organizational rules, and escalation policies.
abstract class ApprovalRouter {
  /// Resolve approvers for the given routing request.
  Future<List<String>> resolveApprovers(ApprovalRoutingRequest request);
}

/// Request for approval routing resolution.
class ApprovalRoutingRequest {
  /// Workflow identifier.
  final String workflowId;

  /// Gate identifier that triggered the approval.
  final String gateId;

  /// Approval type (e.g., 'production_release', 'high_risk').
  final String type;

  /// Additional context for routing decisions.
  final Map<String, dynamic>? context;

  const ApprovalRoutingRequest({
    required this.workflowId,
    required this.gateId,
    required this.type,
    this.context,
  });
}

/// Configuration for approval routing rules.
class ApprovalRoutingRules {
  /// Ordered list of routing rules.
  final List<RoutingRule> rules;

  /// Fallback approvers when no rules match.
  final List<String>? defaultApprovers;

  const ApprovalRoutingRules({
    required this.rules,
    this.defaultApprovers,
  });
}

/// A single routing rule that maps conditions to approver specifications.
class RoutingRule {
  /// Rule name for identification and logging.
  final String name;

  /// Condition that must be met for this rule to apply.
  final RoutingCondition condition;

  /// Approver specification for this rule.
  final ApproverSpec approver;

  /// Priority (higher = evaluated first).
  final int? priority;

  const RoutingRule({
    required this.name,
    required this.condition,
    required this.approver,
    this.priority,
  });
}

/// Condition for matching a routing rule against request context.
class RoutingCondition {
  /// Field name to evaluate in the context.
  final String field;

  /// Comparison operator: 'equals', 'contains', 'in'.
  final String operator;

  /// Value to compare against.
  final dynamic value;

  const RoutingCondition({
    required this.field,
    required this.operator,
    required this.value,
  });
}

/// Specification for an approver or approver group.
class ApproverSpec {
  /// Approver type: 'user', 'role', 'group', or 'dynamic'.
  final String type;

  /// Approver identifier (user_id, role_name, group_id, or expression).
  final String value;

  /// Quorum policy for this approver specification.
  final QuorumPolicy? quorum;

  const ApproverSpec({
    required this.type,
    required this.value,
    this.quorum,
  });
}

/// Policy defining how many approvals are required.
class QuorumPolicy {
  /// Minimum number of approvals required.
  final int minimum;

  /// Optional percentage of approvers that must approve.
  final int? percentage;

  const QuorumPolicy({
    required this.minimum,
    this.percentage,
  });
}

/// Policy for escalating unresolved approvals.
class EscalationPolicy {
  /// Escalation levels in order.
  final List<EscalationLevel> levels;

  const EscalationPolicy({required this.levels});
}

/// A single escalation level definition.
class EscalationLevel {
  /// Duration after which this level is triggered.
  final Duration after;

  /// Additional people to notify at this level.
  final List<String> notifyAdditional;

  /// Action to take: 'notify', 'reassign', 'auto_approve', or 'auto_reject'.
  final String? action;

  const EscalationLevel({
    required this.after,
    required this.notifyAdditional,
    this.action,
  });
}

/// Request to delegate an approval to another person.
class DelegationRequest {
  /// Approval identifier being delegated.
  final String approvalId;

  /// Original approver delegating.
  final String fromApprover;

  /// Target approver receiving the delegation.
  final String toApprover;

  /// Optional reason for delegation.
  final String? reason;

  /// Optional expiration for the delegation.
  final DateTime? expiresAt;

  const DelegationRequest({
    required this.approvalId,
    required this.fromApprover,
    required this.toApprover,
    this.reason,
    this.expiresAt,
  });
}

/// Result of a delegation attempt.
class DelegationResult {
  /// Whether the delegation succeeded.
  final bool success;

  /// Error message if delegation failed.
  final String? error;

  const DelegationResult({
    required this.success,
    this.error,
  });
}

/// Policy governing delegation behavior.
class DelegationPolicy {
  /// Whether delegation is allowed.
  final bool allowDelegation;

  /// Maximum depth of delegation chains (prevents A -> B -> C -> D...).
  final int maxDelegationDepth;

  /// Restrictions on who can be delegated to.
  final List<DelegateeRestriction>? restrictions;

  const DelegationPolicy({
    this.allowDelegation = true,
    this.maxDelegationDepth = 2,
    this.restrictions,
  });
}

/// Restriction on valid delegatees.
class DelegateeRestriction {
  /// Restriction type: 'same_role', 'same_team', or 'explicit_list'.
  final String type;

  /// Restriction value (role name, team id, or list of user ids).
  final dynamic value;

  const DelegateeRestriction({
    required this.type,
    this.value,
  });
}

/// Standard implementation of [ApprovalRouter].
///
/// Matches routing rules against request context to determine approvers.
/// Falls back to default approvers when no rules match.
class StandardApprovalRouter implements ApprovalRouter {
  /// Routing rules configuration.
  final ApprovalRoutingRules rules;

  /// Escalation policy for unresolved approvals.
  final EscalationPolicy? escalation;

  /// Delegation policy for approval transfer.
  final DelegationPolicy? delegation;

  /// Timeout configuration for approval deadlines.
  final ApprovalTimeoutConfig? timeoutConfig;

  const StandardApprovalRouter({
    required this.rules,
    this.escalation,
    this.delegation,
    this.timeoutConfig,
  });

  @override
  Future<List<String>> resolveApprovers(ApprovalRoutingRequest request) async {
    // Match rules against request context (highest priority first)
    for (final rule in rules.rules) {
      if (_matchesCondition(rule.condition, request.context)) {
        return [rule.approver.value];
      }
    }
    return rules.defaultApprovers ?? [];
  }

  /// Evaluate a routing condition against the request context.
  bool _matchesCondition(
    RoutingCondition condition,
    Map<String, dynamic>? context,
  ) {
    if (context == null) return false;
    final value = context[condition.field];
    switch (condition.operator) {
      case 'equals':
        return value == condition.value;
      case 'contains':
        return value?.toString().contains(condition.value.toString()) ?? false;
      case 'in':
        return (condition.value as List?)?.contains(value) ?? false;
      default:
        return false;
    }
  }
}

/// Configuration for approval timeout behavior.
class ApprovalTimeoutConfig {
  /// Primary timeout duration.
  final Duration timeout;

  /// Action to take when timeout is reached.
  final TimeoutAction action;

  /// Optional warning before timeout occurs.
  final PreTimeoutWarning? warning;

  const ApprovalTimeoutConfig({
    required this.timeout,
    required this.action,
    this.warning,
  });
}

/// Actions available when an approval times out.
enum TimeoutAction {
  /// Automatically approve the request.
  autoApprove,

  /// Automatically reject the request.
  autoReject,

  /// Escalate to the next level.
  escalate,

  /// Cancel the approval request.
  cancel,
}

/// Warning notification before timeout occurs.
class PreTimeoutWarning {
  /// Duration before timeout to send the warning.
  final Duration before;

  /// Channels to send the warning notification to.
  final List<String> notifyChannels;

  const PreTimeoutWarning({
    required this.before,
    required this.notifyChannels,
  });
}
