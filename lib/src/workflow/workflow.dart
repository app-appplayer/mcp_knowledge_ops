/// Workflow - State machine-based workflow definitions.
///
/// Provides workflow infrastructure with states, transitions, and actions.
library;

/// Base workflow interface.
abstract class Workflow<TContext extends WorkflowContext> {
  /// Workflow identifier.
  String get id;

  /// Workflow name.
  String get name;

  /// Workflow version.
  String get version;

  /// Initial state.
  WorkflowState get initialState;

  /// All workflow states.
  List<WorkflowState> get states;

  /// All workflow transitions.
  List<WorkflowTransition> get transitions;

  /// Create new context for this workflow.
  TContext createContext(Map<String, dynamic> data);

  /// Validate workflow definition.
  List<String> validate();
}

/// Workflow state.
class WorkflowState {
  /// State identifier.
  final String id;

  /// State name.
  final String name;

  /// State type.
  final StateType type;

  /// Actions to execute on entry.
  final List<WorkflowAction> entryActions;

  /// Actions to execute on exit.
  final List<WorkflowAction> exitActions;

  /// Timeout for this state.
  final Duration? timeout;

  /// Timeout action.
  final TimeoutAction? timeoutAction;

  /// State metadata.
  final Map<String, dynamic> metadata;

  const WorkflowState({
    required this.id,
    required this.name,
    this.type = StateType.normal,
    this.entryActions = const [],
    this.exitActions = const [],
    this.timeout,
    this.timeoutAction,
    this.metadata = const {},
  });

  /// Check if this is a terminal state.
  bool get isTerminal =>
      type == StateType.completed ||
      type == StateType.failed ||
      type == StateType.cancelled;
}

/// State types.
enum StateType {
  /// Initial state.
  initial,

  /// Normal processing state.
  normal,

  /// Waiting for input/approval.
  waiting,

  /// Successfully completed.
  completed,

  /// Failed state.
  failed,

  /// Cancelled state.
  cancelled,
}

/// Timeout action types.
enum TimeoutAction {
  /// Automatically reject/fail.
  reject,

  /// Escalate to supervisor.
  escalate,

  /// Cancel the workflow.
  cancel,

  /// Retry the state.
  retry,

  /// Move to default next state.
  advance,
}

/// Workflow transition.
class WorkflowTransition {
  /// Transition identifier.
  final String id;

  /// Source state ID.
  final String fromState;

  /// Target state ID.
  final String toState;

  /// Event that triggers this transition.
  final String event;

  /// Guard condition (expression).
  final String? guard;

  /// Actions to execute during transition.
  final List<WorkflowAction> actions;

  /// Priority (higher = checked first).
  final int priority;

  const WorkflowTransition({
    required this.id,
    required this.fromState,
    required this.toState,
    required this.event,
    this.guard,
    this.actions = const [],
    this.priority = 0,
  });
}

/// Workflow action.
class WorkflowAction {
  /// Action identifier.
  final String id;

  /// Action type.
  final ActionType type;

  /// Handler reference.
  final String handler;

  /// Action parameters.
  final Map<String, dynamic> parameters;

  /// Whether action is async.
  final bool async;

  /// Retry configuration.
  final RetryConfiguration? retryConfig;

  const WorkflowAction({
    required this.id,
    required this.type,
    required this.handler,
    this.parameters = const {},
    this.async = false,
    this.retryConfig,
  });
}

/// Action types.
enum ActionType {
  /// Execute a handler.
  execute,

  /// Send notification.
  notify,

  /// Update context.
  updateContext,

  /// Log event.
  log,

  /// Emit event.
  emit,

  /// Call external service.
  callService,

  /// Execute compensation.
  compensate,
}

/// Retry configuration.
class RetryConfiguration {
  /// Maximum attempts.
  final int maxAttempts;

  /// Delay between retries.
  final Duration delay;

  /// Backoff multiplier.
  final double backoff;

  const RetryConfiguration({
    this.maxAttempts = 3,
    this.delay = const Duration(seconds: 1),
    this.backoff = 2.0,
  });
}

/// Workflow context.
abstract class WorkflowContext {
  /// Unique execution ID.
  String get executionId;

  /// Workflow ID.
  String get workflowId;

  /// Current state ID.
  String get currentState;

  /// Workflow data.
  Map<String, dynamic> get data;

  /// Execution history.
  List<WorkflowHistoryEntry> get history;

  /// Created at.
  DateTime get createdAt;

  /// Updated at.
  DateTime get updatedAt;

  /// Update current state.
  void transitionTo(String stateId);

  /// Update data.
  void updateData(Map<String, dynamic> updates);

  /// Add history entry.
  void addHistoryEntry(WorkflowHistoryEntry entry);
}

/// Workflow history entry.
class WorkflowHistoryEntry {
  /// Entry type.
  final HistoryEntryType type;

  /// From state.
  final String? fromState;

  /// To state.
  final String? toState;

  /// Event that triggered.
  final String? event;

  /// Entry timestamp.
  final DateTime timestamp;

  /// Entry metadata.
  final Map<String, dynamic> metadata;

  const WorkflowHistoryEntry({
    required this.type,
    this.fromState,
    this.toState,
    this.event,
    required this.timestamp,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (fromState != null) 'fromState': fromState,
        if (toState != null) 'toState': toState,
        if (event != null) 'event': event,
        'timestamp': timestamp.toIso8601String(),
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}

/// History entry types.
enum HistoryEntryType {
  /// Workflow started.
  started,

  /// State entered.
  stateEntered,

  /// State exited.
  stateExited,

  /// Transition occurred.
  transition,

  /// Action executed.
  actionExecuted,

  /// Error occurred.
  error,

  /// Workflow completed.
  completed,

  /// Workflow failed.
  failed,

  /// Workflow cancelled.
  cancelled,
}

/// Basic workflow context implementation.
class BasicWorkflowContext implements WorkflowContext {
  @override
  final String executionId;

  @override
  final String workflowId;

  @override
  String currentState;

  @override
  final Map<String, dynamic> data;

  @override
  final List<WorkflowHistoryEntry> history;

  @override
  final DateTime createdAt;

  @override
  DateTime updatedAt;

  BasicWorkflowContext({
    required this.executionId,
    required this.workflowId,
    required this.currentState,
    Map<String, dynamic>? data,
    List<WorkflowHistoryEntry>? history,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : data = data ?? {},
        history = history ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  @override
  void transitionTo(String stateId) {
    currentState = stateId;
    updatedAt = DateTime.now();
  }

  @override
  void updateData(Map<String, dynamic> updates) {
    data.addAll(updates);
    updatedAt = DateTime.now();
  }

  @override
  void addHistoryEntry(WorkflowHistoryEntry entry) {
    history.add(entry);
    updatedAt = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'executionId': executionId,
        'workflowId': workflowId,
        'currentState': currentState,
        'data': data,
        'history': history.map((h) => h.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory BasicWorkflowContext.fromJson(Map<String, dynamic> json) {
    return BasicWorkflowContext(
      executionId: json['executionId'] as String,
      workflowId: json['workflowId'] as String,
      currentState: json['currentState'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
