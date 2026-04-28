/// Tests for scheduler event classes extending OpsEvent.
import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';
import 'package:mcp_knowledge_ops/src/scheduler/scheduler_events.dart';

void main() {
  // Common params for all constructors
  const correlationId = 'corr-1';
  const runId = 'run-1';
  const workspaceId = 'ws-1';

  group('Schedule Lifecycle Events', () {
    test('ScheduleCreatedEvent', () {
      final event = ScheduleCreatedEvent(
        scheduleId: 'sched-1',
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.scheduleId, equals('sched-1'));
      expect(event.eventType, equals('scheduler.schedule.created'));
      expect(event.correlationId, equals(correlationId));
      expect(event.runId, equals(runId));
      expect(event.workspaceId, equals(workspaceId));
    });

    test('ScheduleUpdatedEvent', () {
      final event = ScheduleUpdatedEvent(
        scheduleId: 'sched-1',
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.scheduleId, equals('sched-1'));
      expect(event.eventType, equals('scheduler.schedule.updated'));
    });

    test('ScheduleDeletedEvent', () {
      final event = ScheduleDeletedEvent(
        scheduleId: 'sched-1',
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.scheduleId, equals('sched-1'));
      expect(event.eventType, equals('scheduler.schedule.deleted'));
    });

    test('SchedulePausedEvent', () {
      final event = SchedulePausedEvent(
        scheduleId: 'sched-1',
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.scheduleId, equals('sched-1'));
      expect(event.eventType, equals('scheduler.schedule.paused'));
    });

    test('ScheduleResumedEvent', () {
      final event = ScheduleResumedEvent(
        scheduleId: 'sched-1',
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.scheduleId, equals('sched-1'));
      expect(event.eventType, equals('scheduler.schedule.resumed'));
    });

    test('ScheduleTriggeredEvent', () {
      final event = ScheduleTriggeredEvent(
        scheduleId: 'sched-1',
        executionId: 'exec-1',
        triggerId: 'trig-1',
        triggerType: 'cron',
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.scheduleId, equals('sched-1'));
      expect(event.executionId, equals('exec-1'));
      expect(event.triggerId, equals('trig-1'));
      expect(event.triggerType, equals('cron'));
      expect(event.eventType, equals('scheduler.schedule.triggered'));
    });

    test('ScheduleTriggeredEvent without optional fields', () {
      final event = ScheduleTriggeredEvent(
        scheduleId: 'sched-1',
        executionId: 'exec-1',
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.triggerId, isNull);
      expect(event.triggerType, isNull);
    });

    test('ScheduleMissedEvent', () {
      final missedTime = DateTime(2024, 6, 15, 10, 0);
      final event = ScheduleMissedEvent(
        scheduleId: 'sched-1',
        missedAt: missedTime,
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.scheduleId, equals('sched-1'));
      expect(event.missedAt, equals(missedTime.toIso8601String()));
      expect(event.eventType, equals('scheduler.schedule.missed'));
    });
  });

  group('Execution Lifecycle Events', () {
    test('ExecutionQueuedEvent', () {
      final event = ExecutionQueuedEvent(
        executionId: 'exec-1',
        scheduleId: 'sched-1',
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.executionId, equals('exec-1'));
      expect(event.scheduleId, equals('sched-1'));
      expect(event.eventType, equals('scheduler.execution.queued'));
    });

    test('ExecutionStartedEvent', () {
      final event = ExecutionStartedEvent(
        executionId: 'exec-1',
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.executionId, equals('exec-1'));
      expect(event.eventType, equals('scheduler.execution.started'));
    });

    test('ExecutionCompletedEvent with success', () {
      final event = ExecutionCompletedEvent(
        executionId: 'exec-1',
        success: true,
        duration: const Duration(seconds: 30),
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.executionId, equals('exec-1'));
      expect(event.success, isTrue);
      expect(event.durationMs, equals(30000));
      expect(event.eventType, equals('scheduler.execution.completed'));
    });

    test('ExecutionCompletedEvent without duration', () {
      final event = ExecutionCompletedEvent(
        executionId: 'exec-1',
        success: false,
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.success, isFalse);
      expect(event.durationMs, isNull);
    });

    test('ExecutionFailedEvent', () {
      final event = ExecutionFailedEvent(
        executionId: 'exec-1',
        error: 'Timeout exceeded',
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.executionId, equals('exec-1'));
      expect(event.error, equals('Timeout exceeded'));
      expect(event.eventType, equals('scheduler.execution.failed'));
    });

    test('ExecutionRetryEvent', () {
      final event = ExecutionRetryEvent(
        executionId: 'exec-1',
        attempt: 3,
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.executionId, equals('exec-1'));
      expect(event.attempt, equals(3));
      expect(event.eventType, equals('scheduler.execution.retry'));
    });

    test('DeadlineApproachingEvent', () {
      final event = DeadlineApproachingEvent(
        executionId: 'exec-1',
        remaining: const Duration(minutes: 5),
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.executionId, equals('exec-1'));
      expect(event.remainingMs, equals(300000));
      expect(
        event.eventType,
        equals('scheduler.execution.deadline_approaching'),
      );
    });

    test('ExecutionCancelledEvent', () {
      final event = ExecutionCancelledEvent(
        executionId: 'exec-1',
        reason: 'User requested',
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.executionId, equals('exec-1'));
      expect(event.reason, equals('User requested'));
      expect(event.eventType, equals('scheduler.execution.cancelled'));
    });

    test('ExecutionCancelledEvent without reason', () {
      final event = ExecutionCancelledEvent(
        executionId: 'exec-1',
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.reason, isNull);
    });
  });

  group('Queue Events', () {
    test('QueueOverflowEvent', () {
      final event = QueueOverflowEvent(
        currentSize: 150,
        maxSize: 100,
        droppedCount: 50,
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.currentSize, equals(150));
      expect(event.maxSize, equals(100));
      expect(event.droppedCount, equals(50));
      expect(event.eventType, equals('scheduler.queue.overflow'));
    });
  });

  group('All events extend OpsEvent', () {
    test('events have valid eventId', () {
      final event = ScheduleCreatedEvent(
        scheduleId: 'sched-1',
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
      );

      expect(event.eventId, isNotEmpty);
      expect(event.timestamp, isNotNull);
    });

    test('causationId is optional', () {
      final event = ScheduleCreatedEvent(
        scheduleId: 'sched-1',
        correlationId: correlationId,
        runId: runId,
        workspaceId: workspaceId,
        causationId: 'cause-1',
      );

      expect(event.causationId, equals('cause-1'));
    });
  });
}
