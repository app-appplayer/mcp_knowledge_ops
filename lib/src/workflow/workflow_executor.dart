/// Workflow Executor - Executes workflow state machines.
///
/// Provides workflow execution with state management, transitions,
/// timeouts, and cancellation.
library;

import 'workflow.dart';

/// Executes workflows.
class WorkflowExecutor {
  /// Action handler registry.
  final WorkflowActionHandlerRegistry _handlers;

  /// Event listener.
  final WorkflowEventListener? _listener;

  /// Active executions.
  final Map<String, WorkflowExecution> _executions = {};

  WorkflowExecutor({
    required WorkflowActionHandlerRegistry handlers,
    WorkflowEventListener? listener,
  })  : _handlers = handlers,
        _listener = listener;

  /// Start a new workflow execution.
  Future<WorkflowExecution> start<T extends WorkflowContext>(
    Workflow<T> workflow,
    Map<String, dynamic> initialData,
  ) async {
    final context = workflow.createContext(initialData);

    final execution = WorkflowExecution(
      workflow: workflow,
      context: context,
      status: WorkflowStatus.running,
      startedAt: DateTime.now(),
    );

    _executions[context.executionId] = execution;

    _emitEvent(WorkflowStartedEvent(
      executionId: context.executionId,
      workflowId: workflow.id,
      timestamp: DateTime.now(),
    ));

    // Enter initial state
    await _enterState(workflow, context, workflow.initialState);

    return execution;
  }

  /// Send event to workflow.
  Future<void> sendEvent(
    String executionId,
    String event, {
    Map<String, dynamic>? payload,
  }) async {
    final execution = _executions[executionId];
    if (execution == null) {
      throw WorkflowException(
        code: 'EXECUTION_NOT_FOUND',
        message: 'Execution not found: $executionId',
      );
    }

    if (execution.status != WorkflowStatus.running) {
      throw WorkflowException(
        code: 'WORKFLOW_NOT_RUNNING',
        message: 'Workflow is not running: ${execution.status}',
      );
    }

    final workflow = execution.workflow;
    final context = execution.context;

    // Update context with payload
    if (payload != null) {
      context.updateData(payload);
    }

    // Find matching transition
    final transition = _findTransition(workflow, context.currentState, event);
    if (transition == null) {
      _emitEvent(WorkflowEventIgnoredEvent(
        executionId: executionId,
        workflowId: workflow.id,
        event: event,
        currentState: context.currentState,
        timestamp: DateTime.now(),
      ));
      return;
    }

    // Check guard condition
    if (transition.guard != null && !_evaluateGuard(transition.guard!, context)) {
      _emitEvent(WorkflowTransitionGuardedEvent(
        executionId: executionId,
        workflowId: workflow.id,
        transitionId: transition.id,
        guard: transition.guard!,
        timestamp: DateTime.now(),
      ));
      return;
    }

    // Execute transition
    await _executeTransition(workflow, context, transition);
  }

  /// Cancel a workflow execution.
  Future<void> cancel(String executionId, {String? reason}) async {
    final execution = _executions[executionId];
    if (execution == null) return;

    final workflow = execution.workflow;
    final context = execution.context;

    // Execute compensation actions
    await _executeCompensation(workflow, context);

    // Find cancelled state
    final cancelledState = workflow.states.where((s) => s.type == StateType.cancelled).firstOrNull;

    if (cancelledState != null) {
      await _enterState(workflow, context, cancelledState);
    }

    execution.status = WorkflowStatus.cancelled;
    execution.completedAt = DateTime.now();

    context.addHistoryEntry(WorkflowHistoryEntry(
      type: HistoryEntryType.cancelled,
      timestamp: DateTime.now(),
      metadata: {'reason': reason},
    ));

    _emitEvent(WorkflowCancelledEvent(
      executionId: executionId,
      workflowId: workflow.id,
      reason: reason,
      timestamp: DateTime.now(),
    ));
  }

