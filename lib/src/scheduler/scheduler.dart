/// Scheduler - Trigger management for pipelines and workflows.
///
/// Provides scheduling infrastructure with cron, event, and deadline triggers.
library;

/// Scheduler for managing pipeline triggers.
class Scheduler {
  /// Registered triggers.
  final Map<String, ScheduledTask> _tasks = {};

  /// Event subscriptions.
  final Map<String, List<String>> _eventSubscriptions = {};

  /// Whether scheduler is running.
  bool _running = false;

  /// Start the scheduler.
  void start() {
    _running = true;
    _startCronChecks();
  }

  /// Stop the scheduler.
  void stop() {
    _running = false;
  }

  /// Check if scheduler is running.
  bool get isRunning => _running;

  /// Register a scheduled task.
  void register({
    required String taskId,
    required Trigger trigger,
    required ScheduledAction action,
    bool enabled = true,
  }) {
    _tasks[taskId] = ScheduledTask(
      taskId: taskId,
      trigger: trigger,
      action: action,
      enabled: enabled,
      registeredAt: DateTime.now(),
    );

    // Register event subscriptions
    if (trigger is EventTrigger) {
      _eventSubscriptions
          .putIfAbsent(trigger.eventType, () => [])
          .add(taskId);
    }
  }

  /// Unregister a task.
  void unregister(String taskId) {
    final task = _tasks.remove(taskId);
    if (task != null && task.trigger is EventTrigger) {
      final eventType = (task.trigger as EventTrigger).eventType;
      _eventSubscriptions[eventType]?.remove(taskId);
    }
  }

  /// Enable a task.
  void enable(String taskId) {
    final task = _tasks[taskId];
    if (task != null) {
      _tasks[taskId] = task.copyWith(enabled: true);
    }
  }

  /// Disable a task.
  void disable(String taskId) {
    final task = _tasks[taskId];
    if (task != null) {
      _tasks[taskId] = task.copyWith(enabled: false);
    }
  }

  /// Get task by ID.
  ScheduledTask? getTask(String taskId) => _tasks[taskId];

  /// List all tasks.
  List<ScheduledTask> listTasks({bool? enabled}) {
    var tasks = _tasks.values;
    if (enabled != null) {
      tasks = tasks.where((t) => t.enabled == enabled);
    }
    return tasks.toList();
  }

  /// Emit an event to trigger subscribed tasks.
  Future<List<TaskExecution>> emitEvent(
    String eventType, {
    Map<String, dynamic>? data,
  }) async {
    if (!_running) return [];

    final taskIds = _eventSubscriptions[eventType] ?? [];
    final executions = <TaskExecution>[];

    for (final taskId in taskIds) {
      final task = _tasks[taskId];
      if (task == null || !task.enabled) continue;

      final execution = await _executeTask(task, data);
      executions.add(execution);
    }

    return executions;
  }

  /// Check and execute deadline-triggered tasks.
  Future<List<TaskExecution>> checkDeadlines({
    required DateTime now,
    required DeadlineProvider deadlineProvider,
  }) async {
    if (!_running) return [];

    final executions = <TaskExecution>[];

    for (final task in _tasks.values) {
      if (!task.enabled) continue;
      if (task.trigger is! DeadlineTrigger) continue;

      final trigger = task.trigger as DeadlineTrigger;
      final deadline = await deadlineProvider.getDeadline(trigger.deadlineId);

      if (deadline == null) continue;

      final triggerTime = deadline.subtract(trigger.beforeDeadline);
      if (now.isAfter(triggerTime) && now.isBefore(deadline)) {
        // Check if not already executed
        if (task.lastExecutedAt == null ||
            task.lastExecutedAt!.isBefore(triggerTime)) {
          final execution = await _executeTask(task, {
            'deadline': deadline.toIso8601String(),
            'deadlineId': trigger.deadlineId,
          });
          executions.add(execution);
        }
      }
    }

    return executions;
  }

  /// Manually trigger a task.
  Future<TaskExecution> triggerManually(
    String taskId, {
    Map<String, dynamic>? data,
  }) async {
    final task = _tasks[taskId];
    if (task == null) {
      return TaskExecution(
        taskId: taskId,
        triggerId: 'manual',
        status: ExecutionStatus.failed,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        error: 'Task not found: $taskId',
      );
    }

    return _executeTask(task, data);
  }

  Future<TaskExecution> _executeTask(
    ScheduledTask task,
    Map<String, dynamic>? data,
  ) async {
    final startTime = DateTime.now();

    try {
      await task.action(data ?? {});

      // Update last execution time
      _tasks[task.taskId] = task.copyWith(lastExecutedAt: DateTime.now());

      return TaskExecution(
        taskId: task.taskId,
        triggerId: task.trigger.id,
        status: ExecutionStatus.completed,
        startedAt: startTime,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      return TaskExecution(
        taskId: task.taskId,
        triggerId: task.trigger.id,
        status: ExecutionStatus.failed,
        startedAt: startTime,
        completedAt: DateTime.now(),
        error: e.toString(),
      );
    }
  }

  void _startCronChecks() {
    _runCronCheckLoop();
  }

  void _runCronCheckLoop() async {
    while (_running) {
      final now = DateTime.now();

      for (final task in _tasks.values) {
        if (!task.enabled) continue;
        if (task.trigger is! CronTrigger) continue;

        final trigger = task.trigger as CronTrigger;
        if (trigger.shouldRunAt(now, task.lastExecutedAt)) {
          await _executeTask(task, {'triggeredAt': now.toIso8601String()});
        }
      }

      // Wait for next minute
      await Future.delayed(const Duration(seconds: 60));
    }
  }
}

/// A scheduled task.
class ScheduledTask {
  /// Task identifier.
  final String taskId;

