/// Scheduler - Trigger management for pipelines and workflows.
///
/// Provides scheduling infrastructure with cron, event, deadline, and
/// composite triggers. Supports priority-based execution queuing,
/// concurrency control, task deduplication, and pause/resume.
library;

// ═══════════════════════════════════════════════════════════════════
// Configuration
// ═══════════════════════════════════════════════════════════════════

/// Configuration for a scheduled task.
class ScheduleConfig {
  /// Whether the schedule is enabled.
  final bool enabled;

  /// Execution priority (1-10, higher = more urgent, default 5).
  final int priority;

  /// Maximum concurrent executions for this schedule.
  final int maxConcurrent;

  /// Whether to deduplicate executions within a time window.
  final bool deduplicate;

  /// Time window for deduplication (skips if executed within window).
  final Duration? dedupeWindow;

  /// Execution timeout.
  final Duration? timeout;

  /// Whether to retry on failure.
  final bool retryOnFailure;

  /// Retry configuration for failed executions.
  final ScheduleRetryConfig? retryConfig;

  /// Tags for categorization and filtering.
  final List<String> tags;

  /// Additional metadata.
  final Map<String, dynamic> metadata;

  const ScheduleConfig({
    this.enabled = true,
    this.priority = 5,
    this.maxConcurrent = 1,
    this.deduplicate = false,
    this.dedupeWindow,
    this.timeout,
    this.retryOnFailure = false,
    this.retryConfig,
    this.tags = const [],
    this.metadata = const {},
  });

