/// Workflow Executor - Deprecated state-machine workflow executor.
///
/// **Deprecated**: Use [ExecutionEngine.executeWorkflow] instead.
/// ExecutionEngine provides sequential stage-based workflow execution
/// with gates, checkpoints, and approvals — which is the optimal model
/// for linear build/release workflows.
library;

/// Executes workflows using a state-machine model.
///
/// **Deprecated**: Use [ExecutionEngine.executeWorkflow] instead.
@Deprecated('Use ExecutionEngine.executeWorkflow() instead')
class WorkflowExecutor {
  WorkflowExecutor({
    required WorkflowActionHandlerRegistry handlers,
    WorkflowEventListener? listener,
  });

  /// Start a new workflow execution.
  @Deprecated('Use ExecutionEngine.executeWorkflow() instead')
  Future<WorkflowExecution> start(
    dynamic workflow,
    Map<String, dynamic> initialData,
  ) async {
    throw UnimplementedError(
      'WorkflowExecutor is deprecated. Use ExecutionEngine.executeWorkflow() instead.',
    );
  }

  /// Send event to workflow.
  @Deprecated('Use ExecutionEngine.executeWorkflow() instead')
  Future<void> sendEvent(
    String executionId,
    String event, {
    Map<String, dynamic>? payload,
  }) async {
    throw UnimplementedError(
      'WorkflowExecutor is deprecated. Use ExecutionEngine.executeWorkflow() instead.',
    );
  }

  /// Cancel a workflow execution.
  @Deprecated('Use ExecutionEngine.executeWorkflow() instead')
  Future<void> cancel(String executionId, {String? reason}) async {
    throw UnimplementedError(
      'WorkflowExecutor is deprecated. Use ExecutionEngine.executeWorkflow() instead.',
    );
  }

  /// Get execution by ID.
  WorkflowExecution? getExecution(String executionId) => null;

  /// List active executions.
  List<WorkflowExecution> listActiveExecutions() => [];
}

/// Workflow execution.
class WorkflowExecution {
  /// Workflow definition (dynamic for backward compatibility).
  final dynamic workflow;

  /// Execution status.
  WorkflowStatus status;

  /// Started at.
  final DateTime startedAt;

  /// Completed at.
  DateTime? completedAt;

  WorkflowExecution({
    required this.workflow,
    required this.status,
    required this.startedAt,
    this.completedAt,
  });

  /// Execution duration.
  Duration? get duration =>
      completedAt != null ? completedAt!.difference(startedAt) : null;
}

/// Workflow status.
enum WorkflowStatus {
  /// Not started.
  pending,

  /// Currently running.
  running,

  /// Successfully completed.
  completed,

  /// Failed.
  failed,

  /// Paused (awaiting resume).
  paused,

  /// Cancelled.
  cancelled,
}

/// Workflow exception.
class WorkflowException implements Exception {
  final String code;
  final String message;
  final Object? cause;

