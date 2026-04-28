/// Events - Execution event models for observability.
///
/// Defines events emitted during pipeline and workflow execution.
library;

/// Base execution event.
abstract class ExecutionEvent {
  /// Event type.
  String get type;

  /// Event timestamp.
  DateTime get timestamp;

  /// Execution run ID.
  String get runId;

  /// Serialize to JSON.
  Map<String, dynamic> toJson();
}

/// Pipeline started event.
class PipelineStartedEvent implements ExecutionEvent {
  @override
  final String type = 'pipeline.started';

  @override
  final DateTime timestamp;

  @override
  final String runId;

  /// Pipeline identifier.
  final String pipelineId;

  /// Input data summary.
  final Map<String, dynamic>? inputSummary;

  const PipelineStartedEvent({
    required this.timestamp,
    required this.runId,
    required this.pipelineId,
    this.inputSummary,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'runId': runId,
        'pipelineId': pipelineId,
        if (inputSummary != null) 'inputSummary': inputSummary,
      };
}

/// Pipeline completed event.
class PipelineCompletedEvent implements ExecutionEvent {
  @override
  final String type = 'pipeline.completed';

  @override
  final DateTime timestamp;

  @override
  final String runId;

  /// Pipeline identifier.
  final String pipelineId;

  /// Whether execution succeeded.
  final bool success;

  /// Total duration.
  final Duration duration;

  /// Error message if failed.
  final String? error;

  const PipelineCompletedEvent({
    required this.timestamp,
    required this.runId,
    required this.pipelineId,
    required this.success,
    required this.duration,
    this.error,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'runId': runId,
        'pipelineId': pipelineId,
        'success': success,
        'durationMs': duration.inMilliseconds,
        if (error != null) 'error': error,
      };
}

/// Stage started event.
class StageStartedEvent implements ExecutionEvent {
  @override
  final String type = 'stage.started';

  @override
  final DateTime timestamp;

  @override
  final String runId;

  /// Pipeline identifier.
  final String pipelineId;

  /// Stage identifier.
  final String stageId;

  const StageStartedEvent({
    required this.timestamp,
    required this.runId,
    required this.pipelineId,
    required this.stageId,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'runId': runId,
        'pipelineId': pipelineId,
        'stageId': stageId,
      };
}

/// Stage completed event.
class StageCompletedEvent implements ExecutionEvent {
  @override
  final String type = 'stage.completed';

  @override
  final DateTime timestamp;

  @override
  final String runId;

  /// Pipeline identifier.
  final String pipelineId;

  /// Stage identifier.
  final String stageId;

  /// Stage duration.
  final Duration duration;

  const StageCompletedEvent({
    required this.timestamp,
    required this.runId,
    required this.pipelineId,
    required this.stageId,
    required this.duration,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'runId': runId,
        'pipelineId': pipelineId,
        'stageId': stageId,
        'durationMs': duration.inMilliseconds,
      };
}

/// Stage failed event.
class StageFailedEvent implements ExecutionEvent {
  @override
  final String type = 'stage.failed';

  @override
  final DateTime timestamp;

  @override
  final String runId;

  /// Pipeline identifier.
  final String pipelineId;

  /// Stage identifier.
  final String stageId;

  /// Error message.
  final String error;

  /// Whether stage will be retried.
  final bool willRetry;

  const StageFailedEvent({
    required this.timestamp,
    required this.runId,
    required this.pipelineId,
    required this.stageId,
    required this.error,
    this.willRetry = false,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'runId': runId,
        'pipelineId': pipelineId,
        'stageId': stageId,
        'error': error,
        'willRetry': willRetry,
      };
}

/// Stage skipped event.
class StageSkippedEvent implements ExecutionEvent {
  @override
  final String type = 'stage.skipped';

  @override
  final DateTime timestamp;

  @override
  final String runId;

  /// Pipeline identifier.
  final String pipelineId;

  /// Stage identifier.
  final String stageId;

  /// Reason for skipping.
  final String reason;

  const StageSkippedEvent({
    required this.timestamp,
    required this.runId,
    required this.pipelineId,
    required this.stageId,
    required this.reason,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'runId': runId,
        'pipelineId': pipelineId,
        'stageId': stageId,
        'reason': reason,
      };
}

/// Gate evaluated event.
class GateEvaluatedEvent implements ExecutionEvent {
  @override
  final String type = 'gate.evaluated';

  @override
  final DateTime timestamp;

  @override
  final String runId;

  /// Pipeline identifier.
  final String pipelineId;

  /// Gate identifier.
  final String gateId;

  /// Whether gate passed.
  final bool passed;

  /// Condition results summary.
  final Map<String, bool> conditions;

