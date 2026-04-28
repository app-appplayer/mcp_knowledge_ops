/// Error Codes - Comprehensive error code taxonomy for knowledge ops.
///
/// Every error code follows the pattern `OPS-{CATEGORY}-{NNN}` and
/// belongs to a well-defined category for filtering and monitoring.
library;

/// Category of an ops error code.
enum OpsErrorCategory {
  /// Pipeline execution errors.
  pipeline,

  /// Workflow execution errors.
  workflow,

  /// Quality gate errors.
  gate,

  /// Approval workflow errors.
  approval,

  /// General execution errors.
  execution,

  /// Philosophy-related errors.
  philosophy,
}

/// Structured error codes for all knowledge ops operations.
///
/// Each variant carries a unique code string, a human-readable display
/// name, and an [OpsErrorCategory] for grouping and filtering.
enum OpsErrorCode {
  // ─────────────────────────────────────────────────────────────────
  // Pipeline: OPS-PIPE-001 through 009
  // ─────────────────────────────────────────────────────────────────

  /// Pipeline definition not found.
  pipelineNotFound('OPS-PIPE-001', 'Pipeline Not Found', OpsErrorCategory.pipeline),

  /// Pipeline definition is invalid or malformed.
  invalidPipeline('OPS-PIPE-002', 'Invalid Pipeline', OpsErrorCategory.pipeline),

  /// Pipeline is already running and concurrent execution is not allowed.
  pipelineAlreadyRunning('OPS-PIPE-003', 'Pipeline Already Running', OpsErrorCategory.pipeline),

  /// A stage within the pipeline failed.
  stageFailed('OPS-PIPE-004', 'Stage Failed', OpsErrorCategory.pipeline),

  /// Pipeline execution was cancelled.
  pipelineCancelled('OPS-PIPE-005', 'Pipeline Cancelled', OpsErrorCategory.pipeline),

  /// Attempted an invalid stage transition.
  invalidStageTransition('OPS-PIPE-006', 'Invalid Stage Transition', OpsErrorCategory.pipeline),

  /// A dependency required by a stage failed.
  dependencyFailed('OPS-PIPE-007', 'Dependency Failed', OpsErrorCategory.pipeline),

  /// Checkpoint save or restore failed during pipeline execution.
  checkpointFailed('OPS-PIPE-008', 'Checkpoint Failed', OpsErrorCategory.pipeline),

  /// Resume from checkpoint failed.
  resumeFailed('OPS-PIPE-009', 'Resume Failed', OpsErrorCategory.pipeline),

  // ─────────────────────────────────────────────────────────────────
  // Workflow: OPS-WKFL-001 through 008
  // ─────────────────────────────────────────────────────────────────

  /// Workflow definition not found.
  workflowNotFound('OPS-WKFL-001', 'Workflow Not Found', OpsErrorCategory.workflow),

  /// Workflow definition is invalid or malformed.
  invalidWorkflow('OPS-WKFL-002', 'Invalid Workflow', OpsErrorCategory.workflow),

  /// A stage within the workflow timed out.
  stageTimeout('OPS-WKFL-003', 'Stage Timeout', OpsErrorCategory.workflow),

  /// A review stage was rejected.
  reviewRejected('OPS-WKFL-004', 'Review Rejected', OpsErrorCategory.workflow),

  /// An approval stage was rejected.
  approvalRejected('OPS-WKFL-005', 'Approval Rejected', OpsErrorCategory.workflow),

  /// An approval stage timed out waiting for approvers.
  approvalTimeout('OPS-WKFL-006', 'Approval Timeout', OpsErrorCategory.workflow),

  /// Attempted an invalid workflow state transition.
  invalidStateTransition('OPS-WKFL-007', 'Invalid State Transition', OpsErrorCategory.workflow),

  /// Workflow has already completed and cannot be modified.
  alreadyCompleted('OPS-WKFL-008', 'Already Completed', OpsErrorCategory.workflow),

  // ─────────────────────────────────────────────────────────────────
  // Gate: OPS-GATE-001 through 005
  // ─────────────────────────────────────────────────────────────────

  /// A gate condition evaluated to false.
  conditionFailed('OPS-GATE-001', 'Condition Failed', OpsErrorCategory.gate),

  /// Error during gate expression evaluation.
  evaluationError('OPS-GATE-002', 'Evaluation Error', OpsErrorCategory.gate),

