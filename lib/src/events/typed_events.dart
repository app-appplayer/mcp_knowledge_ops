/// Typed Events - Strongly-typed event classes for the knowledge ops event architecture.
///
/// Each class extends [OpsEvent] and provides typed fields for its specific
/// event category (pipeline, workflow, schedule, execution, integration).
/// Event type strings follow the 'ops.<category>.<action>' convention.
library;

import 'ops_event.dart';

// ═══════════════════════════════════════════════════════════════════
// Pipeline Events
// ═══════════════════════════════════════════════════════════════════

/// Emitted when a pipeline execution begins.
class PipelineStartedEvent extends OpsEvent {
  /// Pipeline identifier.
  final String pipelineId;

  /// Optional input data for the pipeline.
  final Map<String, dynamic>? input;

  /// Human-readable pipeline name.
  final String? pipelineName;

  /// Pipeline version string.
  final String? pipelineVersion;

  /// Ordered list of stage identifiers in the pipeline.
  final List<String>? stages;

  /// Pipeline configuration parameters.
  final Map<String, dynamic>? config;

  PipelineStartedEvent({
    required this.pipelineId,
    this.input,
    this.pipelineName,
    this.pipelineVersion,
    this.stages,
    this.config,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.pipeline.started',
          payload: {
            'pipelineId': pipelineId,
            if (input != null) 'input': input,
            if (pipelineName != null) 'pipelineName': pipelineName,
            if (pipelineVersion != null) 'pipelineVersion': pipelineVersion,
            if (stages != null) 'stages': stages,
            if (config != null) 'config': config,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory PipelineStartedEvent.create({
    required String pipelineId,
    Map<String, dynamic>? input,
    String? pipelineName,
    String? pipelineVersion,
    List<String>? stages,
    Map<String, dynamic>? config,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.pipeline.started',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'pipelineId': pipelineId,
        if (input != null) 'input': input,
        if (pipelineName != null) 'pipelineName': pipelineName,
        if (pipelineVersion != null) 'pipelineVersion': pipelineVersion,
        if (stages != null) 'stages': stages,
        if (config != null) 'config': config,
      },
      meta: meta,
    );
    return PipelineStartedEvent(
      pipelineId: pipelineId,
      input: input,
      pipelineName: pipelineName,
      pipelineVersion: pipelineVersion,
      stages: stages,
      config: config,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a pipeline stage completes successfully.
class PipelineStageCompletedEvent extends OpsEvent {
  /// Pipeline identifier.
  final String pipelineId;

  /// Completed stage identifier.
  final String stageId;

  /// Optional output from the stage.
  final Map<String, dynamic>? output;

  /// Human-readable stage name.
  final String? stageName;

  /// Zero-based index of the completed stage.
  final int? stageIndex;

  /// Result data from the stage execution.
  final Map<String, dynamic>? result;

  /// Duration the stage took to complete.
  final Duration? duration;

  PipelineStageCompletedEvent({
    required this.pipelineId,
    required this.stageId,
    this.output,
    this.stageName,
    this.stageIndex,
    this.result,
    this.duration,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.pipeline.stage_completed',
          payload: {
            'pipelineId': pipelineId,
            'stageId': stageId,
            if (output != null) 'output': output,
            if (stageName != null) 'stageName': stageName,
            if (stageIndex != null) 'stageIndex': stageIndex,
            if (result != null) 'result': result,
            if (duration != null) 'durationMs': duration.inMilliseconds,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory PipelineStageCompletedEvent.create({
    required String pipelineId,
    required String stageId,
    Map<String, dynamic>? output,
    String? stageName,
    int? stageIndex,
    Map<String, dynamic>? result,
    Duration? duration,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.pipeline.stage_completed',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'pipelineId': pipelineId,
        'stageId': stageId,
        if (output != null) 'output': output,
        if (stageName != null) 'stageName': stageName,
        if (stageIndex != null) 'stageIndex': stageIndex,
        if (result != null) 'result': result,
        if (duration != null) 'durationMs': duration.inMilliseconds,
      },
      meta: meta,
    );
    return PipelineStageCompletedEvent(
      pipelineId: pipelineId,
      stageId: stageId,
      output: output,
      stageName: stageName,
      stageIndex: stageIndex,
      result: result,
      duration: duration,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a pipeline completes all stages successfully.
class PipelineCompletedEvent extends OpsEvent {
  /// Pipeline identifier.
  final String pipelineId;

  /// Optional result from the pipeline.
  final Map<String, dynamic>? result;

  /// Human-readable pipeline name.
  final String? pipelineName;

  /// Completion status string.
  final String? status;

  /// Number of stages that completed successfully.
  final int? stagesCompleted;

  /// Total number of stages in the pipeline.
  final int? totalStages;

  /// Total duration of the pipeline execution.
  final Duration? duration;

  /// Final output data from the pipeline.
  final Map<String, dynamic>? output;

  /// Performance and execution metrics.
  final Map<String, dynamic>? metrics;

  PipelineCompletedEvent({
    required this.pipelineId,
    this.result,
    this.pipelineName,
    this.status,
    this.stagesCompleted,
    this.totalStages,
    this.duration,
    this.output,
    this.metrics,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.pipeline.completed',
          payload: {
            'pipelineId': pipelineId,
            if (result != null) 'result': result,
            if (pipelineName != null) 'pipelineName': pipelineName,
            if (status != null) 'status': status,
            if (stagesCompleted != null) 'stagesCompleted': stagesCompleted,
            if (totalStages != null) 'totalStages': totalStages,
            if (duration != null) 'durationMs': duration.inMilliseconds,
            if (output != null) 'output': output,
            if (metrics != null) 'metrics': metrics,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory PipelineCompletedEvent.create({
    required String pipelineId,
    Map<String, dynamic>? result,
    String? pipelineName,
    String? status,
    int? stagesCompleted,
    int? totalStages,
    Duration? duration,
    Map<String, dynamic>? output,
    Map<String, dynamic>? metrics,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.pipeline.completed',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'pipelineId': pipelineId,
        if (result != null) 'result': result,
        if (pipelineName != null) 'pipelineName': pipelineName,
        if (status != null) 'status': status,
        if (stagesCompleted != null) 'stagesCompleted': stagesCompleted,
        if (totalStages != null) 'totalStages': totalStages,
        if (duration != null) 'durationMs': duration.inMilliseconds,
        if (output != null) 'output': output,
        if (metrics != null) 'metrics': metrics,
      },
      meta: meta,
    );
    return PipelineCompletedEvent(
      pipelineId: pipelineId,
      result: result,
      pipelineName: pipelineName,
      status: status,
      stagesCompleted: stagesCompleted,
      totalStages: totalStages,
      duration: duration,
      output: output,
      metrics: metrics,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a pipeline fails during execution.
class PipelineFailedEvent extends OpsEvent {
  /// Pipeline identifier.
  final String pipelineId;

  /// Error description.
  final String error;

  /// Stage where the failure occurred, if applicable.
  final String? failedStage;

  /// Human-readable pipeline name.
  final String? pipelineName;

  /// Zero-based index of the stage where failure occurred.
  final int? stageIndex;

  /// Machine-readable error code.
  final String? errorCode;

  /// Stack trace of the error.
  final String? errorStack;

  /// Partial output produced before the failure.
  final Map<String, dynamic>? partialOutput;

  /// Whether the failed operation can be retried.
  final bool? retryable;

  PipelineFailedEvent({
    required this.pipelineId,
    required this.error,
    this.failedStage,
    this.pipelineName,
    this.stageIndex,
    this.errorCode,
    this.errorStack,
    this.partialOutput,
    this.retryable,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.pipeline.failed',
          payload: {
            'pipelineId': pipelineId,
            'error': error,
            if (failedStage != null) 'failedStage': failedStage,
            if (pipelineName != null) 'pipelineName': pipelineName,
            if (stageIndex != null) 'stageIndex': stageIndex,
            if (errorCode != null) 'errorCode': errorCode,
            if (errorStack != null) 'errorStack': errorStack,
            if (partialOutput != null) 'partialOutput': partialOutput,
            if (retryable != null) 'retryable': retryable,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory PipelineFailedEvent.create({
    required String pipelineId,
    required String error,
    String? failedStage,
    String? pipelineName,
    int? stageIndex,
    String? errorCode,
    String? errorStack,
    Map<String, dynamic>? partialOutput,
    bool? retryable,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.pipeline.failed',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'pipelineId': pipelineId,
        'error': error,
        if (failedStage != null) 'failedStage': failedStage,
        if (pipelineName != null) 'pipelineName': pipelineName,
        if (stageIndex != null) 'stageIndex': stageIndex,
        if (errorCode != null) 'errorCode': errorCode,
        if (errorStack != null) 'errorStack': errorStack,
        if (partialOutput != null) 'partialOutput': partialOutput,
        if (retryable != null) 'retryable': retryable,
      },
      meta: meta,
    );
    return PipelineFailedEvent(
      pipelineId: pipelineId,
      error: error,
      failedStage: failedStage,
      pipelineName: pipelineName,
      stageIndex: stageIndex,
      errorCode: errorCode,
      errorStack: errorStack,
      partialOutput: partialOutput,
      retryable: retryable,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Workflow Events
// ═══════════════════════════════════════════════════════════════════

/// Emitted when a workflow execution begins.
class WorkflowStartedEvent extends OpsEvent {
  /// Workflow identifier.
  final String workflowId;

  /// Optional input data for the workflow.
  final Map<String, dynamic>? input;

  /// Human-readable workflow name.
  final String? workflowName;

  /// Workflow version string.
  final String? workflowVersion;

  /// Ordered list of step identifiers in the workflow.
  final List<String>? steps;

  /// List of gate identifiers in the workflow.
  final List<String>? gates;

  WorkflowStartedEvent({
    required this.workflowId,
    this.input,
    this.workflowName,
    this.workflowVersion,
    this.steps,
    this.gates,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.workflow.started',
          payload: {
            'workflowId': workflowId,
            if (input != null) 'input': input,
            if (workflowName != null) 'workflowName': workflowName,
            if (workflowVersion != null) 'workflowVersion': workflowVersion,
            if (steps != null) 'steps': steps,
            if (gates != null) 'gates': gates,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory WorkflowStartedEvent.create({
    required String workflowId,
    Map<String, dynamic>? input,
    String? workflowName,
    String? workflowVersion,
    List<String>? steps,
    List<String>? gates,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.workflow.started',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'workflowId': workflowId,
        if (input != null) 'input': input,
        if (workflowName != null) 'workflowName': workflowName,
        if (workflowVersion != null) 'workflowVersion': workflowVersion,
        if (steps != null) 'steps': steps,
        if (gates != null) 'gates': gates,
      },
      meta: meta,
    );
    return WorkflowStartedEvent(
      workflowId: workflowId,
      input: input,
      workflowName: workflowName,
      workflowVersion: workflowVersion,
      steps: steps,
      gates: gates,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a workflow step completes.
class WorkflowStepCompletedEvent extends OpsEvent {
  /// Workflow identifier.
  final String workflowId;

  /// Completed step identifier.
  final String stepId;

  /// Optional output from the step.
  final Map<String, dynamic>? output;

  WorkflowStepCompletedEvent({
    required this.workflowId,
    required this.stepId,
    this.output,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.workflow.step_completed',
          payload: {
            'workflowId': workflowId,
            'stepId': stepId,
            if (output != null) 'output': output,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory WorkflowStepCompletedEvent.create({
    required String workflowId,
    required String stepId,
    Map<String, dynamic>? output,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.workflow.step_completed',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'workflowId': workflowId,
        'stepId': stepId,
        if (output != null) 'output': output,
      },
      meta: meta,
    );
    return WorkflowStepCompletedEvent(
      workflowId: workflowId,
      stepId: stepId,
      output: output,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a workflow gate is evaluated.
class WorkflowGateEvaluatedEvent extends OpsEvent {
  /// Workflow identifier.
  final String workflowId;

  /// Gate identifier.
  final String gateId;

  /// Whether the gate passed.
  final bool passed;

  /// Human-readable gate name.
  final String? gateName;

  /// Result state of the gate evaluation (e.g. 'approved', 'rejected').
  final String? resultState;

  /// Conditions evaluated for this gate.
  final List<Map<String, dynamic>>? conditions;

  /// Action taken as a result of gate evaluation.
  final String? action;

  WorkflowGateEvaluatedEvent({
    required this.workflowId,
    required this.gateId,
    required this.passed,
    this.gateName,
    this.resultState,
    this.conditions,
    this.action,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.workflow.gate_evaluated',
          payload: {
            'workflowId': workflowId,
            'gateId': gateId,
            'passed': passed,
            if (gateName != null) 'gateName': gateName,
            if (resultState != null) 'resultState': resultState,
            if (conditions != null) 'conditions': conditions,
            if (action != null) 'action': action,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory WorkflowGateEvaluatedEvent.create({
    required String workflowId,
    required String gateId,
    required bool passed,
    String? gateName,
    String? resultState,
    List<Map<String, dynamic>>? conditions,
    String? action,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.workflow.gate_evaluated',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'workflowId': workflowId,
        'gateId': gateId,
        'passed': passed,
        if (gateName != null) 'gateName': gateName,
        if (resultState != null) 'resultState': resultState,
        if (conditions != null) 'conditions': conditions,
        if (action != null) 'action': action,
      },
      meta: meta,
    );
    return WorkflowGateEvaluatedEvent(
      workflowId: workflowId,
      gateId: gateId,
      passed: passed,
      gateName: gateName,
      resultState: resultState,
      conditions: conditions,
      action: action,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a workflow requires human approval.
class WorkflowApprovalRequestedEvent extends OpsEvent {
  /// Workflow identifier.
  final String workflowId;

  /// Approval request identifier.
  final String approvalId;

  /// List of approvers who can approve.
  final List<String> approvers;

  /// Gate identifier that triggered the approval request.
  final String? gateId;

  /// Deadline by which approval must be received.
  final DateTime? deadline;

  /// Additional context for the approval request.
  final Map<String, dynamic>? context;

  WorkflowApprovalRequestedEvent({
    required this.workflowId,
    required this.approvalId,
    required this.approvers,
    this.gateId,
    this.deadline,
    this.context,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.workflow.approval_requested',
          payload: {
            'workflowId': workflowId,
            'approvalId': approvalId,
            'approvers': approvers,
            if (gateId != null) 'gateId': gateId,
            if (deadline != null) 'deadline': deadline.toIso8601String(),
            if (context != null) 'context': context,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory WorkflowApprovalRequestedEvent.create({
    required String workflowId,
    required String approvalId,
    required List<String> approvers,
    String? gateId,
    DateTime? deadline,
    Map<String, dynamic>? context,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.workflow.approval_requested',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'workflowId': workflowId,
        'approvalId': approvalId,
        'approvers': approvers,
        if (gateId != null) 'gateId': gateId,
        if (deadline != null) 'deadline': deadline.toIso8601String(),
        if (context != null) 'context': context,
      },
      meta: meta,
    );
    return WorkflowApprovalRequestedEvent(
      workflowId: workflowId,
      approvalId: approvalId,
      approvers: approvers,
      gateId: gateId,
      deadline: deadline,
      context: context,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a workflow approval decision is received.
class WorkflowApprovalReceivedEvent extends OpsEvent {
  /// Workflow identifier.
  final String workflowId;

  /// Approval request identifier.
  final String approvalId;

  /// Whether the approval was granted.
  final bool approved;

  /// Approver who made the decision.
  final String approver;

  /// Decision string (e.g. 'approved', 'rejected', 'deferred').
  final String? decision;

  /// Optional comment from the approver.
  final String? comment;

  /// Timestamp when the decision was made.
  final DateTime? decisionTimestamp;

  WorkflowApprovalReceivedEvent({
    required this.workflowId,
    required this.approvalId,
    required this.approved,
    required this.approver,
    this.decision,
    this.comment,
    this.decisionTimestamp,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.workflow.approval_received',
          payload: {
            'workflowId': workflowId,
            'approvalId': approvalId,
            'approved': approved,
            'approver': approver,
            if (decision != null) 'decision': decision,
            if (comment != null) 'comment': comment,
            if (decisionTimestamp != null)
              'decisionTimestamp': decisionTimestamp.toIso8601String(),
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory WorkflowApprovalReceivedEvent.create({
    required String workflowId,
    required String approvalId,
    required bool approved,
    required String approver,
    String? decision,
    String? comment,
    DateTime? decisionTimestamp,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.workflow.approval_received',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'workflowId': workflowId,
        'approvalId': approvalId,
        'approved': approved,
        'approver': approver,
        if (decision != null) 'decision': decision,
        if (comment != null) 'comment': comment,
        if (decisionTimestamp != null)
          'decisionTimestamp': decisionTimestamp.toIso8601String(),
      },
      meta: meta,
    );
    return WorkflowApprovalReceivedEvent(
      workflowId: workflowId,
      approvalId: approvalId,
      approved: approved,
      approver: approver,
      decision: decision,
      comment: comment,
      decisionTimestamp: decisionTimestamp,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a workflow completes all steps.
class WorkflowCompletedEvent extends OpsEvent {
  /// Workflow identifier.
  final String workflowId;

  /// Optional result from the workflow.
  final Map<String, dynamic>? result;

  /// Human-readable workflow name.
  final String? workflowName;

  /// Completion status string.
  final String? status;

  /// Number of steps that completed successfully.
  final int? stepsCompleted;

  /// Number of gates that passed.
  final int? gatesPassed;

  /// Total duration of the workflow execution.
  final Duration? duration;

  /// Final output data from the workflow.
  final Map<String, dynamic>? output;

  /// Artifacts produced by the workflow.
  final List<Map<String, dynamic>>? artifacts;

  WorkflowCompletedEvent({
    required this.workflowId,
    this.result,
    this.workflowName,
    this.status,
    this.stepsCompleted,
    this.gatesPassed,
    this.duration,
    this.output,
    this.artifacts,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.workflow.completed',
          payload: {
            'workflowId': workflowId,
            if (result != null) 'result': result,
            if (workflowName != null) 'workflowName': workflowName,
            if (status != null) 'status': status,
            if (stepsCompleted != null) 'stepsCompleted': stepsCompleted,
            if (gatesPassed != null) 'gatesPassed': gatesPassed,
            if (duration != null) 'durationMs': duration.inMilliseconds,
            if (output != null) 'output': output,
            if (artifacts != null) 'artifacts': artifacts,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory WorkflowCompletedEvent.create({
    required String workflowId,
    Map<String, dynamic>? result,
    String? workflowName,
    String? status,
    int? stepsCompleted,
    int? gatesPassed,
    Duration? duration,
    Map<String, dynamic>? output,
    List<Map<String, dynamic>>? artifacts,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.workflow.completed',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'workflowId': workflowId,
        if (result != null) 'result': result,
        if (workflowName != null) 'workflowName': workflowName,
        if (status != null) 'status': status,
        if (stepsCompleted != null) 'stepsCompleted': stepsCompleted,
        if (gatesPassed != null) 'gatesPassed': gatesPassed,
        if (duration != null) 'durationMs': duration.inMilliseconds,
        if (output != null) 'output': output,
        if (artifacts != null) 'artifacts': artifacts,
      },
      meta: meta,
    );
    return WorkflowCompletedEvent(
      workflowId: workflowId,
      result: result,
      workflowName: workflowName,
      status: status,
      stepsCompleted: stepsCompleted,
      gatesPassed: gatesPassed,
      duration: duration,
      output: output,
      artifacts: artifacts,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a workflow fails.
class WorkflowFailedEvent extends OpsEvent {
  /// Workflow identifier.
  final String workflowId;

  /// Error description.
  final String error;

  WorkflowFailedEvent({
    required this.workflowId,
    required this.error,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.workflow.failed',
          payload: {
            'workflowId': workflowId,
            'error': error,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory WorkflowFailedEvent.create({
    required String workflowId,
    required String error,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.workflow.failed',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'workflowId': workflowId,
        'error': error,
      },
      meta: meta,
    );
    return WorkflowFailedEvent(
      workflowId: workflowId,
      error: error,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Schedule Events
// ═══════════════════════════════════════════════════════════════════

/// Emitted when a schedule is registered.
class ScheduleRegisteredEvent extends OpsEvent {
  /// Schedule identifier.
  final String scheduleId;

  /// Human-readable schedule name.
  final String name;

  ScheduleRegisteredEvent({
    required this.scheduleId,
    required this.name,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.schedule.registered',
          payload: {
            'scheduleId': scheduleId,
            'name': name,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory ScheduleRegisteredEvent.create({
    required String scheduleId,
    required String name,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.schedule.registered',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'scheduleId': scheduleId,
        'name': name,
      },
      meta: meta,
    );
    return ScheduleRegisteredEvent(
      scheduleId: scheduleId,
      name: name,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a schedule fires and triggers an execution.
class ScheduleTriggeredEvent extends OpsEvent {
  /// Schedule identifier.
  final String scheduleId;

  /// Execution ID that was triggered.
  final String executionId;

  ScheduleTriggeredEvent({
    required this.scheduleId,
    required this.executionId,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.schedule.triggered',
          payload: {
            'scheduleId': scheduleId,
            'executionId': executionId,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory ScheduleTriggeredEvent.create({
    required String scheduleId,
    required String executionId,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.schedule.triggered',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'scheduleId': scheduleId,
        'executionId': executionId,
      },
      meta: meta,
    );
    return ScheduleTriggeredEvent(
      scheduleId: scheduleId,
      executionId: executionId,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a schedule is paused.
class SchedulePausedEvent extends OpsEvent {
  /// Schedule identifier.
  final String scheduleId;

  SchedulePausedEvent({
    required this.scheduleId,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.schedule.paused',
          payload: {
            'scheduleId': scheduleId,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory SchedulePausedEvent.create({
    required String scheduleId,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.schedule.paused',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'scheduleId': scheduleId,
      },
      meta: meta,
    );
    return SchedulePausedEvent(
      scheduleId: scheduleId,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a schedule is resumed from a paused state.
class ScheduleResumedEvent extends OpsEvent {
  /// Schedule identifier.
  final String scheduleId;

  ScheduleResumedEvent({
    required this.scheduleId,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.schedule.resumed',
          payload: {
            'scheduleId': scheduleId,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory ScheduleResumedEvent.create({
    required String scheduleId,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.schedule.resumed',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'scheduleId': scheduleId,
      },
      meta: meta,
    );
    return ScheduleResumedEvent(
      scheduleId: scheduleId,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a schedule is deleted.
class ScheduleDeletedEvent extends OpsEvent {
  /// Schedule identifier.
  final String scheduleId;

  ScheduleDeletedEvent({
    required this.scheduleId,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.schedule.deleted',
          payload: {
            'scheduleId': scheduleId,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory ScheduleDeletedEvent.create({
    required String scheduleId,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.schedule.deleted',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'scheduleId': scheduleId,
      },
      meta: meta,
    );
    return ScheduleDeletedEvent(
      scheduleId: scheduleId,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Execution Events
// ═══════════════════════════════════════════════════════════════════

/// Emitted when an execution is queued for processing.
class ExecutionQueuedEvent extends OpsEvent {
  /// Execution identifier.
  final String executionId;

  /// Optional schedule that triggered this execution.
  final String? scheduleId;

  /// Type of target being executed (e.g. 'pipeline', 'workflow').
  final String? targetType;

  /// Identifier of the target being executed.
  final String? targetId;

  /// Priority level for queue ordering.
  final int? priority;

  /// Scheduled execution time.
  final DateTime? scheduledFor;

  /// Entity or user that triggered the execution.
  final String? triggeredBy;

  ExecutionQueuedEvent({
    required this.executionId,
    this.scheduleId,
    this.targetType,
    this.targetId,
    this.priority,
    this.scheduledFor,
    this.triggeredBy,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.execution.queued',
          payload: {
            'executionId': executionId,
            if (scheduleId != null) 'scheduleId': scheduleId,
            if (targetType != null) 'targetType': targetType,
            if (targetId != null) 'targetId': targetId,
            if (priority != null) 'priority': priority,
            if (scheduledFor != null)
              'scheduledFor': scheduledFor.toIso8601String(),
            if (triggeredBy != null) 'triggeredBy': triggeredBy,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory ExecutionQueuedEvent.create({
    required String executionId,
    String? scheduleId,
    String? targetType,
    String? targetId,
    int? priority,
    DateTime? scheduledFor,
    String? triggeredBy,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.execution.queued',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'executionId': executionId,
        if (scheduleId != null) 'scheduleId': scheduleId,
        if (targetType != null) 'targetType': targetType,
        if (targetId != null) 'targetId': targetId,
        if (priority != null) 'priority': priority,
        if (scheduledFor != null)
          'scheduledFor': scheduledFor.toIso8601String(),
        if (triggeredBy != null) 'triggeredBy': triggeredBy,
      },
      meta: meta,
    );
    return ExecutionQueuedEvent(
      executionId: executionId,
      scheduleId: scheduleId,
      targetType: targetType,
      targetId: targetId,
      priority: priority,
      scheduledFor: scheduledFor,
      triggeredBy: triggeredBy,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when an execution starts processing.
class ExecutionStartedEvent extends OpsEvent {
  /// Execution identifier.
  final String executionId;

  ExecutionStartedEvent({
    required this.executionId,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.execution.started',
          payload: {
            'executionId': executionId,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory ExecutionStartedEvent.create({
    required String executionId,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.execution.started',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'executionId': executionId,
      },
      meta: meta,
    );
    return ExecutionStartedEvent(
      executionId: executionId,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a checkpoint is created during execution.
class CheckpointCreatedEvent extends OpsEvent {
  /// Execution identifier.
  final String executionId;

  /// Checkpoint identifier.
  final String checkpointId;

  /// Stage identifier at which the checkpoint was created.
  final String? stageId;

  /// Captured state at the checkpoint.
  final Map<String, dynamic>? state;

  /// Whether the checkpoint can be used for recovery.
  final bool? recoverable;

  CheckpointCreatedEvent({
    required this.executionId,
    required this.checkpointId,
    this.stageId,
    this.state,
    this.recoverable,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.execution.checkpoint_created',
          payload: {
            'executionId': executionId,
            'checkpointId': checkpointId,
            if (stageId != null) 'stageId': stageId,
            if (state != null) 'state': state,
            if (recoverable != null) 'recoverable': recoverable,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory CheckpointCreatedEvent.create({
    required String executionId,
    required String checkpointId,
    String? stageId,
    Map<String, dynamic>? state,
    bool? recoverable,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.execution.checkpoint_created',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'executionId': executionId,
        'checkpointId': checkpointId,
        if (stageId != null) 'stageId': stageId,
        if (state != null) 'state': state,
        if (recoverable != null) 'recoverable': recoverable,
      },
      meta: meta,
    );
    return CheckpointCreatedEvent(
      executionId: executionId,
      checkpointId: checkpointId,
      stageId: stageId,
      state: state,
      recoverable: recoverable,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a checkpoint is restored during recovery.
class CheckpointRestoredEvent extends OpsEvent {
  /// Execution identifier.
  final String executionId;

  /// Checkpoint identifier that was restored.
  final String checkpointId;

  CheckpointRestoredEvent({
    required this.executionId,
    required this.checkpointId,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.execution.checkpoint_restored',
          payload: {
            'executionId': executionId,
            'checkpointId': checkpointId,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory CheckpointRestoredEvent.create({
    required String executionId,
    required String checkpointId,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.execution.checkpoint_restored',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'executionId': executionId,
        'checkpointId': checkpointId,
      },
      meta: meta,
    );
    return CheckpointRestoredEvent(
      executionId: executionId,
      checkpointId: checkpointId,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when an execution completes.
class ExecutionCompletedEvent extends OpsEvent {
  /// Execution identifier.
  final String executionId;

  /// Whether the execution succeeded.
  final bool success;

  ExecutionCompletedEvent({
    required this.executionId,
    required this.success,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.execution.completed',
          payload: {
            'executionId': executionId,
            'success': success,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory ExecutionCompletedEvent.create({
    required String executionId,
    required bool success,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.execution.completed',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'executionId': executionId,
        'success': success,
      },
      meta: meta,
    );
    return ExecutionCompletedEvent(
      executionId: executionId,
      success: success,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when an execution fails.
class ExecutionFailedEvent extends OpsEvent {
  /// Execution identifier.
  final String executionId;

  /// Error description.
  final String error;

  ExecutionFailedEvent({
    required this.executionId,
    required this.error,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.execution.failed',
          payload: {
            'executionId': executionId,
            'error': error,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory ExecutionFailedEvent.create({
    required String executionId,
    required String error,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.execution.failed',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'executionId': executionId,
        'error': error,
      },
      meta: meta,
    );
    return ExecutionFailedEvent(
      executionId: executionId,
      error: error,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when an execution is rolled back.
class ExecutionRolledBackEvent extends OpsEvent {
  /// Execution identifier.
  final String executionId;

  /// Optional reason for rollback.
  final String? reason;

  /// Checkpoint identifier to roll back to.
  final String? checkpointId;

  /// Detailed reason for the rollback.
  final String? rollbackReason;

  /// List of stage identifiers affected by the rollback.
  final List<String>? affectedStages;

  /// List of compensating actions executed during rollback.
  final List<String>? compensatingActions;

  ExecutionRolledBackEvent({
    required this.executionId,
    this.reason,
    this.checkpointId,
    this.rollbackReason,
    this.affectedStages,
    this.compensatingActions,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.execution.rolled_back',
          payload: {
            'executionId': executionId,
            if (reason != null) 'reason': reason,
            if (checkpointId != null) 'checkpointId': checkpointId,
            if (rollbackReason != null) 'rollbackReason': rollbackReason,
            if (affectedStages != null) 'affectedStages': affectedStages,
            if (compensatingActions != null)
              'compensatingActions': compensatingActions,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory ExecutionRolledBackEvent.create({
    required String executionId,
    String? reason,
    String? checkpointId,
    String? rollbackReason,
    List<String>? affectedStages,
    List<String>? compensatingActions,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.execution.rolled_back',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'executionId': executionId,
        if (reason != null) 'reason': reason,
        if (checkpointId != null) 'checkpointId': checkpointId,
        if (rollbackReason != null) 'rollbackReason': rollbackReason,
        if (affectedStages != null) 'affectedStages': affectedStages,
        if (compensatingActions != null)
          'compensatingActions': compensatingActions,
      },
      meta: meta,
    );
    return ExecutionRolledBackEvent(
      executionId: executionId,
      reason: reason,
      checkpointId: checkpointId,
      rollbackReason: rollbackReason,
      affectedStages: affectedStages,
      compensatingActions: compensatingActions,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Integration Events
// ═══════════════════════════════════════════════════════════════════

/// Emitted when a fact graph entity is created, updated, or deleted.
class FactGraphUpdatedEvent extends OpsEvent {
  /// Fact or entity identifier.
  final String factId;

  /// Operation performed: 'create', 'update', or 'delete'.
  final String operation;

  /// Type of the entity being modified.
  final String? entityType;

  /// Identifier of the entity being modified.
  final String? entityId;

  /// List of individual field changes applied.
  final List<Map<String, dynamic>>? changes;

  /// Entity or user that triggered the update.
  final String? triggeredBy;

  FactGraphUpdatedEvent({
    required this.factId,
    required this.operation,
    this.entityType,
    this.entityId,
    this.changes,
    this.triggeredBy,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.integration.factgraph_updated',
          payload: {
            'factId': factId,
            'operation': operation,
            if (entityType != null) 'entityType': entityType,
            if (entityId != null) 'entityId': entityId,
            if (changes != null) 'changes': changes,
            if (triggeredBy != null) 'triggeredBy': triggeredBy,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory FactGraphUpdatedEvent.create({
    required String factId,
    required String operation,
    String? entityType,
    String? entityId,
    List<Map<String, dynamic>>? changes,
    String? triggeredBy,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.integration.factgraph_updated',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'factId': factId,
        'operation': operation,
        if (entityType != null) 'entityType': entityType,
        if (entityId != null) 'entityId': entityId,
        if (changes != null) 'changes': changes,
        if (triggeredBy != null) 'triggeredBy': triggeredBy,
      },
      meta: meta,
    );
    return FactGraphUpdatedEvent(
      factId: factId,
      operation: operation,
      entityType: entityType,
      entityId: entityId,
      changes: changes,
      triggeredBy: triggeredBy,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a skill execution completes.
class SkillExecutedEvent extends OpsEvent {
  /// Skill identifier.
  final String skillId;

  /// Optional result from the skill execution.
  final Map<String, dynamic>? result;

  /// Version of the skill that was executed.
  final String? skillVersion;

  /// Execution status string.
  final String? status;

  /// Duration of the skill execution.
  final Duration? duration;

  /// Summary of the input provided to the skill.
  final String? inputSummary;

  /// Summary of the output produced by the skill.
  final String? outputSummary;

  /// List of claims produced by the skill execution.
  final List<String>? claims;

  SkillExecutedEvent({
    required this.skillId,
    this.result,
    this.skillVersion,
    this.status,
    this.duration,
    this.inputSummary,
    this.outputSummary,
    this.claims,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.integration.skill_executed',
          payload: {
            'skillId': skillId,
            if (result != null) 'result': result,
            if (skillVersion != null) 'skillVersion': skillVersion,
            if (status != null) 'status': status,
            if (duration != null) 'durationMs': duration.inMilliseconds,
            if (inputSummary != null) 'inputSummary': inputSummary,
            if (outputSummary != null) 'outputSummary': outputSummary,
            if (claims != null) 'claims': claims,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory SkillExecutedEvent.create({
    required String skillId,
    Map<String, dynamic>? result,
    String? skillVersion,
    String? status,
    Duration? duration,
    String? inputSummary,
    String? outputSummary,
    List<String>? claims,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.integration.skill_executed',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'skillId': skillId,
        if (result != null) 'result': result,
        if (skillVersion != null) 'skillVersion': skillVersion,
        if (status != null) 'status': status,
        if (duration != null) 'durationMs': duration.inMilliseconds,
        if (inputSummary != null) 'inputSummary': inputSummary,
        if (outputSummary != null) 'outputSummary': outputSummary,
        if (claims != null) 'claims': claims,
      },
      meta: meta,
    );
    return SkillExecutedEvent(
      skillId: skillId,
      result: result,
      skillVersion: skillVersion,
      status: status,
      duration: duration,
      inputSummary: inputSummary,
      outputSummary: outputSummary,
      claims: claims,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a profile is applied to a skill execution.
class ProfileAppliedEvent extends OpsEvent {
  /// Profile identifier.
  final String profileId;

  /// Version of the profile that was applied.
  final String? profileVersion;

  /// Skill identifier the profile was applied to.
  final String? skillId;

  /// Result of the profile appraisal.
  final String? appraisalResult;

  /// List of decisions applied from the profile.
  final List<String>? decisionsApplied;

  ProfileAppliedEvent({
    required this.profileId,
    this.profileVersion,
    this.skillId,
    this.appraisalResult,
    this.decisionsApplied,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.integration.profile_applied',
          payload: {
            'profileId': profileId,
            if (profileVersion != null) 'profileVersion': profileVersion,
            if (skillId != null) 'skillId': skillId,
            if (appraisalResult != null) 'appraisalResult': appraisalResult,
            if (decisionsApplied != null) 'decisionsApplied': decisionsApplied,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory ProfileAppliedEvent.create({
    required String profileId,
    String? profileVersion,
    String? skillId,
    String? appraisalResult,
    List<String>? decisionsApplied,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.integration.profile_applied',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'profileId': profileId,
        if (profileVersion != null) 'profileVersion': profileVersion,
        if (skillId != null) 'skillId': skillId,
        if (appraisalResult != null) 'appraisalResult': appraisalResult,
        if (decisionsApplied != null) 'decisionsApplied': decisionsApplied,
      },
      meta: meta,
    );
    return ProfileAppliedEvent(
      profileId: profileId,
      profileVersion: profileVersion,
      skillId: skillId,
      appraisalResult: appraisalResult,
      decisionsApplied: decisionsApplied,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a bundle is published.
class BundlePublishedEvent extends OpsEvent {
  /// Bundle identifier.
  final String bundleId;

  /// Bundle version.
  final String bundleVersion;

  /// Type of the bundle (e.g. 'skill', 'knowledge', 'composite').
  final String? bundleType;

  /// Target where the bundle was published.
  final String? publishTarget;

  /// Checksum of the published bundle.
  final String? checksum;

  /// Size of the bundle in bytes.
  final int? size;

  BundlePublishedEvent({
    required this.bundleId,
    required this.bundleVersion,
    this.bundleType,
    this.publishTarget,
    this.checksum,
    this.size,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.integration.bundle_published',
          payload: {
            'bundleId': bundleId,
            'bundleVersion': bundleVersion,
            if (bundleType != null) 'bundleType': bundleType,
            if (publishTarget != null) 'publishTarget': publishTarget,
            if (checksum != null) 'checksum': checksum,
            if (size != null) 'size': size,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory BundlePublishedEvent.create({
    required String bundleId,
    required String bundleVersion,
    String? bundleType,
    String? publishTarget,
    String? checksum,
    int? size,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.integration.bundle_published',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'bundleId': bundleId,
        'bundleVersion': bundleVersion,
        if (bundleType != null) 'bundleType': bundleType,
        if (publishTarget != null) 'publishTarget': publishTarget,
        if (checksum != null) 'checksum': checksum,
        if (size != null) 'size': size,
      },
      meta: meta,
    );
    return BundlePublishedEvent(
      bundleId: bundleId,
      bundleVersion: bundleVersion,
      bundleType: bundleType,
      publishTarget: publishTarget,
      checksum: checksum,
      size: size,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}

/// Emitted when a notification is sent.
class NotificationSentEvent extends OpsEvent {
  /// Notification channel used.
  final String channel;

  /// Number of recipients the notification was sent to.
  final int recipientCount;

  NotificationSentEvent({
    required this.channel,
    required this.recipientCount,
    required super.eventId,
    required super.correlationId,
    required super.runId,
    required super.workspaceId,
    required super.timestamp,
    required super.meta,
    super.version,
    super.causationId,
  }) : super(
          eventType: 'ops.integration.notification_sent',
          payload: {
            'channel': channel,
            'recipientCount': recipientCount,
          },
        );

  /// Convenience factory with auto-generated ID and timestamp.
  factory NotificationSentEvent.create({
    required String channel,
    required int recipientCount,
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required OpsEventMeta meta,
  }) {
    final base = OpsEvent.create(
      eventType: 'ops.integration.notification_sent',
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      payload: {
        'channel': channel,
        'recipientCount': recipientCount,
      },
      meta: meta,
    );
    return NotificationSentEvent(
      channel: channel,
      recipientCount: recipientCount,
      eventId: base.eventId,
      correlationId: base.correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: base.timestamp,
      meta: meta,
    );
  }
}
