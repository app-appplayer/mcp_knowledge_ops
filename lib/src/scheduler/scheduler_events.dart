/// Scheduler Events - Event classes for scheduler state changes.
///
/// All scheduler events extend [OpsEvent] and carry scheduler-specific
/// data such as schedule IDs, execution IDs, and trigger information.
library;

import '../events/ops_event.dart';

// ═══════════════════════════════════════════════════════════════════
// Schedule Lifecycle Events
// ═══════════════════════════════════════════════════════════════════

/// Emitted when a new schedule is created.
class ScheduleCreatedEvent extends OpsEvent {
  /// The ID of the created schedule.
  String get scheduleId => payload['scheduleId'] as String;

  ScheduleCreatedEvent({
    required String scheduleId,
    required String correlationId,
    required String runId,
    required String workspaceId,
    String? causationId,
  }) : super(
          eventId: OpsEvent.generateEventId(),
          eventType: 'scheduler.schedule.created',
          correlationId: correlationId,
          causationId: causationId,
          runId: runId,
          workspaceId: workspaceId,
          timestamp: DateTime.now(),
          payload: {'scheduleId': scheduleId},
          meta: const OpsEventMeta(source: 'scheduler'),
        );
}

/// Emitted when a schedule is updated.
class ScheduleUpdatedEvent extends OpsEvent {
  /// The ID of the updated schedule.
  String get scheduleId => payload['scheduleId'] as String;

  ScheduleUpdatedEvent({
    required String scheduleId,
    required String correlationId,
    required String runId,
    required String workspaceId,
    String? causationId,
  }) : super(
          eventId: OpsEvent.generateEventId(),
          eventType: 'scheduler.schedule.updated',
          correlationId: correlationId,
          causationId: causationId,
          runId: runId,
          workspaceId: workspaceId,
          timestamp: DateTime.now(),
          payload: {'scheduleId': scheduleId},
          meta: const OpsEventMeta(source: 'scheduler'),
        );
}

/// Emitted when a schedule is deleted.
class ScheduleDeletedEvent extends OpsEvent {
  /// The ID of the deleted schedule.
  String get scheduleId => payload['scheduleId'] as String;

  ScheduleDeletedEvent({
    required String scheduleId,
    required String correlationId,
    required String runId,
    required String workspaceId,
    String? causationId,
  }) : super(
          eventId: OpsEvent.generateEventId(),
          eventType: 'scheduler.schedule.deleted',
          correlationId: correlationId,
          causationId: causationId,
          runId: runId,
          workspaceId: workspaceId,
          timestamp: DateTime.now(),
          payload: {'scheduleId': scheduleId},
          meta: const OpsEventMeta(source: 'scheduler'),
        );
}

/// Emitted when a schedule is paused.
class SchedulePausedEvent extends OpsEvent {
  /// The ID of the paused schedule.
  String get scheduleId => payload['scheduleId'] as String;

  SchedulePausedEvent({
    required String scheduleId,
    required String correlationId,
    required String runId,
    required String workspaceId,
    String? causationId,
  }) : super(
          eventId: OpsEvent.generateEventId(),
          eventType: 'scheduler.schedule.paused',
          correlationId: correlationId,
          causationId: causationId,
          runId: runId,
          workspaceId: workspaceId,
          timestamp: DateTime.now(),
          payload: {'scheduleId': scheduleId},
          meta: const OpsEventMeta(source: 'scheduler'),
        );
}

/// Emitted when a schedule is resumed from pause.
class ScheduleResumedEvent extends OpsEvent {
  /// The ID of the resumed schedule.
  String get scheduleId => payload['scheduleId'] as String;

  ScheduleResumedEvent({
    required String scheduleId,
    required String correlationId,
    required String runId,
    required String workspaceId,
    String? causationId,
  }) : super(
          eventId: OpsEvent.generateEventId(),
          eventType: 'scheduler.schedule.resumed',
          correlationId: correlationId,
          causationId: causationId,
          runId: runId,
          workspaceId: workspaceId,
          timestamp: DateTime.now(),
          payload: {'scheduleId': scheduleId},
          meta: const OpsEventMeta(source: 'scheduler'),
        );
}

/// Emitted when a schedule is triggered and an execution is created.
class ScheduleTriggeredEvent extends OpsEvent {
  /// The ID of the triggered schedule.
  String get scheduleId => payload['scheduleId'] as String;

  /// The ID of the created execution.
  String get executionId => payload['executionId'] as String;

  /// The ID of the trigger that fired.
  String? get triggerId => payload['triggerId'] as String?;

  /// The type of trigger (e.g. 'cron', 'event', 'deadline', 'manual').
  String? get triggerType => payload['triggerType'] as String?;

  /// Additional trigger context.
  Map<String, dynamic>? get triggerContext =>
      payload['context'] as Map<String, dynamic>?;

