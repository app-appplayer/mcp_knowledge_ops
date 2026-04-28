/// Review Models - Review and approval request/response models.
///
/// Defines data structures for human review steps and gate-controlled
/// approval steps in workflow execution (spec section 7).
library;

/// Review request for human review steps.
///
/// Created when a workflow stage of type 'review' is reached,
/// allowing designated reviewers to inspect artifacts before proceeding.
class ReviewRequest {
  /// Unique request identifier.
  final String id;

  /// Workflow run identifier.
  final String workflowId;

  /// Stage that triggered the review.
  final String stepId;

  /// Review title.
  final String title;

  /// Optional description providing review context.
  final String? description;

  /// Data to be reviewed.
  final Map<String, dynamic>? data;

  /// List of designated reviewer identifiers.
  final List<String> reviewers;

  /// When the review was requested.
  final DateTime createdAt;

  /// Optional timeout after which the review expires.
  final Duration? timeout;

  const ReviewRequest({
    required this.id,
    required this.workflowId,
    required this.stepId,
    required this.title,
    this.description,
    this.data,
    required this.reviewers,
    required this.createdAt,
    this.timeout,
  });
}

/// Response to a review request.
///
/// Captures a reviewer's decision along with optional feedback.
class ReviewResponse {
  /// Identifier of the review request being responded to.
  final String requestId;

  /// Reviewer who submitted the response.
  final String reviewer;

  /// Decision: 'approved', 'rejected', or 'changes_requested'.
  final String decision;

  /// Optional comment explaining the decision.
  final String? comment;

  /// Optional structured feedback data.
  final Map<String, dynamic>? feedback;

  /// When the response was submitted.
  final DateTime respondedAt;

  const ReviewResponse({
    required this.requestId,
    required this.reviewer,
    required this.decision,
    this.comment,
    this.feedback,
    required this.respondedAt,
  });
}

/// Workflow-level approval request for gate-controlled steps.
///
/// Created when a workflow stage of type 'approval' is reached,
/// requiring designated approvers to authorize proceeding.
///
/// Note: Named [WorkflowApprovalRequest] to avoid conflict with
/// [ApprovalRequest] from mcp_bundle's ApprovalPort contract.
class WorkflowApprovalRequest {
  /// Unique request identifier.
  final String id;

  /// Workflow run identifier.
  final String workflowId;

  /// Gate that triggered the approval.
  final String gateId;

  /// Approval title.
  final String title;

  /// Optional description providing approval context.
  final String? description;

  /// List of designated approver identifiers.
  final List<String> approvers;

  /// Number of approvals required to proceed.
  final int requiredApprovals;

  /// When the approval was requested.
  final DateTime createdAt;

  /// Optional timeout after which the approval expires.
  final Duration? timeout;

  const WorkflowApprovalRequest({
    required this.id,
    required this.workflowId,
    required this.gateId,
    required this.title,
    this.description,
    required this.approvers,
    this.requiredApprovals = 1,
    required this.createdAt,
    this.timeout,
  });
}

/// Workflow-level response to an approval request.
///
/// Captures an approver's decision with optional reasoning.
///
/// Note: Named [WorkflowApprovalResponse] to avoid potential conflict
/// with approval types from mcp_bundle's ApprovalPort contract.
class WorkflowApprovalResponse {
  /// Identifier of the approval request being responded to.
  final String requestId;

  /// Approver who submitted the response.
  final String approver;

  /// Whether the request was approved.
  final bool approved;

  /// Optional reason for the decision.
  final String? reason;

  /// When the response was submitted.
  final DateTime respondedAt;

  const WorkflowApprovalResponse({
    required this.requestId,
    required this.approver,
    required this.approved,
    this.reason,
    required this.respondedAt,
  });
}