  WorkflowException({
    required this.code,
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'WorkflowException($code): $message';
}

/// Action handler registry.
class WorkflowActionHandlerRegistry {
  final Map<String, WorkflowActionHandler> _handlers = {};

  /// Register a handler.
  void register(WorkflowActionHandler handler) {
    _handlers[handler.id] = handler;
  }

  /// Get handler by ID.
  WorkflowActionHandler? get(String handlerId) {
    return _handlers[handlerId];
  }

  /// Check if handler exists.
  bool has(String handlerId) {
    return _handlers.containsKey(handlerId);
  }
}

/// Action handler interface.
abstract class WorkflowActionHandler {
  /// Handler identifier.
  String get id;

  /// Execute the action.
  Future<ActionResult> execute(ActionExecutionContext context);
}

/// Action execution context.
class ActionExecutionContext {
  final String executionId;
  final String workflowId;
  final String stateId;
  final String actionId;
  final Map<String, dynamic> parameters;
  final Map<String, dynamic> data;

  const ActionExecutionContext({
    required this.executionId,
    required this.workflowId,
    required this.stateId,
    required this.actionId,
    required this.parameters,
    required this.data,
  });
}

/// Action execution result.
class ActionResult {
  /// Whether action succeeded.
  final bool success;

  /// Context updates.
  final Map<String, dynamic>? updates;

  /// Error message.
  final String? error;

  const ActionResult({
    required this.success,
    this.updates,
    this.error,
  });

  factory ActionResult.ok({Map<String, dynamic>? updates}) {
    return ActionResult(success: true, updates: updates);
  }

  factory ActionResult.fail(String error) {
    return ActionResult(success: false, error: error);
  }
}

/// Workflow event listener.
abstract class WorkflowEventListener {
  void onEvent(WorkflowEvent event);
}

/// Base workflow event.
abstract class WorkflowEvent {
  String get type;
  String get executionId;
  String get workflowId;
  DateTime get timestamp;
}

/// Workflow started event.
class WorkflowStartedEvent implements WorkflowEvent {
  @override
  final String type = 'workflow_started';
  @override
  final String executionId;
  @override
  final String workflowId;
  @override
  final DateTime timestamp;

  const WorkflowStartedEvent({
    required this.executionId,
    required this.workflowId,
    required this.timestamp,
  });
}

/// State entered event.
class WorkflowStateEnteredEvent implements WorkflowEvent {
  @override
  final String type = 'state_entered';
  @override
  final String executionId;
  @override
  final String workflowId;
  final String stateId;
  @override
  final DateTime timestamp;

  const WorkflowStateEnteredEvent({
    required this.executionId,
    required this.workflowId,
    required this.stateId,
    required this.timestamp,
  });
}

/// State exited event.
class WorkflowStateExitedEvent implements WorkflowEvent {
  @override
  final String type = 'state_exited';
  @override
  final String executionId;
  @override
  final String workflowId;
  final String stateId;
  @override
  final DateTime timestamp;

  const WorkflowStateExitedEvent({
    required this.executionId,
    required this.workflowId,
    required this.stateId,
    required this.timestamp,
  });
}

/// Transition event.
class WorkflowTransitionEvent implements WorkflowEvent {
  @override
  final String type = 'transition';
  @override
  final String executionId;
  @override
  final String workflowId;
  final String transitionId;
  final String fromState;
  final String toState;
  @override
  final DateTime timestamp;

  const WorkflowTransitionEvent({
    required this.executionId,
    required this.workflowId,
    required this.transitionId,
    required this.fromState,
    required this.toState,
    required this.timestamp,
  });
}

/// Event ignored event.
class WorkflowEventIgnoredEvent implements WorkflowEvent {
  @override
  final String type = 'event_ignored';
  @override
  final String executionId;
  @override
  final String workflowId;
  final String event;
  final String currentState;
  @override
  final DateTime timestamp;

  const WorkflowEventIgnoredEvent({
    required this.executionId,
    required this.workflowId,
    required this.event,
    required this.currentState,
    required this.timestamp,
  });
}

/// Transition guarded event.
class WorkflowTransitionGuardedEvent implements WorkflowEvent {
  @override
  final String type = 'transition_guarded';
  @override
  final String executionId;
  @override
  final String workflowId;
  final String transitionId;
  final String guard;
  @override
  final DateTime timestamp;

  const WorkflowTransitionGuardedEvent({
    required this.executionId,
    required this.workflowId,
    required this.transitionId,
    required this.guard,
    required this.timestamp,
  });
}

/// Workflow completed event.
class WorkflowCompletedEvent implements WorkflowEvent {
  @override
  final String type = 'workflow_completed';
  @override
  final String executionId;
  @override
  final String workflowId;
  @override
  final DateTime timestamp;

  const WorkflowCompletedEvent({
    required this.executionId,
    required this.workflowId,
    required this.timestamp,
  });
}

/// Workflow failed event.
class WorkflowFailedEvent implements WorkflowEvent {
  @override
  final String type = 'workflow_failed';
  @override
  final String executionId;
  @override
  final String workflowId;
  @override
  final DateTime timestamp;

  const WorkflowFailedEvent({
    required this.executionId,
    required this.workflowId,
    required this.timestamp,
  });
}

/// Workflow cancelled event.
class WorkflowCancelledEvent implements WorkflowEvent {
  @override
  final String type = 'workflow_cancelled';
  @override
  final String executionId;
  @override
  final String workflowId;
  final String? reason;
  @override
  final DateTime timestamp;

  const WorkflowCancelledEvent({
    required this.executionId,
    required this.workflowId,
    this.reason,
    required this.timestamp,
  });
}