  /// Copy with modifications.
  ScheduleConfig copyWith({
    bool? enabled,
    int? priority,
    int? maxConcurrent,
    bool? deduplicate,
    Duration? dedupeWindow,
    Duration? timeout,
    bool? retryOnFailure,
    ScheduleRetryConfig? retryConfig,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    return ScheduleConfig(
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
      deduplicate: deduplicate ?? this.deduplicate,
      dedupeWindow: dedupeWindow ?? this.dedupeWindow,
      timeout: timeout ?? this.timeout,
      retryOnFailure: retryOnFailure ?? this.retryOnFailure,
      retryConfig: retryConfig ?? this.retryConfig,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'priority': priority,
        'maxConcurrent': maxConcurrent,
        'deduplicate': deduplicate,
        if (dedupeWindow != null)
          'dedupeWindowMs': dedupeWindow!.inMilliseconds,
        if (timeout != null) 'timeoutMs': timeout!.inMilliseconds,
        'retryOnFailure': retryOnFailure,
        if (tags.isNotEmpty) 'tags': tags,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}

// ═══════════════════════════════════════════════════════════════════
// Schedule Status
// ═══════════════════════════════════════════════════════════════════

/// Status of a schedule.
enum ScheduleStatus {
  /// Schedule is active and will trigger normally.
  active,

  /// Schedule is paused (temporarily suspended).
  paused,

  /// Schedule is disabled (will not trigger).
  disabled,

  /// Schedule has been permanently deleted.
  deleted,
}

// ═══════════════════════════════════════════════════════════════════
// Execution Target
// ═══════════════════════════════════════════════════════════════════

/// Target type for scheduled executions.
enum TargetType {
  /// Pipeline execution target.
  pipeline,

  /// Workflow execution target.
  workflow,

  /// Runbook execution target.
  runbook,
}

/// Execution target definition.
class ExecutionTarget {
  /// Target type.
  final TargetType type;

  /// Target identifier.
  final String id;

  /// Input data for execution.
  final Map<String, dynamic>? input;

  /// Configuration overrides.
  final Map<String, dynamic>? config;

  const ExecutionTarget({
    required this.type,
    required this.id,
    this.input,
    this.config,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        if (input != null) 'input': input,
        if (config != null) 'config': config,
      };
}

// ═══════════════════════════════════════════════════════════════════
// Pending Execution
// ═══════════════════════════════════════════════════════════════════

/// A pending execution waiting in the queue.
class PendingExecution {
  /// Unique execution ID.
  final String id;

  /// Associated schedule ID.
  final String scheduleId;

  /// Execution target.
  final ExecutionTarget target;

  /// Execution priority (higher = more urgent).
  final int priority;

  /// When this execution was enqueued.
  final DateTime enqueuedAt;

  /// Earliest time this execution should run.
  final DateTime? executeAfter;

  /// Additional metadata.
  final Map<String, dynamic> metadata;

  const PendingExecution({
    required this.id,
    required this.scheduleId,
    required this.target,
    this.priority = 5,
    required this.enqueuedAt,
    this.executeAfter,
    this.metadata = const {},
  });

  /// Check if execution is ready to run.
  bool isReady(DateTime now) {
    if (executeAfter == null) return true;
    return now.isAfter(executeAfter!) || now.isAtSameMomentAs(executeAfter!);
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'scheduleId': scheduleId,
        'target': target.toJson(),
        'priority': priority,
        'enqueuedAt': enqueuedAt.toIso8601String(),
        if (executeAfter != null)
          'executeAfter': executeAfter!.toIso8601String(),
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}

// ═══════════════════════════════════════════════════════════════════
// Queue Statistics
// ═══════════════════════════════════════════════════════════════════

/// Statistics for the execution queue.
class QueueStats {
  /// Number of pending executions.
  final int pending;

  /// Number of currently running executions.
  final int running;

  /// Number of completed executions.
  final int completed;

  /// Number of failed executions.
  final int failed;

  /// Average wait time in queue.
  final Duration avgWaitTime;

  /// Average execution time.
  final Duration avgExecutionTime;

  /// Throughput (executions per minute).
  final double throughputPerMinute;

  /// Error rate (0.0 to 1.0).
  final double errorRate;

  const QueueStats({
    this.pending = 0,
    this.running = 0,
    this.completed = 0,
    this.failed = 0,
    this.avgWaitTime = Duration.zero,
    this.avgExecutionTime = Duration.zero,
    this.throughputPerMinute = 0.0,
    this.errorRate = 0.0,
  });

  /// Total number of executions tracked.
  int get total => pending + running + completed + failed;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'pending': pending,
        'running': running,
        'completed': completed,
        'failed': failed,
        'avgWaitTimeMs': avgWaitTime.inMilliseconds,
        'avgExecutionTimeMs': avgExecutionTime.inMilliseconds,
        'throughputPerMinute': throughputPerMinute,
        'errorRate': errorRate,
      };
}

// ═══════════════════════════════════════════════════════════════════
// Queue Configuration
// ═══════════════════════════════════════════════════════════════════

/// Dead letter queue configuration for failed executions.
class QueueDlqConfig {
  /// Whether DLQ is enabled.
  final bool enabled;

  /// Maximum retries before sending to DLQ.
  final int maxRetries;

  /// Delay between retries.
  final Duration retryDelay;

  const QueueDlqConfig({
    this.enabled = false,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 30),
  });
}

/// Rate limiting configuration for queue processing.
class QueueRateLimitConfig {
  /// Whether rate limiting is enabled.
  final bool enabled;

  /// Maximum executions per second.
  final int? maxPerSecond;

  /// Maximum executions per minute.
  final int? maxPerMinute;

  /// Maximum executions per hour.
  final int? maxPerHour;

  const QueueRateLimitConfig({
    this.enabled = false,
    this.maxPerSecond,
    this.maxPerMinute,
    this.maxPerHour,
  });
}

/// Configuration for the execution queue.
class QueueConfig {
  /// Maximum queue depth.
  final int? maxSize;

  /// Number of priority buckets.
  final int? priorityLevels;

  /// Maximum concurrent executions.
  final int? processingConcurrency;

  /// Dead letter queue configuration.
  final QueueDlqConfig dlq;

  /// Rate limiting configuration.
  final QueueRateLimitConfig rateLimit;

  const QueueConfig({
    this.maxSize,
    this.priorityLevels,
    this.processingConcurrency,
    this.dlq = const QueueDlqConfig(),
    this.rateLimit = const QueueRateLimitConfig(),
  });
}

// ═══════════════════════════════════════════════════════════════════
// Execution Queue
// ═══════════════════════════════════════════════════════════════════

/// Priority-ordered execution queue.
class ExecutionQueue {
  /// Queue configuration.
  final QueueConfig config;

  /// Queued executions sorted by priority (highest first).
  final List<PendingExecution> _queue = [];

  ExecutionQueue({this.config = const QueueConfig()});

  /// Completed execution count.
  int _completedCount = 0;

  /// Failed execution count.
  int _failedCount = 0;

  /// Running execution count.
  int _runningCount = 0;

  /// Accumulated wait time in milliseconds for completed executions.
  int _totalWaitTimeMs = 0;

  /// Accumulated execution time in milliseconds for completed executions.
  int _totalExecutionTimeMs = 0;

  /// Timestamp of first tracked execution for throughput calculation.
  DateTime? _trackingStartedAt;

  /// Number of items in the queue.
  int get size => _queue.length;

  /// Whether queue is empty.
  bool get isEmpty => _queue.isEmpty;

  /// Peek at the highest-priority item without removing.
  PendingExecution? peek() {
    if (_queue.isEmpty) return null;
    return _queue.first;
  }

  /// Enqueue an execution, inserted sorted by priority (highest first).
  void enqueue(PendingExecution execution) {
    _trackingStartedAt ??= DateTime.now();

    // Insert in priority order (higher priority first)
    var insertIndex = _queue.length;
    for (var i = 0; i < _queue.length; i++) {
      if (execution.priority > _queue[i].priority) {
        insertIndex = i;
        break;
      }
    }
    _queue.insert(insertIndex, execution);
  }

  /// Dequeue the highest-priority ready execution.
  PendingExecution? dequeue() {
    if (_queue.isEmpty) return null;

    final execution = _queue.removeAt(0);
    final waitTime =
        DateTime.now().difference(execution.enqueuedAt).inMilliseconds;
    _totalWaitTimeMs += waitTime;
    _runningCount++;
    return execution;
  }

  /// Remove a specific execution by ID.
  bool remove(String executionId) {
    final index = _queue.indexWhere((e) => e.id == executionId);
    if (index < 0) return false;
    _queue.removeAt(index);
    return true;
  }

  /// Clear all queued executions.
  void clear() {
    _queue.clear();
  }

  /// Record a completed execution for statistics.
  void recordCompletion(Duration executionTime) {
    _runningCount = (_runningCount - 1).clamp(0, _runningCount);
    _completedCount++;
    _totalExecutionTimeMs += executionTime.inMilliseconds;
  }

  /// Record a failed execution for statistics.
  void recordFailure(Duration executionTime) {
    _runningCount = (_runningCount - 1).clamp(0, _runningCount);
    _failedCount++;
    _totalExecutionTimeMs += executionTime.inMilliseconds;
  }

  /// Get current queue statistics.
  QueueStats getStats() {
    final totalFinished = _completedCount + _failedCount;
    final avgWait = totalFinished > 0
        ? Duration(milliseconds: _totalWaitTimeMs ~/ totalFinished)
        : Duration.zero;
    final avgExec = totalFinished > 0
        ? Duration(milliseconds: _totalExecutionTimeMs ~/ totalFinished)
        : Duration.zero;

    // Calculate throughput
    var throughput = 0.0;
    if (_trackingStartedAt != null && totalFinished > 0) {
      final elapsed =
          DateTime.now().difference(_trackingStartedAt!).inMilliseconds;
      if (elapsed > 0) {
        throughput = (totalFinished / elapsed) * 60000.0;
      }
    }

    // Calculate error rate
    final errorRate =
        totalFinished > 0 ? _failedCount / totalFinished : 0.0;

    return QueueStats(
      pending: _queue.length,
      running: _runningCount,
      completed: _completedCount,
      failed: _failedCount,
      avgWaitTime: avgWait,
      avgExecutionTime: avgExec,
      throughputPerMinute: throughput,
      errorRate: errorRate,
    );
  }

  /// Reset all statistics.
  void resetStats() {
    _completedCount = 0;
    _failedCount = 0;
    _runningCount = 0;
    _totalWaitTimeMs = 0;
    _totalExecutionTimeMs = 0;
    _trackingStartedAt = null;
  }
}

// ═══════════════════════════════════════════════════════════════════
// Scheduler Status
// ═══════════════════════════════════════════════════════════════════

/// Overall scheduler status.
class SchedulerStatus {
  /// Number of active schedules.
  final int activeSchedules;

  /// Number of paused schedules.
  final int pausedSchedules;

  /// Number of pending executions in queue.
  final int pendingExecutions;

  /// Number of currently running executions.
  final int runningExecutions;

  /// Timestamp of last activity.
  final DateTime? lastActivityAt;

  const SchedulerStatus({
    this.activeSchedules = 0,
    this.pausedSchedules = 0,
    this.pendingExecutions = 0,
    this.runningExecutions = 0,
    this.lastActivityAt,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'activeSchedules': activeSchedules,
        'pausedSchedules': pausedSchedules,
        'pendingExecutions': pendingExecutions,
        'runningExecutions': runningExecutions,
        if (lastActivityAt != null)
          'lastActivityAt': lastActivityAt!.toIso8601String(),
      };
}

// ═══════════════════════════════════════════════════════════════════
// Schedule
// ═══════════════════════════════════════════════════════════════════

/// A schedule definition (spec-compliant).
class Schedule {
  /// Schedule identifier.
  final String id;

  /// Backward-compatible alias for id.
  @Deprecated('Use id instead')
  String get taskId => id;

  /// Human-readable schedule name.
  final String name;

  /// Schedule description.
  final String description;

  /// Execution target reference.
  final ExecutionTarget? target;

  /// Trigger configuration.
  final Trigger trigger;

  /// Action to execute.
  final ScheduledAction action;

  /// Schedule status (replaces simple enabled flag).
  final ScheduleStatus status;

  /// Execution priority (1-10, higher = more urgent, default 5).
  final int priority;

  /// Schedule configuration.
  final ScheduleConfig config;

  /// When schedule was created.
  final DateTime createdAt;

  /// When schedule was last updated.
  final DateTime updatedAt;

  /// Last run time.
  final DateTime? lastRunAt;

  /// Next expected run time.
  final DateTime? nextRunAt;

  /// Number of currently running executions for this schedule.
  final int runningCount;

  /// Whether schedule is enabled (convenience getter for backward compatibility).
  bool get enabled => status == ScheduleStatus.active;

  /// Backward-compatible alias for createdAt.
  DateTime get registeredAt => createdAt;

  /// Backward-compatible alias for lastRunAt.
  DateTime? get lastExecutedAt => lastRunAt;

  Schedule({
    required this.id,
    this.name = '',
    this.description = '',
    this.target,
    required this.trigger,
    required this.action,
    this.status = ScheduleStatus.active,
    this.priority = 5,
    ScheduleConfig? config,
    required this.createdAt,
    DateTime? updatedAt,
    this.lastRunAt,
    this.nextRunAt,
    this.runningCount = 0,
    // ignore: deprecated_member_use_from_same_package
    @Deprecated('Use status parameter instead') bool enabled = true,
  })  : config = config ?? const ScheduleConfig(),
        updatedAt = updatedAt ?? createdAt;

  Schedule copyWith({
    String? id,
    String? name,
    String? description,
    ExecutionTarget? target,
    Trigger? trigger,
    ScheduledAction? action,
    ScheduleStatus? status,
    int? priority,
    ScheduleConfig? config,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastRunAt,
    DateTime? nextRunAt,
    int? runningCount,
    // ignore: deprecated_member_use_from_same_package
    @Deprecated('Use status parameter instead') bool? enabled,
  }) {
    // Support legacy enabled flag by mapping to status
    ScheduleStatus? resolvedStatus = status;
    if (resolvedStatus == null && enabled != null) {
      resolvedStatus = enabled ? ScheduleStatus.active : ScheduleStatus.disabled;
    }

    return Schedule(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      target: target ?? this.target,
      trigger: trigger ?? this.trigger,
      action: action ?? this.action,
      status: resolvedStatus ?? this.status,
      priority: priority ?? this.priority,
      config: config ?? this.config,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      lastRunAt: lastRunAt ?? this.lastRunAt,
      nextRunAt: nextRunAt ?? this.nextRunAt,
      runningCount: runningCount ?? this.runningCount,
    );
  }
}

/// Backward-compatible alias for Schedule.
typedef ScheduledTask = Schedule;

/// Action to execute when triggered.
typedef ScheduledAction = Future<void> Function(Map<String, dynamic> data);

// ═══════════════════════════════════════════════════════════════════
// Triggers
// ═══════════════════════════════════════════════════════════════════

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

  /// Composite trigger (combines multiple triggers).
  composite,
}

/// Cron-based trigger.
class CronTrigger implements Trigger {
  @override
  final String id;

  @override
  TriggerType get type => TriggerType.cron;

  /// Cron expression.
  final String expression;

  /// Timezone (e.g. 'Asia/Seoul', default UTC).
  final String? timezone;

  /// Earliest date this trigger can fire.
  final DateTime? notBefore;

  /// Latest date this trigger can fire.
  final DateTime? notAfter;

  /// Whether to skip execution on holidays.
  final bool skipHolidays;

  /// Holiday calendar identifier (when skipHolidays is true).
  final String? holidayCalendar;

  CronTrigger(
    this.expression, {
    String? id,
    this.timezone,
    this.notBefore,
    this.notAfter,
    this.skipHolidays = false,
    this.holidayCalendar,
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

/// Structured filter for event triggers.
class EventFilter {
  /// Event type pattern to match.
  final String? eventType;

  /// Event source pattern to match.
  final String? source;

  /// Additional filter conditions as key-value pairs.
  final Map<String, dynamic> conditions;

  const EventFilter({
    this.eventType,
    this.source,
    this.conditions = const {},
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        if (eventType != null) 'eventType': eventType,
        if (source != null) 'source': source,
        if (conditions.isNotEmpty) 'conditions': conditions,
      };
}

/// Batch configuration for event triggers.
class EventBatchConfig {
  /// Whether batching is enabled.
  final bool enabled;

  /// Maximum events per batch.
  final int? maxSize;

  /// Maximum wait time before processing a batch.
  final Duration? maxWait;

  const EventBatchConfig({
    this.enabled = false,
    this.maxSize,
    this.maxWait,
  });
}

/// Debounce configuration for event triggers.
class EventDebounceConfig {
  /// Whether debouncing is enabled.
  final bool enabled;

  /// Debounce window duration.
  final Duration window;

  const EventDebounceConfig({
    this.enabled = false,
    this.window = const Duration(seconds: 5),
  });
}

/// Event-driven trigger.
class EventTrigger implements Trigger {
  @override
  final String id;

  @override
  TriggerType get type => TriggerType.event;

  /// Event type to listen for.
  final String eventType;

  /// Structured event filter.
  final EventFilter? filter;

  /// Batching options for grouping events.
  final EventBatchConfig? batch;

  /// Debouncing options to avoid rapid re-triggers.
  final EventDebounceConfig? debounce;

  EventTrigger(
    this.eventType, {
    String? id,
    this.filter,
    this.batch,
    this.debounce,
  }) : id = id ?? 'event_$eventType';
}

/// Source type for deadline data.
enum DeadlineSourceType {
  /// Deadline from an entity field (e.g. task.dueDate).
  entityField,

  /// Deadline from another schedule.
  schedule,

  /// Deadline from an external endpoint.
  external,
}

/// Describes where deadline data comes from.
class DeadlineSource {
  /// Source type.
  final DeadlineSourceType type;

  /// Entity type (for entityField source).
  final String? entityType;

  /// Field name on the entity (for entityField source).
  final String? field;

  /// Query to find entities (for entityField source).
  final Map<String, dynamic>? query;

  /// Schedule ID (for schedule source).
  final String? scheduleId;

  /// External endpoint URL (for external source).
  final String? endpoint;

  const DeadlineSource({
    required this.type,
    this.entityType,
    this.field,
    this.query,
    this.scheduleId,
    this.endpoint,
  });

  /// Create an entity field deadline source.
  factory DeadlineSource.entityField({
    required String entityType,
    required String field,
    Map<String, dynamic>? query,
  }) {
    return DeadlineSource(
      type: DeadlineSourceType.entityField,
      entityType: entityType,
      field: field,
      query: query,
    );
  }

  /// Create a schedule-based deadline source.
  factory DeadlineSource.schedule(String scheduleId) {
    return DeadlineSource(
      type: DeadlineSourceType.schedule,
      scheduleId: scheduleId,
    );
  }

  /// Create an external deadline source.
  factory DeadlineSource.external(String endpoint) {
    return DeadlineSource(
      type: DeadlineSourceType.external,
      endpoint: endpoint,
    );
  }
}

/// Escalation action type.
enum EscalationActionType {
  /// Send notification.
  notify,

  /// Boost execution priority.
  priorityBoost,

  /// Execute in parallel with additional resources.
  parallelExec,

  /// Escalate approval to higher authority.
  escalateApproval,
}

/// Action to take at an escalation threshold.
class EscalationAction {
  /// Action type.
  final EscalationActionType type;

  /// Additional configuration for the action.
  final Map<String, dynamic> config;

  const EscalationAction({
    required this.type,
    this.config = const {},
  });
}

/// Threshold at which escalation is triggered.
class EscalationThreshold {
  /// Duration before the deadline to trigger this escalation.
  final Duration offsetBefore;

  /// Action to take at this threshold.
  final EscalationAction action;

  const EscalationThreshold({
    required this.offsetBefore,
    required this.action,
  });
}

/// Escalation configuration for deadline triggers.
class EscalationConfig {
  /// Whether escalation is enabled.
  final bool enabled;

  /// Ordered escalation thresholds (earliest first).
  final List<EscalationThreshold> thresholds;

  const EscalationConfig({
    this.enabled = false,
    this.thresholds = const [],
  });
}

/// Deadline-aware trigger.
class DeadlineTrigger implements Trigger {
  @override
  final String id;

  @override
  TriggerType get type => TriggerType.deadline;

  /// Source of deadline data.
  final DeadlineSource deadlineSource;

  /// Execute this duration before the deadline.
  final Duration offset;

  /// Escalation configuration for deadline at risk.
  final EscalationConfig? escalation;

  DeadlineTrigger({
    required this.deadlineSource,
    required this.offset,
    this.escalation,
    String? id,
  }) : id = id ?? 'deadline_${deadlineSource.type.name}';
}

/// Manual trigger.
class ManualTrigger implements Trigger {
  @override
  final String id;

  @override
  TriggerType get type => TriggerType.manual;

  /// List of user IDs allowed to trigger this manually.
  final List<String> allowedUsers;

  /// Whether approval is required before execution.
  final bool requireApproval;

  /// List of approver user IDs (when requireApproval is true).
  final List<String> approvers;

  /// JSON Schema defining expected input for manual trigger.
  final Map<String, dynamic>? inputSchema;

  /// List of required input field names for manual runs.
  final List<String>? requiredInputs;

  ManualTrigger({
    String? id,
    this.allowedUsers = const [],
    this.requireApproval = false,
    this.approvers = const [],
    this.inputSchema,
    this.requiredInputs,
  }) : id = id ?? 'manual';
}

/// Composite trigger operator.
enum CompositeOperator {
  /// All triggers must fire (logical AND).
  and,

  /// Any trigger must fire (logical OR).
  or,

  /// Triggers must fire in sequence within a timeout.
  sequence,
}

/// Composite trigger that combines multiple triggers.
///
/// Supports AND (all must fire), OR (any must fire), and
/// sequence (must fire in order within a timeout) operators.
class CompositeTrigger implements Trigger {
  @override
  final String id;

  @override
  TriggerType get type => TriggerType.composite;

  /// How to combine the child triggers.
  final CompositeOperator operator;

  /// Child triggers to combine.
  final List<Trigger> triggers;

  /// Timeout for sequence operator (how long to wait for all triggers).
  final Duration? sequenceTimeout;

  /// Whether to reset the sequence when a trigger fires out of order.
  final bool? resetOnMismatch;

  /// Tracks which child triggers have fired (by trigger ID).
  final Map<String, DateTime> _firedTriggers = {};

  /// When the first trigger in a sequence fired.
  DateTime? _sequenceStartedAt;

  CompositeTrigger({
    required this.operator,
    required this.triggers,
    this.sequenceTimeout,
    this.resetOnMismatch,
    String? id,
  }) : id = id ?? 'composite_${operator.name}_${triggers.length}';

  /// Record that a child trigger has fired.
  void recordTriggerFired(String triggerId) {
    final now = DateTime.now();
    _firedTriggers[triggerId] = now;

    // Track sequence start time
    if (operator == CompositeOperator.sequence &&
        _sequenceStartedAt == null) {
      _sequenceStartedAt = now;
    }
  }

  /// Check if the composite trigger condition is satisfied.
  bool isSatisfied() {
    switch (operator) {
      case CompositeOperator.and:
        return _checkAnd();
      case CompositeOperator.or:
        return _checkOr();
      case CompositeOperator.sequence:
        return _checkSequence();
    }
  }

  /// Reset tracked trigger state.
  void reset() {
    _firedTriggers.clear();
    _sequenceStartedAt = null;
  }

  bool _checkAnd() {
    // All child triggers must have fired
    for (final trigger in triggers) {
      if (!_firedTriggers.containsKey(trigger.id)) {
        return false;
      }
    }
    return true;
  }

  bool _checkOr() {
    // Any child trigger must have fired
    for (final trigger in triggers) {
      if (_firedTriggers.containsKey(trigger.id)) {
        return true;
      }
    }
    return false;
  }

  bool _checkSequence() {
    // All triggers must have fired in order within the timeout
    if (_firedTriggers.length < triggers.length) return false;

    // Check timeout if specified
    if (sequenceTimeout != null && _sequenceStartedAt != null) {
      final elapsed = DateTime.now().difference(_sequenceStartedAt!);
      if (elapsed > sequenceTimeout!) {
        // Timed out, reset and return false
        reset();
        return false;
      }
    }

    // Verify ordering: each trigger must have fired after the previous one
    DateTime? previousTime;
    for (final trigger in triggers) {
      final firedAt = _firedTriggers[trigger.id];
      if (firedAt == null) return false;

      if (previousTime != null && firedAt.isBefore(previousTime)) {
        return false;
      }
      previousTime = firedAt;
    }

    return true;
  }
}

// ═══════════════════════════════════════════════════════════════════
// Providers
// ═══════════════════════════════════════════════════════════════════

/// Provider for deadline information.
abstract class DeadlineProvider {
  /// Get deadline from a deadline source definition.
  Future<DateTime?> getDeadline(DeadlineSource source);
}

// ═══════════════════════════════════════════════════════════════════
// Task Execution
// ═══════════════════════════════════════════════════════════════════

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

  /// Queued for execution.
  queued,

  /// Currently running.
  running,

  /// Completed successfully.
  completed,

  /// Failed.
  failed,

  /// Cancelled.
  cancelled,

  /// Timed out.
  timeout,

  /// Skipped due to concurrency limit.
  skippedConcurrency,

  /// Skipped due to deduplication.
  skippedDeduplicated,
}

// ═══════════════════════════════════════════════════════════════════
// Scheduler
// ═══════════════════════════════════════════════════════════════════

/// Scheduler for managing pipeline triggers.
///
/// Supports priority-based execution queuing, concurrency control,
/// task deduplication, and pause/resume of individual schedules.
class Scheduler {
  /// Workspace scope for this scheduler instance.
  final String workspaceId;

  /// Registered triggers.
  final Map<String, ScheduledTask> _tasks = {};

  /// Event subscriptions.
  final Map<String, List<String>> _eventSubscriptions = {};

  /// Whether scheduler is running.
  bool _running = false;

  /// Execution queue for priority-ordered execution.
  final ExecutionQueue _queue = ExecutionQueue();

  /// Deduplication tracking: taskId -> last execution timestamp.
  final Map<String, DateTime> _dedupeTracker = {};

  /// Running execution count per task.
  final Map<String, int> _runningCounts = {};

  /// Timestamp of last activity.
  DateTime? _lastActivityAt;

  Scheduler({this.workspaceId = 'default'});

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

  /// Get the execution queue.
  ExecutionQueue get queue => _queue;

  /// Register a scheduled task.
  ///
  /// Returns the created [Schedule] for confirmation and chaining.
  Future<Schedule> register({
    required String taskId,
    required Trigger trigger,
    required ScheduledAction action,
    bool enabled = true,
    int priority = 5,
    ScheduleConfig? config,
  }) async {
    final resolvedConfig = config ?? const ScheduleConfig();
    final status = enabled ? ScheduleStatus.active : ScheduleStatus.disabled;

    final schedule = ScheduledTask(
      id: taskId,
      trigger: trigger,
      action: action,
      status: status,
      priority: priority,
      config: resolvedConfig,
      createdAt: DateTime.now(),
    );

    _tasks[taskId] = schedule;

    // Register event subscriptions
    if (trigger is EventTrigger) {
      _eventSubscriptions
          .putIfAbsent(trigger.eventType, () => [])
          .add(taskId);
    }

    // Register event subscriptions for composite triggers containing events
    if (trigger is CompositeTrigger) {
      _registerCompositeTriggerEvents(taskId, trigger);
    }

    return schedule;
  }

  /// Unregister a task.
  Future<void> unregister(String taskId) async {
    final task = _tasks.remove(taskId);
    if (task != null) {
      if (task.trigger is EventTrigger) {
        final eventType = (task.trigger as EventTrigger).eventType;
        _eventSubscriptions[eventType]?.remove(taskId);
      }
      if (task.trigger is CompositeTrigger) {
        _unregisterCompositeTriggerEvents(
            taskId, task.trigger as CompositeTrigger);
      }
    }
    _runningCounts.remove(taskId);
    _dedupeTracker.remove(taskId);
  }

  /// Enable a task (set status to active).
  void enable(String taskId) {
    final task = _tasks[taskId];
    if (task != null) {
      _tasks[taskId] = task.copyWith(status: ScheduleStatus.active);
    }
  }

  /// Disable a task (set status to disabled).
  void disable(String taskId) {
    final task = _tasks[taskId];
    if (task != null) {
      _tasks[taskId] = task.copyWith(status: ScheduleStatus.disabled);
    }
  }

  /// Pause a task (set status to paused).
  Future<void> pause(String taskId) async {
    final task = _tasks[taskId];
    if (task != null) {
      _tasks[taskId] = task.copyWith(status: ScheduleStatus.paused);
    }
  }

  /// Resume a paused task (set status back to active).
  Future<void> resume(String taskId) async {
    final task = _tasks[taskId];
    if (task != null && task.status == ScheduleStatus.paused) {
      _tasks[taskId] = task.copyWith(status: ScheduleStatus.active);
    }
  }

  /// Get task by ID.
  ScheduledTask? getTask(String taskId) => _tasks[taskId];

  /// List all tasks.
  List<ScheduledTask> listTasks({
    bool? enabled,
    ScheduleStatus? status,
    List<String>? tags,
  }) {
    var tasks = _tasks.values;

    // Filter by enabled (backward compatibility)
    if (enabled != null) {
      tasks = tasks.where((t) => t.enabled == enabled);
    }

    // Filter by status
    if (status != null) {
      tasks = tasks.where((t) => t.status == status);
    }

    // Filter by tags
    if (tags != null && tags.isNotEmpty) {
      tasks = tasks.where(
        (t) => tags.any((tag) => t.config.tags.contains(tag)),
      );
    }

    return tasks.toList();
  }

  /// Get overall scheduler status.
  SchedulerStatus getStatus() {
    final stats = _queue.getStats();
    final activeCount =
        _tasks.values.where((t) => t.status == ScheduleStatus.active).length;
    final pausedCount =
        _tasks.values.where((t) => t.status == ScheduleStatus.paused).length;

    return SchedulerStatus(
      activeSchedules: activeCount,
      pausedSchedules: pausedCount,
      pendingExecutions: stats.pending,
      runningExecutions: stats.running,
      lastActivityAt: _lastActivityAt,
    );
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
      if (task == null || task.status != ScheduleStatus.active) continue;

      // Handle composite triggers
      if (task.trigger is CompositeTrigger) {
        final composite = task.trigger as CompositeTrigger;
        // Find the matching child event trigger and record it
        for (final child in composite.triggers) {
          if (child is EventTrigger && child.eventType == eventType) {
            composite.recordTriggerFired(child.id);
          }
        }

        // Check if composite condition is satisfied
        if (!composite.isSatisfied()) continue;

        // Reset after satisfaction
        composite.reset();
      }

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
      if (task.status != ScheduleStatus.active) continue;
      if (task.trigger is! DeadlineTrigger) continue;

      final trigger = task.trigger as DeadlineTrigger;
      final deadline =
          await deadlineProvider.getDeadline(trigger.deadlineSource);

      if (deadline == null) continue;

      final triggerTime = deadline.subtract(trigger.offset);
      if (now.isAfter(triggerTime) && now.isBefore(deadline)) {
        // Check if not already executed
        if (task.lastExecutedAt == null ||
            task.lastExecutedAt!.isBefore(triggerTime)) {
          final execution = await _executeTask(task, {
            'deadline': deadline.toIso8601String(),
            'sourceType': trigger.deadlineSource.type.name,
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
    _lastActivityAt = startTime;

    // Check concurrency limit
    final currentRunning = _runningCounts[task.id] ?? 0;
    if (currentRunning >= task.config.maxConcurrent) {
      return TaskExecution(
        taskId: task.id,
        triggerId: task.trigger.id,
        status: ExecutionStatus.skippedConcurrency,
        startedAt: startTime,
        completedAt: DateTime.now(),
        error: 'Concurrency limit reached '
            '($currentRunning/${task.config.maxConcurrent})',
      );
    }

    // Check deduplication
    if (task.config.deduplicate) {
      final lastExec = _dedupeTracker[task.id];
      if (lastExec != null && task.config.dedupeWindow != null) {
        final elapsed = startTime.difference(lastExec);
        if (elapsed < task.config.dedupeWindow!) {
          return TaskExecution(
            taskId: task.id,
            triggerId: task.trigger.id,
            status: ExecutionStatus.skippedDeduplicated,
            startedAt: startTime,
            completedAt: DateTime.now(),
            error: 'Deduplicated: last execution was '
                '${elapsed.inMilliseconds}ms ago '
                '(window: ${task.config.dedupeWindow!.inMilliseconds}ms)',
          );
        }
      }
    }

    // Increment running count
    _runningCounts[task.id] = currentRunning + 1;

    try {
      // Execute with optional timeout
      if (task.config.timeout != null) {
        await task.action(data ?? {}).timeout(task.config.timeout!);
      } else {
        await task.action(data ?? {});
      }

      final completedAt = DateTime.now();
      final executionTime = completedAt.difference(startTime);

      // Update tracking state
      _runningCounts[task.id] =
          (_runningCounts[task.id] ?? 1) - 1;
      _dedupeTracker[task.id] = completedAt;
      _lastActivityAt = completedAt;

      // Update last execution time on task
      _tasks[task.id] = task.copyWith(lastRunAt: completedAt);

      // Record completion in queue stats
      _queue.recordCompletion(executionTime);

      return TaskExecution(
        taskId: task.id,
        triggerId: task.trigger.id,
        status: ExecutionStatus.completed,
        startedAt: startTime,
        completedAt: completedAt,
      );
    } catch (e) {
      final completedAt = DateTime.now();
      final executionTime = completedAt.difference(startTime);

      // Decrement running count
      _runningCounts[task.id] =
          (_runningCounts[task.id] ?? 1) - 1;
      _lastActivityAt = completedAt;

      // Record failure in queue stats
      _queue.recordFailure(executionTime);

      return TaskExecution(
        taskId: task.id,
        triggerId: task.trigger.id,
        status: ExecutionStatus.failed,
        startedAt: startTime,
        completedAt: completedAt,
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
        if (task.status != ScheduleStatus.active) continue;
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

  /// Register event subscriptions for composite trigger child events.
  void _registerCompositeTriggerEvents(
    String taskId,
    CompositeTrigger trigger,
  ) {
    for (final child in trigger.triggers) {
      if (child is EventTrigger) {
        _eventSubscriptions
            .putIfAbsent(child.eventType, () => [])
            .add(taskId);
      }
    }
  }

  /// Unregister event subscriptions for composite trigger child events.
  void _unregisterCompositeTriggerEvents(
    String taskId,
    CompositeTrigger trigger,
  ) {
    for (final child in trigger.triggers) {
      if (child is EventTrigger) {
        _eventSubscriptions[child.eventType]?.remove(taskId);
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// Execution Manager
// ═══════════════════════════════════════════════════════════════════

/// Manages execution lifecycle for scheduled tasks.
abstract class ExecutionManager {
  /// Enqueue an execution request; returns the execution ID.
  Future<String> enqueue(ExecutionRequest request);

  /// Dequeue the next execution ready to run.
  Future<SchedulerExecution?> dequeue();

  /// Mark an execution as started.
  Future<SchedulerExecution> start(String executionId);

  /// Cancel a queued or running execution.
  Future<SchedulerExecution> cancel(String executionId, {String? reason});

  /// Get a single execution by ID.
  Future<SchedulerExecution?> getExecution(String executionId);

  /// List executions matching optional filter criteria.
  Future<List<SchedulerExecution>> listExecutions(ExecutionFilter? filter);
}

/// Request to enqueue an execution.
class ExecutionRequest {
  /// Schedule that triggered this execution.
  final String scheduleId;

  /// Information about the trigger that caused this execution.
  final TriggerInfo triggeredBy;

  /// Input data for the execution.
  final Map<String, dynamic>? input;

  /// Execution priority (higher = more urgent).
  final int? priority;

  const ExecutionRequest({
    required this.scheduleId,
    required this.triggeredBy,
    this.input,
    this.priority,
  });
}

/// Execution record managed by the scheduler.
///
/// Named SchedulerExecution to avoid conflict with execution_engine's Execution.
class SchedulerExecution {
  /// Unique execution identifier.
  final String id;

  /// Associated schedule identifier.
  final String scheduleId;

  /// Current execution status: 'queued', 'running', 'completed', 'failed', 'cancelled'.
  final String status;

  /// Information about the trigger that caused this execution.
  final TriggerInfo triggeredBy;

  /// When this execution was queued.
  final DateTime queuedAt;

  /// When this execution started running.
  final DateTime? startedAt;

  /// When this execution completed.
  final DateTime? completedAt;

  /// Input data for the execution.
  final Map<String, dynamic>? input;

  /// Execution result (on success).
  final ExecutionResult? result;

  /// Execution error (on failure).
  final ExecutionError? error;

  /// Execution performance metrics.
  final ExecutionMetrics? metrics;

  const SchedulerExecution({
    required this.id,
    required this.scheduleId,
    required this.status,
    required this.triggeredBy,
    required this.queuedAt,
    this.startedAt,
    this.completedAt,
    this.input,
    this.result,
    this.error,
    this.metrics,
  });
}

/// Information about what triggered an execution.
class TriggerInfo {
  /// Trigger type: 'schedule', 'manual', 'event', 'api'.
  final String type;

  /// When the trigger fired.
  final DateTime triggeredAt;

  /// Who or what triggered the execution.
  final String? triggeredBy;

  /// Additional trigger context.
  final Map<String, dynamic>? context;

  const TriggerInfo({
    required this.type,
    required this.triggeredAt,
    this.triggeredBy,
    this.context,
  });
}

/// Result of a completed execution.
class ExecutionResult {
  /// Whether the execution succeeded.
  final bool success;

  /// Output data produced by the execution.
  final Map<String, dynamic>? output;

  /// Human-readable summary of the result.
  final String? summary;

  const ExecutionResult({
    required this.success,
    this.output,
    this.summary,
  });
}

/// Error details from a failed execution.
class ExecutionError {
  /// Error code for programmatic handling.
  final String code;

  /// Human-readable error message.
  final String message;

  /// Whether the execution can be retried.
  final bool retryable;

  /// Stack trace for debugging.
  final String? stackTrace;

  const ExecutionError({
    required this.code,
    required this.message,
    required this.retryable,
    this.stackTrace,
  });
}

/// Performance metrics for an execution.
class ExecutionMetrics {
  /// Total wall-clock duration of the execution.
  final Duration totalDuration;

  /// Time spent waiting in queue before execution started.
  final Duration? queueWaitTime;

  /// Actual execution time (excluding queue wait).
  final Duration? executionTime;

  /// Number of retry attempts.
  final int? retryCount;

  const ExecutionMetrics({
    required this.totalDuration,
    this.queueWaitTime,
    this.executionTime,
    this.retryCount,
  });
}

/// Filter criteria for listing executions.
class ExecutionFilter {
  /// Filter by schedule ID.
  final String? scheduleId;

  /// Filter by execution status.
  final String? status;

  /// Only include executions after this time.
  final DateTime? since;

  /// Only include executions before this time.
  final DateTime? until;

  /// Maximum number of results to return.
  final int? limit;

  const ExecutionFilter({
    this.scheduleId,
    this.status,
    this.since,
    this.until,
    this.limit,
  });
}

// ═══════════════════════════════════════════════════════════════════
// Schedule Retry Config
// ═══════════════════════════════════════════════════════════════════

/// Retry configuration for scheduled executions.
class ScheduleRetryConfig {
  /// Maximum retry attempts.
  final int maxAttempts;

  /// Initial delay between retries.
  final Duration initialDelay;

  /// Backoff multiplier for exponential backoff.
  final double backoffMultiplier;

  /// Maximum delay between retries.
  final Duration maxDelay;

  const ScheduleRetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(minutes: 5),
  });

  /// Calculate delay for a given attempt.
  Duration delayForAttempt(int attempt) {
    if (attempt <= 0) return initialDelay;
    final delayMs =
        initialDelay.inMilliseconds * (1 << (attempt - 1).clamp(0, 30));
    final cappedMs = delayMs.clamp(0, maxDelay.inMilliseconds);
    return Duration(milliseconds: cappedMs);
  }
}

// ═══════════════════════════════════════════════════════════════════
// Schedule Registration
// ═══════════════════════════════════════════════════════════════════

/// Registration result returned after creating a schedule.
class ScheduleRegistration {
  /// The created schedule.
  final Schedule schedule;

  /// Whether this was a new registration or update of an existing one.
  final bool isNew;

  const ScheduleRegistration({
    required this.schedule,
    required this.isNew,
  });
}

// ═══════════════════════════════════════════════════════════════════
// Filter Condition
// ═══════════════════════════════════════════════════════════════════

/// Structured filter condition for event filtering.
class FilterCondition {
  /// Field path to filter on (e.g. 'payload.type').
  final String field;

  /// Comparison operator.
  final FilterOperator operator;

  /// Value to compare against.
  final dynamic value;

  const FilterCondition({
    required this.field,
    required this.operator,
    required this.value,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'field': field,
        'operator': operator.name,
        'value': value,
      };
}

/// Operators for filter conditions.
enum FilterOperator {
  /// Equality check.
  eq,

  /// Inequality check.
  neq,

  /// Greater than.
  gt,

  /// Greater than or equal.
  gte,

  /// Less than.
  lt,

  /// Less than or equal.
  lte,

  /// String contains.
  contains,

  /// String starts with.
  startsWith,

  /// Value is in a list.
  inList,
}

// ═══════════════════════════════════════════════════════════════════
// System Event Types
// ═══════════════════════════════════════════════════════════════════

/// Standard system event type constants for scheduler integration.
abstract class SystemEventType {
  SystemEventType._();

  static const scheduleCreated = 'scheduler.schedule.created';
  static const scheduleUpdated = 'scheduler.schedule.updated';
  static const scheduleDeleted = 'scheduler.schedule.deleted';
  static const schedulePaused = 'scheduler.schedule.paused';
  static const scheduleResumed = 'scheduler.schedule.resumed';
  static const scheduleTriggered = 'scheduler.schedule.triggered';
  static const scheduleMissed = 'scheduler.schedule.missed';
  static const executionQueued = 'scheduler.execution.queued';
  static const executionStarted = 'scheduler.execution.started';
  static const executionCompleted = 'scheduler.execution.completed';
  static const executionFailed = 'scheduler.execution.failed';
  static const executionRetry = 'scheduler.execution.retry';
  static const executionCancelled = 'scheduler.execution.cancelled';
  static const deadlineApproaching = 'scheduler.execution.deadline_approaching';
  static const queueOverflow = 'scheduler.queue.overflow';
}
