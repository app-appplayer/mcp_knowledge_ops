/// Runbook - Operational procedure definitions.
///
/// Defines runbook structure for operational procedures.
library;


// --- Enums ---

/// Runbook step types matching spec §3.
enum RunbookStepType {
  /// Execute a pipeline via ExecutionEngine.
  pipeline,

  /// Execute a workflow via ExecutionEngine.
  workflow,

  /// Run a script.
  script,

  /// Manual step (wait for user completion).
  manual,

  /// Wait for approval via ApprovalPort.
  approval,

  /// Send notification via NotificationPort.
  notification,

  /// Wait for condition.
  wait,

  /// Branch based on condition.
  decision,

  /// Run steps in parallel.
  parallel,

  /// Iterate over collection.
  loop,
}

/// Runbook category for classification.
enum RunbookCategory {
  /// Daily operational tasks.
  dailyOperations,

  /// Weekly maintenance tasks.
  weeklyMaintenance,

  /// Incident response procedures.
  incidentResponse,

  /// Deployment procedures.
  deployment,

  /// Recovery procedures.
  recovery,

  /// Scaling operations.
  scaling,

  /// Security-related procedures.
  security,

  /// Philosophy alignment procedures.
  philosophyAlignment,
}

/// Runbook severity level.
enum RunbookSeverity {
  /// Routine operations.
  routine,

  /// Important but not urgent.
  important,

  /// Critical operations requiring attention.
  critical,

  /// Emergency procedures.
  emergency,
}

/// Check type for step pre/post checks.
enum CheckType {
  /// Metric-based check.
  metric,

  /// Expression-based check.
  expression,

  /// Command-based check.
  command,
}

/// Check severity determines behavior on check failure.
enum CheckSeverity {
  /// Log warning but continue.
  warn,

  /// Fail the step.
  fail,
}

/// Wait condition type.
enum WaitType {
  /// Wait for metric threshold.
  metric,

  /// Wait for event.
  event,

  /// Wait until specific time.
  time,

  /// Wait for expression to evaluate true.
  expression,
}

/// Runbook variable types.
enum RunbookVariableType {
  string,
  number,
  boolean,
  list,
  map,
}

/// On failure behavior.
enum RunbookOnFailure {
  /// Fail the runbook execution.
  fail,

  /// Continue to next step.
  continue_,

  /// Skip the failed step and continue.
  skip,

  /// Rollback completed steps.
  rollback,
}

// --- Classes ---

/// Runbook definition.
class Runbook {
  /// Runbook identifier.
  final String id;

  /// Runbook name.
  final String name;

  /// Runbook description.
  final String description;

  /// Runbook version.
  final String version;

  /// Runbook category.
  final RunbookCategory? category;

  /// Runbook severity level.
  final RunbookSeverity? severity;

  /// Tags for search and filtering.
  final List<String> tags;

  /// Owner identifier (user or team).
  final String? owner;

  /// Runbook configuration.
  final RunbookConfig? config;

  /// Runbook steps.
  final List<RunbookStep> steps;

  /// Variables required.
  final List<RunbookVariable> variables;

  /// Runbook metadata.
  final Map<String, dynamic> metadata;

  /// Prerequisites that must be met before execution.
  final List<String> prerequisites;

  /// Triggers that can initiate this runbook.
  final List<RunbookTrigger> triggers;

  /// When this runbook was created.
  final DateTime? createdAt;

  /// When this runbook was last updated.
  final DateTime? updatedAt;