  ScheduleTriggeredEvent({
    required String scheduleId,
    required String executionId,
    String? triggerId,
    String? triggerType,
    Map<String, dynamic>? context,
    required String correlationId,
    required String runId,
    required String workspaceId,
    String? causationId,
  }) : super(
          eventId: OpsEvent.generateEventId(),
          eventType: 'scheduler.schedule.triggered',
          correlationId: correlationId,
          causationId: causationId,
          runId: runId,
          workspaceId: workspaceId,
          timestamp: DateTime.now(),
          payload: {
            'scheduleId': scheduleId,
            'executionId': executionId,
            if (triggerId != null) 'triggerId': triggerId,
            if (triggerType != null) 'triggerType': triggerType,
            if (context != null) 'context': context,
          },
          meta: const OpsEventMeta(source: 'scheduler'),
        );
}

/// Emitted when a scheduled execution was missed.
class ScheduleMissedEvent extends OpsEvent {
  /// The ID of the schedule that missed execution.
  String get scheduleId => payload['scheduleId'] as String;

  /// When the execution was supposed to run.
  String get missedAt => payload['missedAt'] as String;

  ScheduleMissedEvent({
    required String scheduleId,
    required DateTime missedAt,
    required String correlationId,
    required String runId,
    required String workspaceId,
    String? causationId,
  }) : super(
          eventId: OpsEvent.generateEventId(),
          eventType: 'scheduler.schedule.missed',
          correlationId: correlationId,
          causationId: causationId,
          runId: runId,
          workspaceId: workspaceId,
          timestamp: DateTime.now(),
          payload: {
            'scheduleId': scheduleId,
            'missedAt': missedAt.toIso8601String(),
          },
          meta: const OpsEventMeta(source: 'scheduler'),
        );
}

// ═══════════════════════════════════════════════════════════════════
// Execution Lifecycle Events
// ═══════════════════════════════════════════════════════════════════

/// Emitted when an execution is added to the queue.
class ExecutionQueuedEvent extends OpsEvent {
  /// The ID of the queued execution.
  String get executionId => payload['executionId'] as String;

  /// The ID of the associated schedule.
  String get scheduleId => payload['scheduleId'] as String;

  ExecutionQueuedEvent({
    required String executionId,
    required String scheduleId,
    required String correlationId,
    required String runId,
    required String workspaceId,
    String? causationId,
  }) : super(
          eventId: OpsEvent.generateEventId(),
          eventType: 'scheduler.execution.queued',
          correlationId: correlationId,
          causationId: causationId,
          runId: runId,
          workspaceId: workspaceId,
          timestamp: DateTime.now(),
          payload: {
            'executionId': executionId,
            'scheduleId': scheduleId,
          },
          meta: const OpsEventMeta(source: 'scheduler'),
        );
}

/// Emitted when an execution begins running.
class ExecutionStartedEvent extends OpsEvent {
  /// The ID of the started execution.
  String get executionId => payload['executionId'] as String;

  ExecutionStartedEvent({
    required String executionId,
    required String correlationId,
    required String runId,
    required String workspaceId,
    String? causationId,
  }) : super(
          eventId: OpsEvent.generateEventId(),
          eventType: 'scheduler.execution.started',
          correlationId: correlationId,
          causationId: causationId,
          runId: runId,
          workspaceId: workspaceId,
          timestamp: DateTime.now(),
          payload: {'executionId': executionId},
          meta: const OpsEventMeta(source: 'scheduler'),
        );
}

/// Emitted when an execution completes (successfully or not).
class ExecutionCompletedEvent extends OpsEvent {
  /// The ID of the completed execution.
  String get executionId => payload['executionId'] as String;

  /// Whether the execution succeeded.
  bool get success => payload['success'] as bool;

  /// Duration of the execution in milliseconds.
  int? get durationMs => payload['durationMs'] as int?;

  /// Summary of the output produced.
  String? get outputSummary => payload['outputSummary'] as String?;

  ExecutionCompletedEvent({
    required String executionId,
    required bool success,
    Duration? duration,
    String? outputSummary,
    required String correlationId,
    required String runId,
    required String workspaceId,
    String? causationId,
  }) : super(
          eventId: OpsEvent.generateEventId(),
          eventType: 'scheduler.execution.completed',
          correlationId: correlationId,
          causationId: causationId,
          runId: runId,
          workspaceId: workspaceId,
          timestamp: DateTime.now(),
          payload: {
            'executionId': executionId,
            'success': success,
            if (duration != null) 'durationMs': duration.inMilliseconds,
            if (outputSummary != null) 'outputSummary': outputSummary,
          },
          meta: const OpsEventMeta(source: 'scheduler'),
        );
}

/// Emitted when an execution fails.
class ExecutionFailedEvent extends OpsEvent {
  /// The ID of the failed execution.
  String get executionId => payload['executionId'] as String;

  /// Error description.
  String get error => payload['error'] as String;