  /// A metric required by the gate is missing.
  missingMetric('OPS-GATE-003', 'Missing Metric', OpsErrorCategory.gate),

  /// Gate expression is syntactically or semantically invalid.
  invalidExpression('OPS-GATE-004', 'Invalid Expression', OpsErrorCategory.gate),

  /// A numeric threshold was not met.
  thresholdNotMet('OPS-GATE-005', 'Threshold Not Met', OpsErrorCategory.gate),

  // ─────────────────────────────────────────────────────────────────
  // Approval: OPS-APRV-001 through 007
  // ─────────────────────────────────────────────────────────────────

  /// No approvers are configured for the approval stage.
  noApprovers('OPS-APRV-001', 'No Approvers', OpsErrorCategory.approval),

  /// The specified approver is not valid or not authorized.
  invalidApprover('OPS-APRV-002', 'Invalid Approver', OpsErrorCategory.approval),

  /// Approval delegation is not allowed for this stage.
  delegationNotAllowed('OPS-APRV-003', 'Delegation Not Allowed', OpsErrorCategory.approval),

  /// Escalation to a higher-level approver failed.
  escalationFailed('OPS-APRV-004', 'Escalation Failed', OpsErrorCategory.approval),

  /// Required quorum of approvers was not reached.
  quorumNotReached('OPS-APRV-005', 'Quorum Not Reached', OpsErrorCategory.approval),

  /// The approval request has already been processed.
  alreadyProcessed('OPS-APRV-006', 'Already Processed', OpsErrorCategory.approval),

  /// Self-approval is not allowed for this stage.
  selfApprovalNotAllowed('OPS-APRV-007', 'Self-Approval Not Allowed', OpsErrorCategory.approval),

  // ─────────────────────────────────────────────────────────────────
  // Execution: OPS-EXEC-001 through 007
  // ─────────────────────────────────────────────────────────────────

  /// Execution run not found.
  executionNotFound('OPS-EXEC-001', 'Execution Not Found', OpsErrorCategory.execution),

  /// Execution exceeded its overall timeout.
  executionTimeout('OPS-EXEC-002', 'Execution Timeout', OpsErrorCategory.execution),

  /// All retry attempts have been exhausted.
  retryExhausted('OPS-EXEC-003', 'Retry Exhausted', OpsErrorCategory.execution),

  /// Circuit breaker is open; requests are being rejected.
  circuitOpen('OPS-EXEC-004', 'Circuit Open', OpsErrorCategory.execution),

  /// Rollback operation failed.
  rollbackFailed('OPS-EXEC-005', 'Rollback Failed', OpsErrorCategory.execution),

  /// Execution is in an invalid state for the requested operation.
  invalidState('OPS-EXEC-006', 'Invalid State', OpsErrorCategory.execution),

  /// Concurrency limit has been reached.
  concurrencyLimit('OPS-EXEC-007', 'Concurrency Limit', OpsErrorCategory.execution),

  // ─────────────────────────────────────────────────────────────────
  // Philosophy: PHIL-*
  // ─────────────────────────────────────────────────────────────────

  /// Ethos not found or not configured.
  ethosNotFound('PHIL-EVAL-001', 'Ethos Not Found', OpsErrorCategory.philosophy),

  /// Hard prohibition violated.
  prohibitionViolated('PHIL-PROH-001', 'Hard Prohibition Violated', OpsErrorCategory.philosophy),

  /// Philosophy intervention failed.
  philosophyInterventionFailed('PHIL-INTV-001', 'Intervention Failed', OpsErrorCategory.philosophy),

  /// Tension detection not supported by adapter.
  tensionDetectionUnsupported('PHIL-TENS-001', 'Tension Detection Unsupported', OpsErrorCategory.philosophy);

  /// Unique code string (e.g. "OPS-PIPE-001").
  final String code;

  /// Human-readable display name.
  final String displayName;

  /// Category this error code belongs to.
  final OpsErrorCategory category;

  const OpsErrorCode(this.code, this.displayName, this.category);

  /// Look up an [OpsErrorCode] by its code string.
  ///
  /// Returns `null` if the code string is not recognized.
  static OpsErrorCode? fromCode(String code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return null;
  }

  /// Get all error codes for a given category.
  static List<OpsErrorCode> byCategory(OpsErrorCategory category) {
    return values.where((v) => v.category == category).toList();
  }

  @override
  String toString() => '$code ($displayName)';
}