  /// Get execution by ID.
  WorkflowExecution? getExecution(String executionId) {
    return _executions[executionId];
  }

  /// List active executions.
  List<WorkflowExecution> listActiveExecutions() {
    return _executions.values
        .where((e) => e.status == WorkflowStatus.running)
        .toList();
  }

  Future<void> _enterState(
    Workflow workflow,
    WorkflowContext context,
    WorkflowState state,
  ) async {
    final previousState = context.currentState;
    context.transitionTo(state.id);

    context.addHistoryEntry(WorkflowHistoryEntry(
      type: HistoryEntryType.stateEntered,
      fromState: previousState,
      toState: state.id,
      timestamp: DateTime.now(),
    ));

    _emitEvent(WorkflowStateEnteredEvent(
      executionId: context.executionId,
      workflowId: context.workflowId,
      stateId: state.id,
      timestamp: DateTime.now(),
    ));

    // Execute entry actions
    for (final action in state.entryActions) {
      await _executeAction(action, context);
    }

    // Check if terminal state
    if (state.isTerminal) {
      await _completeWorkflow(workflow, context, state);
    }

    // Start timeout if configured
    if (state.timeout != null) {
      _startTimeout(context.executionId, state);
    }
  }

  Future<void> _exitState(
    Workflow workflow,
    WorkflowContext context,
    WorkflowState state,
  ) async {
    // Execute exit actions
    for (final action in state.exitActions) {
      await _executeAction(action, context);
    }

    context.addHistoryEntry(WorkflowHistoryEntry(
      type: HistoryEntryType.stateExited,
      fromState: state.id,
      timestamp: DateTime.now(),
    ));

    _emitEvent(WorkflowStateExitedEvent(
      executionId: context.executionId,
      workflowId: context.workflowId,
      stateId: state.id,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _executeTransition(
    Workflow workflow,
    WorkflowContext context,
    WorkflowTransition transition,
  ) async {
    final fromState = workflow.states.where((s) => s.id == transition.fromState).first;
    final toState = workflow.states.where((s) => s.id == transition.toState).first;

    // Exit current state
    await _exitState(workflow, context, fromState);

    // Execute transition actions
    for (final action in transition.actions) {
      await _executeAction(action, context);
    }

    context.addHistoryEntry(WorkflowHistoryEntry(
      type: HistoryEntryType.transition,
      fromState: transition.fromState,
      toState: transition.toState,
      event: transition.event,
      timestamp: DateTime.now(),
    ));

    _emitEvent(WorkflowTransitionEvent(
      executionId: context.executionId,
      workflowId: context.workflowId,
      transitionId: transition.id,
      fromState: transition.fromState,
      toState: transition.toState,
      timestamp: DateTime.now(),
    ));

    // Enter new state
    await _enterState(workflow, context, toState);
  }

  Future<void> _executeAction(
    WorkflowAction action,
    WorkflowContext context,
  ) async {
    final handler = _handlers.get(action.handler);
    if (handler == null) {
      throw WorkflowException(
        code: 'HANDLER_NOT_FOUND',
        message: 'Handler not found: ${action.handler}',
      );
    }

    final actionContext = ActionExecutionContext(
      executionId: context.executionId,
      workflowId: context.workflowId,
      stateId: context.currentState,
      actionId: action.id,
      parameters: action.parameters,
      data: context.data,
    );

    try {
      final result = await handler.execute(actionContext);
      if (result.updates != null) {
        context.updateData(result.updates!);
      }

      context.addHistoryEntry(WorkflowHistoryEntry(
        type: HistoryEntryType.actionExecuted,
        timestamp: DateTime.now(),
        metadata: {
          'actionId': action.id,
          'handler': action.handler,
          'success': true,
        },
      ));
    } catch (e) {
      context.addHistoryEntry(WorkflowHistoryEntry(
        type: HistoryEntryType.error,
        timestamp: DateTime.now(),
        metadata: {
          'actionId': action.id,
          'handler': action.handler,
          'error': e.toString(),
        },
      ));

      // Retry if configured
      if (action.retryConfig != null) {
        // Retry logic would go here
      }

      rethrow;
    }
  }

  Future<void> _completeWorkflow(
    Workflow workflow,
    WorkflowContext context,
    WorkflowState terminalState,
  ) async {
    final execution = _executions[context.executionId];
    if (execution == null) return;

    execution.completedAt = DateTime.now();

    switch (terminalState.type) {
      case StateType.completed:
        execution.status = WorkflowStatus.completed;
        context.addHistoryEntry(WorkflowHistoryEntry(
          type: HistoryEntryType.completed,
          timestamp: DateTime.now(),
        ));
        _emitEvent(WorkflowCompletedEvent(
          executionId: context.executionId,
          workflowId: workflow.id,
          timestamp: DateTime.now(),
        ));
        break;

      case StateType.failed:
        execution.status = WorkflowStatus.failed;
        context.addHistoryEntry(WorkflowHistoryEntry(
          type: HistoryEntryType.failed,
          timestamp: DateTime.now(),
        ));
        _emitEvent(WorkflowFailedEvent(
          executionId: context.executionId,
          workflowId: workflow.id,
          timestamp: DateTime.now(),
        ));
        break;

      case StateType.cancelled:
        execution.status = WorkflowStatus.cancelled;
        context.addHistoryEntry(WorkflowHistoryEntry(
          type: HistoryEntryType.cancelled,
          timestamp: DateTime.now(),
        ));
        break;

      default:
        break;
    }
  }

  Future<void> _executeCompensation(
    Workflow workflow,
    WorkflowContext context,
  ) async {
    // Execute compensation actions for completed states in reverse order
    final completedStates = context.history
        .where((h) => h.type == HistoryEntryType.stateExited)
        .map((h) => h.fromState)
        .whereType<String>()
        .toList()
        .reversed;

    for (final stateId in completedStates) {
      final state = workflow.states.where((s) => s.id == stateId).firstOrNull;
      if (state == null) continue;

      // Find compensation actions
      final compensations = state.exitActions
          .where((a) => a.type == ActionType.compensate);

      for (final action in compensations) {
        try {
          await _executeAction(action, context);
        } catch (e) {
          // Log but continue with other compensations
        }
      }
    }
  }

  WorkflowTransition? _findTransition(
    Workflow workflow,
    String currentState,
    String event,
  ) {
    final transitions = workflow.transitions
        .where((t) => t.fromState == currentState && t.event == event)
        .toList();

    if (transitions.isEmpty) return null;

    // Sort by priority (highest first)
    transitions.sort((a, b) => b.priority.compareTo(a.priority));
    return transitions.first;
  }

  bool _evaluateGuard(String guard, WorkflowContext context) {
    // Simple guard evaluation
    final trimmed = guard.trim();

    if (trimmed == 'true') return true;
    if (trimmed == 'false') return false;

    // Check for data variable existence
    if (trimmed.startsWith('!')) {
      final varName = trimmed.substring(1).trim();
      return context.data[varName] == null;
    }

    // Check for data variable truthy
    final value = context.data[trimmed];
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.isNotEmpty;
    if (value is num) return value != 0;
    return true;
  }

  void _startTimeout(String executionId, WorkflowState state) {
    // Timeout handling would be implemented here
    // Using a timer to trigger timeout action
  }

  void _emitEvent(WorkflowEvent event) {
    _listener?.onEvent(event);
  }
}

/// Workflow execution.
class WorkflowExecution {
  /// Workflow definition.
  final Workflow workflow;

  /// Execution context.
  final WorkflowContext context;

  /// Execution status.
  WorkflowStatus status;

  /// Started at.
  final DateTime startedAt;

  /// Completed at.
  DateTime? completedAt;

  WorkflowExecution({
    required this.workflow,
    required this.context,
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

  /// Waiting for input.
  waiting,

  /// Successfully completed.
  completed,

  /// Failed.
  failed,

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