  /// Trigger configuration.
  final Trigger trigger;

  /// Action to execute.
  final ScheduledAction action;

  /// Whether task is enabled.
  final bool enabled;

  /// When task was registered.
  final DateTime registeredAt;

  /// Last execution time.
  final DateTime? lastExecutedAt;

  const ScheduledTask({
    required this.taskId,
    required this.trigger,
    required this.action,
    required this.enabled,
    required this.registeredAt,
    this.lastExecutedAt,
  });

  ScheduledTask copyWith({
    String? taskId,
    Trigger? trigger,
    ScheduledAction? action,
    bool? enabled,
    DateTime? registeredAt,
    DateTime? lastExecutedAt,
  }) {
    return ScheduledTask(
      taskId: taskId ?? this.taskId,
      trigger: trigger ?? this.trigger,
      action: action ?? this.action,
      enabled: enabled ?? this.enabled,
      registeredAt: registeredAt ?? this.registeredAt,
      lastExecutedAt: lastExecutedAt ?? this.lastExecutedAt,
    );
  }
}

/// Action to execute when triggered.
typedef ScheduledAction = Future<void> Function(Map<String, dynamic> data);

/// Base trigger interface.
abstract class Trigger {
  /// Trigger identifier.
  String get id;

  /// Trigger type.
  TriggerType get type;
}

/// Trigger types.
enum TriggerType {
  /// Time-based cron trigger.
  cron,

  /// Event-driven trigger.
  event,

  /// Deadline-aware trigger.
  deadline,

  /// Manual trigger.
  manual,
}

/// Cron-based trigger.
class CronTrigger implements Trigger {
  @override
  final String id;

  @override
  TriggerType get type => TriggerType.cron;

  /// Cron expression.
  final String expression;

  /// Timezone.
  final String? timezone;

  CronTrigger(
    this.expression, {
    String? id,
    this.timezone,
  }) : id = id ?? 'cron_$expression';

  /// Check if trigger should run at given time.
  bool shouldRunAt(DateTime now, DateTime? lastRun) {
    // Simple cron evaluation for common patterns
    final parts = expression.split(' ');
    if (parts.length < 5) return false;

    // Check minute
    if (parts[0] != '*' && parts[0] != now.minute.toString()) {
      return false;
    }

    // Check hour
    if (parts[1] != '*' && parts[1] != now.hour.toString()) {
      return false;
    }

    // Check day of month
    if (parts[2] != '*' && parts[2] != now.day.toString()) {
      return false;
    }

    // Check month
    if (parts[3] != '*' && parts[3] != now.month.toString()) {
      return false;
    }

    // Check day of week
    if (parts[4] != '*' && parts[4] != now.weekday.toString()) {
      return false;
    }

    // Check if already ran this minute
    if (lastRun != null) {
      if (lastRun.year == now.year &&
          lastRun.month == now.month &&
          lastRun.day == now.day &&
          lastRun.hour == now.hour &&
          lastRun.minute == now.minute) {
        return false;
      }
    }

    return true;
  }
}

/// Event-driven trigger.
class EventTrigger implements Trigger {
  @override
  final String id;

  @override
  TriggerType get type => TriggerType.event;

  /// Event type to listen for.
  final String eventType;

  /// Filter condition.
  final String? filter;

  EventTrigger(
    this.eventType, {
    String? id,
    this.filter,
  }) : id = id ?? 'event_$eventType';
}

/// Deadline-aware trigger.
class DeadlineTrigger implements Trigger {
  @override
  final String id;

  @override
  TriggerType get type => TriggerType.deadline;

  /// Deadline identifier.
  final String deadlineId;

  /// How long before deadline to trigger.
  final Duration beforeDeadline;

  DeadlineTrigger({
    required this.deadlineId,
    required this.beforeDeadline,
    String? id,
  }) : id = id ?? 'deadline_$deadlineId';
}

/// Manual trigger.
class ManualTrigger implements Trigger {
  @override
  final String id;

  @override
  TriggerType get type => TriggerType.manual;

  ManualTrigger({String? id}) : id = id ?? 'manual';
}

/// Provider for deadline information.
abstract class DeadlineProvider {
  /// Get deadline by ID.
  Future<DateTime?> getDeadline(String deadlineId);
}

/// Task execution record.
class TaskExecution {
  /// Task identifier.
  final String taskId;

  /// Trigger that caused execution.
  final String triggerId;

  /// Execution status.
  final ExecutionStatus status;

  /// When execution started.
  final DateTime startedAt;

  /// When execution completed.
  final DateTime? completedAt;

  /// Error message if failed.
  final String? error;

  /// Output data.
  final Map<String, dynamic>? output;

  const TaskExecution({
    required this.taskId,
    required this.triggerId,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.error,
    this.output,
  });

  /// Execution duration.
  Duration? get duration =>
      completedAt != null ? completedAt!.difference(startedAt) : null;

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'triggerId': triggerId,
        'status': status.name,
        'startedAt': startedAt.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (error != null) 'error': error,
        if (output != null) 'output': output,
      };
}

/// Task execution status.
enum ExecutionStatus {
  /// Pending execution.
  pending,

  /// Currently running.
  running,

  /// Completed successfully.
  completed,

  /// Failed.
  failed,

  /// Cancelled.
  cancelled,
}