  const GateEvaluatedEvent({
    required this.timestamp,
    required this.runId,
    required this.pipelineId,
    required this.gateId,
    required this.passed,
    required this.conditions,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'runId': runId,
        'pipelineId': pipelineId,
        'gateId': gateId,
        'passed': passed,
        'conditions': conditions,
      };
}

/// Checkpoint created event.
class CheckpointCreatedEvent implements ExecutionEvent {
  @override
  final String type = 'checkpoint.created';

  @override
  final DateTime timestamp;

  @override
  final String runId;

  /// Checkpoint identifier.
  final String checkpointId;

  /// Checkpoint name.
  final String name;

  /// Last completed stage.
  final String? lastStage;

  const CheckpointCreatedEvent({
    required this.timestamp,
    required this.runId,
    required this.checkpointId,
    required this.name,
    this.lastStage,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'runId': runId,
        'checkpointId': checkpointId,
        'name': name,
        if (lastStage != null) 'lastStage': lastStage,
      };
}

/// Execution resumed event.
class ExecutionResumedEvent implements ExecutionEvent {
  @override
  final String type = 'execution.resumed';

  @override
  final DateTime timestamp;

  @override
  final String runId;

  /// Checkpoint used to resume.
  final String checkpointId;

  /// Stage to resume from.
  final String resumeFromStage;

  const ExecutionResumedEvent({
    required this.timestamp,
    required this.runId,
    required this.checkpointId,
    required this.resumeFromStage,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'runId': runId,
        'checkpointId': checkpointId,
        'resumeFromStage': resumeFromStage,
      };
}

/// Workflow started event.
class WorkflowStartedEvent implements ExecutionEvent {
  @override
  final String type = 'workflow.started';

  @override
  final DateTime timestamp;

  @override
  final String runId;

  /// Workflow identifier.
  final String workflowId;

  const WorkflowStartedEvent({
    required this.timestamp,
    required this.runId,
    required this.workflowId,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'runId': runId,
        'workflowId': workflowId,
      };
}

/// Workflow completed event.
class WorkflowCompletedEvent implements ExecutionEvent {
  @override
  final String type = 'workflow.completed';

  @override
  final DateTime timestamp;

  @override
  final String runId;

  /// Workflow identifier.
  final String workflowId;

  /// Whether execution succeeded.
  final bool success;

  /// Total duration.
  final Duration duration;

  const WorkflowCompletedEvent({
    required this.timestamp,
    required this.runId,
    required this.workflowId,
    required this.success,
    required this.duration,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'runId': runId,
        'workflowId': workflowId,
        'success': success,
        'durationMs': duration.inMilliseconds,
      };
}

/// Review requested event.
class ReviewRequestedEvent implements ExecutionEvent {
  @override
  final String type = 'review.requested';

  @override
  final DateTime timestamp;

  @override
  final String runId;

  /// Stage requiring review.
  final String stageId;

  /// Reviewers.
  final List<String> reviewers;

  const ReviewRequestedEvent({
    required this.timestamp,
    required this.runId,
    required this.stageId,
    required this.reviewers,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'runId': runId,
        'stageId': stageId,
        'reviewers': reviewers,
      };
}

/// Review completed event.
class ReviewCompletedEvent implements ExecutionEvent {
  @override
  final String type = 'review.completed';

  @override
  final DateTime timestamp;

  @override
  final String runId;

  /// Stage reviewed.
  final String stageId;

  /// Review decision.
  final String decision;

  /// Reviewer.
  final String reviewer;

  const ReviewCompletedEvent({
    required this.timestamp,
    required this.runId,
    required this.stageId,
    required this.decision,
    required this.reviewer,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'runId': runId,
        'stageId': stageId,
        'decision': decision,
        'reviewer': reviewer,
      };
}

/// Approval requested event.
class ApprovalRequestedEvent implements ExecutionEvent {
  @override
  final String type = 'approval.requested';

  @override
  final DateTime timestamp;

  @override
  final String runId;

  /// Stage requiring approval.
  final String stageId;

  /// Approvers.
  final List<String> approvers;

  /// Required approvals count.
  final int requiredApprovals;

  const ApprovalRequestedEvent({
    required this.timestamp,
    required this.runId,
    required this.stageId,
    required this.approvers,
    required this.requiredApprovals,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'runId': runId,
        'stageId': stageId,
        'approvers': approvers,
        'requiredApprovals': requiredApprovals,
      };
}

/// Approval completed event.
class ApprovalCompletedEvent implements ExecutionEvent {
  @override
  final String type = 'approval.completed';

  @override
  final DateTime timestamp;

  @override
  final String runId;

  /// Stage approved.
  final String stageId;

  /// Whether approved.
  final bool approved;

  /// Approver.
  final String approver;

  const ApprovalCompletedEvent({
    required this.timestamp,
    required this.runId,
    required this.stageId,
    required this.approved,
    required this.approver,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'runId': runId,
        'stageId': stageId,
        'approved': approved,
        'approver': approver,
      };
}