  const Runbook({
    required this.id,
    required this.name,
    this.description = '',
    this.version = '1.0.0',
    this.category,
    this.severity,
    this.tags = const [],
    this.owner,
    this.config,
    required this.steps,
    this.variables = const [],
    this.metadata = const {},
    this.prerequisites = const [],
    this.triggers = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Validate runbook variables.
  List<String> validateVariables(Map<String, dynamic> providedVariables) {
    final errors = <String>[];

    for (final variable in variables) {
      if (variable.required && !providedVariables.containsKey(variable.name)) {
        errors.add('Missing required variable: ${variable.name}');
      }
    }

    return errors;
  }

  /// Get default variable values.
  Map<String, dynamic> getDefaultVariables() {
    final defaults = <String, dynamic>{};
    for (final variable in variables) {
      if (variable.defaultValue != null) {
        defaults[variable.name] = variable.defaultValue;
      }
    }
    return defaults;
  }
}

/// Runbook configuration.
class RunbookConfig {
  /// Overall timeout for runbook execution.
  final Duration? timeout;

  /// Whether parallel step execution is allowed.
  final bool allowParallel;

  /// Whether approval is required before execution.
  final bool requireApproval;

  /// List of approver identifiers.
  final List<String> approvers;

  /// Recipients to notify on runbook start.
  final List<String> notifyOnStart;

  /// Recipients to notify on runbook completion.
  final List<String> notifyOnComplete;

  /// Recipients to notify on runbook failure.
  final List<String> notifyOnFailure;

  /// Whether to automatically rollback on failure.
  final bool autoRollback;

  /// Step IDs to execute during rollback.
  final List<String> rollbackSteps;

  /// Whether to retry on failure.
  final bool retryOnFailure;

  /// Maximum number of retries.
  final int maxRetries;

  const RunbookConfig({
    this.timeout,
    this.allowParallel = false,
    this.requireApproval = false,
    this.approvers = const [],
    this.notifyOnStart = const [],
    this.notifyOnComplete = const [],
    this.notifyOnFailure = const [],
    this.autoRollback = false,
    this.rollbackSteps = const [],
    this.retryOnFailure = false,
    this.maxRetries = 0,
  });
}

/// Runbook step.
class RunbookStep {
  /// Step identifier.
  final String id;

  /// Step name.
  final String name;

  /// Step description.
  final String description;

  /// Execution order (lower values execute first).
  final int order;

  /// Action to execute.
  final RunbookAction action;

  /// Condition for execution.
  final String? condition;

  /// Whether step can be skipped.
  final bool optional;

  /// On failure behavior.
  final RunbookOnFailure onFailure;

  /// Step timeout.
  final Duration? timeout;

  /// Step IDs that must complete before this step.
  final List<String> dependsOn;

  /// Checks to run before step execution.
  final List<StepCheck> preChecks;

  /// Checks to run after step execution.
  final List<StepCheck> postChecks;

  const RunbookStep({
    required this.id,
    required this.name,
    this.description = '',
    this.order = 0,
    required this.action,
    this.condition,
    this.optional = false,
    this.onFailure = RunbookOnFailure.fail,
    this.timeout,
    this.dependsOn = const [],
    this.preChecks = const [],
    this.postChecks = const [],
  });
}

/// Step check for pre/post validation.
class StepCheck {
  /// Check name.
  final String name;

  /// Check type.
  final CheckType type;

  /// Check configuration.
  final Map<String, dynamic> config;

  /// Severity determines behavior on failure.
  final CheckSeverity severity;

  const StepCheck({
    required this.name,
    required this.type,
    this.config = const {},
    this.severity = CheckSeverity.fail,
  });
}

/// Decision branch for decision actions.
class DecisionBranch {
  /// Condition expression to evaluate.
  final String condition;

  /// Step IDs to execute when condition is met.
  final List<String> steps;

  const DecisionBranch({
    required this.condition,
    required this.steps,
  });
}

/// Wait condition for advanced waiting scenarios.
class WaitCondition {
  /// Wait condition type.
  final WaitType type;

  /// Metric name (for metric-based waits).
  final String? metric;

  /// Event name (for event-based waits).
  final String? event;

  /// Target time (for time-based waits).
  final DateTime? until;

  /// Expression string (for expression-based waits).
  final String? expression;

  const WaitCondition({
    required this.type,
    this.metric,
    this.event,
    this.until,
    this.expression,
  });

  /// Create a metric-based wait condition.
  factory WaitCondition.metric(String metric) {
    return WaitCondition(type: WaitType.metric, metric: metric);
  }

  /// Create an event-based wait condition.
  factory WaitCondition.event(String event) {
    return WaitCondition(type: WaitType.event, event: event);
  }

  /// Create a time-based wait condition.
  factory WaitCondition.time(DateTime until) {
    return WaitCondition(type: WaitType.time, until: until);
  }

  /// Create an expression-based wait condition.
  factory WaitCondition.expression(String expression) {
    return WaitCondition(type: WaitType.expression, expression: expression);
  }
}

/// Runbook action.
class RunbookAction {
  /// Action type.
  final RunbookStepType type;

  /// Pipeline ID (for pipeline actions).
  final String? pipelineId;

  /// Workflow ID (for workflow actions).
  final String? workflowId;

  /// Input mapping.
  final Map<String, String> inputMapping;

  /// Output mapping.
  final Map<String, String> outputMapping;

  /// Action configuration.
  final Map<String, dynamic> config;

  // --- Decision fields ---

  /// Decision branches (for decision actions).
  final List<DecisionBranch>? branches;

  /// Default branch step ID when no condition matches (for decision actions).
  final String? defaultBranch;

  // --- Parallel fields ---

  /// Step IDs to execute in parallel (for parallel actions).
  final List<String>? parallelSteps;

  /// Maximum concurrent executions (for parallel actions).
  final int? maxConcurrent;

  /// Whether to fail fast on first error (for parallel actions).
  final bool failFast;

  // --- Loop fields ---

  /// Collection variable name to iterate over (for loop actions).
  final String? collection;

  /// Variable name for current item in iteration (for loop actions).
  final String? itemVariable;

  /// Step IDs to execute for each item (for loop actions).
  final List<String>? loopSteps;

  // --- Manual fields ---

  /// Instructions for manual step (for manual actions).
  final String? instructions;

  /// Checklist items for manual step (for manual actions).
  final List<String>? checklist;

  /// Expected duration for manual step (for manual actions).
  final Duration? expectedDuration;

  // --- Notification fields ---

  /// Notification channel (for notification actions).
  final String? channel;

  /// Notification template name (for notification actions).
  final String? template;

  /// Notification recipients (for notification actions).
  final List<String>? recipients;

  // --- Script fields ---

  /// Script content (for script actions).
  final String? script;

  /// Script interpreter (for script actions).
  final String? interpreter;

  const RunbookAction({
    required this.type,
    this.pipelineId,
    this.workflowId,
    this.inputMapping = const {},
    this.outputMapping = const {},
    this.config = const {},
    this.branches,
    this.defaultBranch,
    this.parallelSteps,
    this.maxConcurrent,
    this.failFast = false,
    this.collection,
    this.itemVariable,
    this.loopSteps,
    this.instructions,
    this.checklist,
    this.expectedDuration,
    this.channel,
    this.template,
    this.recipients,
    this.script,
    this.interpreter,
  });

  /// Create pipeline action.
  factory RunbookAction.pipeline(
    String pipelineId, {
    Map<String, String> inputMapping = const {},
    Map<String, String> outputMapping = const {},
  }) {
    return RunbookAction(
      type: RunbookStepType.pipeline,
      pipelineId: pipelineId,
      inputMapping: inputMapping,
      outputMapping: outputMapping,
    );
  }

  /// Create workflow action.
  factory RunbookAction.workflow(
    String workflowId, {
    Map<String, String> inputMapping = const {},
    Map<String, String> outputMapping = const {},
  }) {
    return RunbookAction(
      type: RunbookStepType.workflow,
      workflowId: workflowId,
      inputMapping: inputMapping,
      outputMapping: outputMapping,
    );
  }

  /// Create wait action.
  factory RunbookAction.wait(Duration duration) {
    return RunbookAction(
      type: RunbookStepType.wait,
      config: {'duration': duration.inMilliseconds},
    );
  }

  /// Create approval action.
  factory RunbookAction.approval({
    required List<String> approvers,
    int requiredApprovals = 1,
  }) {
    return RunbookAction(
      type: RunbookStepType.approval,
      config: {
        'approvers': approvers,
        'requiredApprovals': requiredApprovals,
      },
    );
  }

  /// Create decision action with branches.
  factory RunbookAction.decision({
    required List<DecisionBranch> branches,
    String? defaultBranch,
    Map<String, dynamic> config = const {},
  }) {
    return RunbookAction(
      type: RunbookStepType.decision,
      branches: branches,
      defaultBranch: defaultBranch,
      config: config,
    );
  }

  /// Create parallel execution action.
  factory RunbookAction.parallel({
    required List<String> steps,
    int? maxConcurrent,
    bool failFast = false,
    Map<String, dynamic> config = const {},
  }) {
    return RunbookAction(
      type: RunbookStepType.parallel,
      parallelSteps: steps,
      maxConcurrent: maxConcurrent,
      failFast: failFast,
      config: config,
    );
  }

  /// Create loop action to iterate over a collection.
  factory RunbookAction.loop({
    required String collection,
    required String itemVariable,
    required List<String> steps,
    Map<String, dynamic> config = const {},
  }) {
    return RunbookAction(
      type: RunbookStepType.loop,
      collection: collection,
      itemVariable: itemVariable,
      loopSteps: steps,
      config: config,
    );
  }

  /// Create manual step action.
  factory RunbookAction.manual({
    required String instructions,
    List<String>? checklist,
    Duration? expectedDuration,
    Map<String, dynamic> config = const {},
  }) {
    return RunbookAction(
      type: RunbookStepType.manual,
      instructions: instructions,
      checklist: checklist,
      expectedDuration: expectedDuration,
      config: config,
    );
  }

  /// Create notification action.
  factory RunbookAction.notification({
    required String channel,
    required String template,
    List<String>? recipients,
    Map<String, dynamic> config = const {},
  }) {
    return RunbookAction(
      type: RunbookStepType.notification,
      channel: channel,
      template: template,
      recipients: recipients,
      config: config,
    );
  }

  /// Create script action.
  factory RunbookAction.script({
    required String script,
    String? interpreter,
    Map<String, String> inputMapping = const {},
    Map<String, String> outputMapping = const {},
    Map<String, dynamic> config = const {},
  }) {
    return RunbookAction(
      type: RunbookStepType.script,
      script: script,
      interpreter: interpreter,
      inputMapping: inputMapping,
      outputMapping: outputMapping,
      config: config,
    );
  }
}

/// Runbook variable.
class RunbookVariable {
  /// Variable name.
  final String name;

  /// Variable description.
  final String description;

  /// Variable type.
  final RunbookVariableType type;

  /// Whether variable is required.
  final bool required;

  /// Default value.
  final dynamic defaultValue;

  /// Validation pattern (for string variables).
  final String? pattern;

  /// Allowed values (for enum variables).
  final List<dynamic>? allowedValues;

  const RunbookVariable({
    required this.name,
    this.description = '',
    this.type = RunbookVariableType.string,
    this.required = false,
    this.defaultValue,
    this.pattern,
    this.allowedValues,
  });
}

// ═══════════════════════════════════════════════════════════════════
// Runbook Execution Tracking (spec §4)
// ═══════════════════════════════════════════════════════════════════

/// Runbook execution status.
enum RunbookExecutionStatus {
  /// Execution is pending.
  pending,

  /// Execution is running.
  running,

  /// Waiting for approval step.
  waitingApproval,

  /// Waiting for manual step completion.
  waitingManual,

  /// Execution completed successfully.
  completed,

  /// Execution failed.
  failed,

  /// Execution was cancelled.
  cancelled,

  /// Execution was rolled back.
  rolledBack,
}

/// Step execution status.
enum StepExecutionStatus {
  /// Step is pending.
  pending,

  /// Step is running.
  running,

  /// Step is waiting (for condition, approval, or manual).
  waiting,

  /// Step completed successfully.
  completed,

  /// Step was skipped.
  skipped,

  /// Step failed.
  failed,
}

/// Tracks the runtime state of a runbook execution.
class RunbookExecution {
  /// Unique execution identifier.
  final String id;

  /// Runbook being executed.
  final String runbookId;

  /// Version of the runbook.
  final String runbookVersion;

  /// Current execution status.
  final RunbookExecutionStatus status;

  /// When execution started.
  final DateTime startedAt;

  /// When execution completed (if finished).
  final DateTime? completedAt;

  /// Step execution tracking.
  final List<StepExecution> steps;

  /// Resolved variables for this execution.
  final Map<String, dynamic> variables;

  /// How this execution was triggered.
  final TriggerInfo triggeredBy;

  /// Approval records collected during execution.
  final List<RunbookApprovalRecord> approvals;

  /// Final result (when completed).
  final Map<String, dynamic>? result;

  /// Error details (when failed).
  final RunbookExecutionError? error;

  const RunbookExecution({
    required this.id,
    required this.runbookId,
    required this.runbookVersion,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.steps = const [],
    this.variables = const {},
    required this.triggeredBy,
    this.approvals = const [],
    this.result,
    this.error,
  });

  /// Create a copy with updated fields.
  RunbookExecution copyWith({
    RunbookExecutionStatus? status,
    DateTime? completedAt,
    List<StepExecution>? steps,
    Map<String, dynamic>? variables,
    List<RunbookApprovalRecord>? approvals,
    Map<String, dynamic>? result,
    RunbookExecutionError? error,
  }) {
    return RunbookExecution(
      id: id,
      runbookId: runbookId,
      runbookVersion: runbookVersion,
      status: status ?? this.status,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      steps: steps ?? this.steps,
      variables: variables ?? this.variables,
      triggeredBy: triggeredBy,
      approvals: approvals ?? this.approvals,
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }
}

/// Tracks individual step execution state.
class StepExecution {
  /// Step identifier.
  final String stepId;

  /// Current step status.
  final StepExecutionStatus status;

  /// When step started.
  final DateTime? startedAt;

  /// When step completed.
  final DateTime? completedAt;

  /// Step execution duration.
  final Duration? duration;

  /// Input data for the step.
  final Map<String, dynamic>? input;

  /// Output data from the step.
  final Map<String, dynamic>? output;

  /// Error message if failed.
  final String? error;

  /// Pre-check results.
  final List<CheckResult>? preCheckResults;

  /// Post-check results.
  final List<CheckResult>? postCheckResults;

  const StepExecution({
    required this.stepId,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.duration,
    this.input,
    this.output,
    this.error,
    this.preCheckResults,
    this.postCheckResults,
  });
}

/// Result of a step pre/post check.
class CheckResult {
  /// Check name.
  final String name;

  /// Whether the check passed.
  final bool passed;

  /// Check message.
  final String? message;

  const CheckResult({
    required this.name,
    required this.passed,
    this.message,
  });
}

/// Trigger definition for a runbook.
///
/// Defines what can automatically initiate a runbook execution.
class RunbookTrigger {
  /// Trigger type: schedule, event, alert, manual.
  final String type;

  /// Trigger-specific configuration (e.g. cron expression, event filter).
  final Map<String, dynamic> config;

  /// Whether this trigger is enabled.
  final bool enabled;

  /// Optional description of the trigger.
  final String? description;

  const RunbookTrigger({
    required this.type,
    this.config = const {},
    this.enabled = true,
    this.description,
  });

  /// Create a schedule-based trigger.
  factory RunbookTrigger.schedule(String cron, {String? description}) {
    return RunbookTrigger(
      type: 'schedule',
      config: {'cron': cron},
      description: description,
    );
  }

  /// Create an event-based trigger.
  factory RunbookTrigger.event(String eventType, {Map<String, dynamic>? filter, String? description}) {
    return RunbookTrigger(
      type: 'event',
      config: {
        'eventType': eventType,
        if (filter != null) 'filter': filter,
      },
      description: description,
    );
  }

  /// Create an alert-based trigger.
  factory RunbookTrigger.alert(String alertName, {String? severity, String? description}) {
    return RunbookTrigger(
      type: 'alert',
      config: {
        'alertName': alertName,
        if (severity != null) 'severity': severity,
      },
      description: description,
    );
  }
}

/// Information about what triggered a runbook execution.
class TriggerInfo {
  /// Trigger type: schedule, event, alert, manual.
  final String type;

  /// Trigger source identifier.
  final String? source;

  /// Who or what initiated the trigger.
  final String? initiator;

  /// Timestamp of the trigger.
  final DateTime triggeredAt;

  const TriggerInfo({
    required this.type,
    this.source,
    this.initiator,
    required this.triggeredAt,
  });
}

/// Approval record for approval steps.
class RunbookApprovalRecord {
  /// Step that required approval.
  final String stepId;

  /// Approver identity.
  final String approver;

  /// Whether approved or rejected.
  final bool approved;

  /// Reason for decision.
  final String? reason;

  /// When the decision was made.
  final DateTime decidedAt;

  const RunbookApprovalRecord({
    required this.stepId,
    required this.approver,
    required this.approved,
    this.reason,
    required this.decidedAt,
  });
}

/// Execution error details.
class RunbookExecutionError {
  /// Step where error occurred.
  final String stepId;

  /// Error code.
  final String code;

  /// Error message.
  final String message;

  /// Whether the error is recoverable.
  final bool recoverable;

  /// Suggested action.
  final String? suggestedAction;

  const RunbookExecutionError({
    required this.stepId,
    required this.code,
    required this.message,
    this.recoverable = false,
    this.suggestedAction,
  });
}