  ExecutionFailedEvent({
    required String executionId,
    required String error,
    required String correlationId,
    required String runId,
    required String workspaceId,
    String? causationId,
  }) : super(
          eventId: OpsEvent.generateEventId(),
          eventType: 'scheduler.execution.failed',
          correlationId: correlationId,
          causationId: causationId,
          runId: runId,
          workspaceId: workspaceId,
          timestamp: DateTime.now(),
          payload: {
            'executionId': executionId,
            'error': error,
          },
          meta: const OpsEventMeta(source: 'scheduler'),
        );
}

/// Emitted when an execution is retried.
class ExecutionRetryEvent extends OpsEvent {
  /// The ID of the retried execution.
  String get executionId => payload['executionId'] as String;

  /// The retry attempt number.
  int get attempt => payload['attempt'] as int;

  ExecutionRetryEvent({
    required String executionId,
    required int attempt,
    required String correlationId,
    required String runId,
    required String workspaceId,
    String? causationId,
  }) : super(
          eventId: OpsEvent.generateEventId(),
          eventType: 'scheduler.execution.retry',
          correlationId: correlationId,
          causationId: causationId,
          runId: runId,
          workspaceId: workspaceId,
          timestamp: DateTime.now(),
          payload: {
            'executionId': executionId,
            'attempt': attempt,
          },
          meta: const OpsEventMeta(source: 'scheduler'),
        );
}

/// Emitted when an execution is approaching its deadline.
class DeadlineApproachingEvent extends OpsEvent {
  /// The ID of the execution approaching its deadline.
  String get executionId => payload['executionId'] as String;

  /// Remaining time in milliseconds before the deadline.
  int get remainingMs => payload['remainingMs'] as int;

  /// The ID of the associated schedule.
  String? get scheduleId => payload['scheduleId'] as String?;

  /// Deadline timestamp (ISO 8601).
  String? get deadlineAt => payload['deadlineAt'] as String?;

  /// Current escalation level (0 = first warning, increments with each threshold).
  int? get escalationLevel => payload['escalationLevel'] as int?;

  DeadlineApproachingEvent({
    required String executionId,
    required Duration remaining,
    String? scheduleId,
    DateTime? deadlineAt,
    int? escalationLevel,
    required String correlationId,
    required String runId,
    required String workspaceId,
    String? causationId,
  }) : super(
          eventId: OpsEvent.generateEventId(),
          eventType: 'scheduler.execution.deadline_approaching',
          correlationId: correlationId,
          causationId: causationId,
          runId: runId,
          workspaceId: workspaceId,
          timestamp: DateTime.now(),
          payload: {
            'executionId': executionId,
            'remainingMs': remaining.inMilliseconds,
            if (scheduleId != null) 'scheduleId': scheduleId,
            if (deadlineAt != null)
              'deadlineAt': deadlineAt.toIso8601String(),
            if (escalationLevel != null) 'escalationLevel': escalationLevel,
          },
          meta: const OpsEventMeta(source: 'scheduler'),
        );
}

/// Emitted when an execution is cancelled.
class ExecutionCancelledEvent extends OpsEvent {
  /// The ID of the cancelled execution.
  String get executionId => payload['executionId'] as String;

  /// Reason for cancellation.
  String? get reason => payload['reason'] as String?;

  /// Who cancelled the execution.
  String? get cancelledBy => payload['cancelledBy'] as String?;

  ExecutionCancelledEvent({
    required String executionId,
    String? reason,
    String? cancelledBy,
    required String correlationId,
    required String runId,
    required String workspaceId,
    String? causationId,
  }) : super(
          eventId: OpsEvent.generateEventId(),
          eventType: 'scheduler.execution.cancelled',
          correlationId: correlationId,
          causationId: causationId,
          runId: runId,
          workspaceId: workspaceId,
          timestamp: DateTime.now(),
          payload: {
            'executionId': executionId,
            if (reason != null) 'reason': reason,
            if (cancelledBy != null) 'cancelledBy': cancelledBy,
          },
          meta: const OpsEventMeta(source: 'scheduler'),
        );
}

/// Emitted when the execution queue exceeds its capacity.
class QueueOverflowEvent extends OpsEvent {
  /// Current queue size.
  int get currentSize => payload['currentSize'] as int;

  /// Maximum allowed queue size.
  int get maxSize => payload['maxSize'] as int;

  /// Number of items that were rejected or dropped.
  int get droppedCount => payload['droppedCount'] as int;

  QueueOverflowEvent({
    required int currentSize,
    required int maxSize,
    required int droppedCount,
    required String correlationId,
    required String runId,
    required String workspaceId,
    String? causationId,
  }) : super(
          eventId: OpsEvent.generateEventId(),
          eventType: 'scheduler.queue.overflow',
          correlationId: correlationId,
          causationId: causationId,
          runId: runId,
          workspaceId: workspaceId,
          timestamp: DateTime.now(),
          payload: {
            'currentSize': currentSize,
            'maxSize': maxSize,
            'droppedCount': droppedCount,
          },
          meta: const OpsEventMeta(source: 'scheduler'),
        );
}
