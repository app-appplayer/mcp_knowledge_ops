/// Scheduler Tests
///
/// Tests for Scheduler, ScheduledTask, Trigger classes, and related types.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  group('CronTrigger', () {
    test('creates with expression', () {
      final trigger = CronTrigger('0 0 * * *');

      expect(trigger.expression, equals('0 0 * * *'));
      expect(trigger.type, equals(TriggerType.cron));
      expect(trigger.id, contains('cron'));
    });

    test('creates with custom id', () {
      final trigger = CronTrigger('0 0 * * *', id: 'daily-midnight');

      expect(trigger.id, equals('daily-midnight'));
    });

    test('shouldRunAt returns true for matching time', () {
      final trigger = CronTrigger('30 10 * * *');
      final matchingTime = DateTime(2024, 1, 15, 10, 30);

      expect(trigger.shouldRunAt(matchingTime, null), isTrue);
    });

    test('shouldRunAt returns false for non-matching time', () {
      final trigger = CronTrigger('30 10 * * *');
      final nonMatchingTime = DateTime(2024, 1, 15, 11, 30);

      expect(trigger.shouldRunAt(nonMatchingTime, null), isFalse);
    });

    test('shouldRunAt returns false if already ran this minute', () {
      final trigger = CronTrigger('30 10 * * *');
      final now = DateTime(2024, 1, 15, 10, 30);
      final lastRun = DateTime(2024, 1, 15, 10, 30);

      expect(trigger.shouldRunAt(now, lastRun), isFalse);
    });

    test('shouldRunAt with wildcards matches any value', () {
      final trigger = CronTrigger('* * * * *');
      final anyTime = DateTime(2024, 6, 20, 15, 45);

      expect(trigger.shouldRunAt(anyTime, null), isTrue);
    });
  });

  group('EventTrigger', () {
    test('creates with event type', () {
      final trigger = EventTrigger('document_created');

      expect(trigger.eventType, equals('document_created'));
      expect(trigger.type, equals(TriggerType.event));
      expect(trigger.id, contains('event'));
    });

    test('creates with custom id and filter', () {
      final trigger = EventTrigger(
        'document_created',
        id: 'doc-create-trigger',
        filter: EventFilter(
          conditions: {'type': 'pdf'},
        ),
      );

      expect(trigger.id, equals('doc-create-trigger'));
      expect(trigger.filter, isNotNull);
      expect(trigger.filter!.conditions['type'], equals('pdf'));
    });
  });

  group('DeadlineTrigger', () {
    test('creates with deadline source and offset', () {
      final trigger = DeadlineTrigger(
        deadlineSource: DeadlineSource.entityField(
          entityType: 'project',
          field: 'deadline',
        ),
        offset: const Duration(days: 1),
      );

      expect(
          trigger.deadlineSource.type, equals(DeadlineSourceType.entityField));
      expect(trigger.offset.inDays, equals(1));
      expect(trigger.type, equals(TriggerType.deadline));
    });

    test('creates with custom id', () {
      final trigger = DeadlineTrigger(
        deadlineSource: DeadlineSource.schedule('deadline-1'),
        offset: const Duration(hours: 24),
        id: 'reminder-1',
      );

      expect(trigger.id, equals('reminder-1'));
    });
  });

  group('ManualTrigger', () {
    test('creates with default id', () {
      final trigger = ManualTrigger();

      expect(trigger.type, equals(TriggerType.manual));
      expect(trigger.id, equals('manual'));
    });

    test('creates with custom id', () {
      final trigger = ManualTrigger(id: 'manual-test');

      expect(trigger.id, equals('manual-test'));
    });

    test('creates with requiredInputs', () {
      final trigger = ManualTrigger(
        requiredInputs: ['name', 'description'],
      );

      expect(trigger.requiredInputs, equals(['name', 'description']));
    });
  });

  group('CompositeTrigger', () {
    test('creates with resetOnMismatch', () {
      final trigger = CompositeTrigger(
        operator: CompositeOperator.sequence,
        triggers: [
          EventTrigger('event_a'),
          EventTrigger('event_b'),
        ],
        sequenceTimeout: const Duration(hours: 1),
        resetOnMismatch: true,
      );

      expect(trigger.resetOnMismatch, isTrue);
      expect(trigger.operator, equals(CompositeOperator.sequence));
    });
  });

  group('TriggerType', () {
    test('has all expected values', () {
      expect(
          TriggerType.values,
          containsAll([
            TriggerType.cron,
            TriggerType.event,
            TriggerType.deadline,
            TriggerType.manual,
            TriggerType.composite,
          ]));
    });
  });

  group('ScheduledTask', () {
    test('creates with required parameters', () {
      final task = ScheduledTask(
        id: 'task-1',
        trigger: ManualTrigger(),
        action: (_) async {},
        createdAt: DateTime(2024, 1, 1),
      );

      expect(task.id, equals('task-1'));
      expect(task.enabled, isTrue);
      expect(task.lastRunAt, isNull);
    });

    test('copyWith creates modified copy', () {
      final original = ScheduledTask(
        id: 'task-1',
        trigger: ManualTrigger(),
        action: (_) async {},
        createdAt: DateTime(2024, 1, 1),
      );

      final modified = original.copyWith(
        status: ScheduleStatus.disabled,
        lastRunAt: DateTime(2024, 1, 2),
      );

      expect(original.enabled, isTrue);
      expect(modified.enabled, isFalse);
      expect(modified.lastRunAt, equals(DateTime(2024, 1, 2)));
    });
  });

  group('TaskExecution', () {
    test('creates with required parameters', () {
      final execution = TaskExecution(
        taskId: 'task-1',
        triggerId: 'manual',
        status: ExecutionStatus.completed,
        startedAt: DateTime(2024, 1, 1, 10, 0),
        completedAt: DateTime(2024, 1, 1, 10, 5),
      );

      expect(execution.taskId, equals('task-1'));
      expect(execution.status, equals(ExecutionStatus.completed));
      expect(execution.duration?.inMinutes, equals(5));
      expect(execution.error, isNull);
    });

    test('duration returns null when not completed', () {
      final execution = TaskExecution(
        taskId: 'task-1',
        triggerId: 'manual',
        status: ExecutionStatus.running,
        startedAt: DateTime(2024, 1, 1, 10, 0),
      );

      expect(execution.duration, isNull);
    });

    test('toJson serializes correctly', () {
      final execution = TaskExecution(
        taskId: 'task-1',
        triggerId: 'trigger-1',
        status: ExecutionStatus.failed,
        startedAt: DateTime(2024, 1, 1, 10, 0),
        completedAt: DateTime(2024, 1, 1, 10, 1),
        error: 'Task failed',
        output: {'result': 'partial'},
      );

      final json = execution.toJson();

      expect(json['taskId'], equals('task-1'));
      expect(json['status'], equals('failed'));
      expect(json['error'], equals('Task failed'));
      expect(json['output'], containsPair('result', 'partial'));
    });
  });

  group('ExecutionStatus', () {
    test('has all expected values', () {
      expect(
          ExecutionStatus.values,
          containsAll([
            ExecutionStatus.pending,
            ExecutionStatus.running,
            ExecutionStatus.completed,
            ExecutionStatus.failed,
            ExecutionStatus.cancelled,
          ]));
    });
  });

  group('Scheduler', () {
    late Scheduler scheduler;

    setUp(() {
      scheduler = Scheduler();
    });

    tearDown(() {
      scheduler.stop();
    });

    test('starts and stops', () {
      expect(scheduler.isRunning, isFalse);

      scheduler.start();
      expect(scheduler.isRunning, isTrue);

      scheduler.stop();
      expect(scheduler.isRunning, isFalse);
    });

    test('registers task', () {
      scheduler.register(
        taskId: 'test-task',
        trigger: ManualTrigger(),
        action: (_) async {},
      );

      final task = scheduler.getTask('test-task');
      expect(task, isNotNull);
      expect(task!.id, equals('test-task'));
    });

    test('unregisters task', () {
      scheduler.register(
        taskId: 'test-task',
        trigger: ManualTrigger(),
        action: (_) async {},
      );

      scheduler.unregister('test-task');

      expect(scheduler.getTask('test-task'), isNull);
    });

    test('enables and disables task', () {
      scheduler.register(
        taskId: 'test-task',
        trigger: ManualTrigger(),
        action: (_) async {},
        enabled: true,
      );

      scheduler.disable('test-task');
      expect(scheduler.getTask('test-task')!.enabled, isFalse);

      scheduler.enable('test-task');
      expect(scheduler.getTask('test-task')!.enabled, isTrue);
    });

    test('listTasks returns all tasks', () {
      scheduler.register(
        taskId: 'task-1',
        trigger: ManualTrigger(),
        action: (_) async {},
        enabled: true,
      );
      scheduler.register(
        taskId: 'task-2',
        trigger: ManualTrigger(),
        action: (_) async {},
        enabled: false,
      );

      final allTasks = scheduler.listTasks();
      expect(allTasks.length, equals(2));

      final enabledTasks = scheduler.listTasks(enabled: true);
      expect(enabledTasks.length, equals(1));
      expect(enabledTasks.first.id, equals('task-1'));
    });

    test('triggerManually executes task', () async {
      var executed = false;
      scheduler.register(
        taskId: 'test-task',
        trigger: ManualTrigger(),
        action: (_) async {
          executed = true;
        },
      );

      final execution = await scheduler.triggerManually('test-task');

      expect(execution.status, equals(ExecutionStatus.completed));
      expect(executed, isTrue);
    });

    test('triggerManually returns failure for unknown task', () async {
      final execution = await scheduler.triggerManually('unknown-task');

      expect(execution.status, equals(ExecutionStatus.failed));
      expect(execution.error, contains('not found'));
    });

    test('triggerManually handles action failure', () async {
      scheduler.register(
        taskId: 'failing-task',
        trigger: ManualTrigger(),
        action: (_) async {
          throw Exception('Task failed');
        },
      );

      final execution = await scheduler.triggerManually('failing-task');

      expect(execution.status, equals(ExecutionStatus.failed));
      expect(execution.error, contains('Task failed'));
    });

    test('emitEvent triggers subscribed tasks', () async {
      var eventReceived = false;
      Map<String, dynamic>? receivedData;

      scheduler.start();
      scheduler.register(
        taskId: 'event-task',
        trigger: EventTrigger('test_event'),
        action: (data) async {
          eventReceived = true;
          receivedData = data;
        },
      );

      final executions = await scheduler.emitEvent(
        'test_event',
        data: {'key': 'value'},
      );

      expect(executions.length, equals(1));
      expect(eventReceived, isTrue);
      expect(receivedData, containsPair('key', 'value'));
    });

    test('emitEvent returns empty when not running', () async {
      scheduler.register(
        taskId: 'event-task',
        trigger: EventTrigger('test_event'),
        action: (_) async {},
      );

      final executions = await scheduler.emitEvent('test_event');

      expect(executions, isEmpty);
    });

    test('emitEvent skips disabled tasks', () async {
      scheduler.start();
      scheduler.register(
        taskId: 'event-task',
        trigger: EventTrigger('test_event'),
        action: (_) async {},
        enabled: false,
      );

      final executions = await scheduler.emitEvent('test_event');

      expect(executions, isEmpty);
    });
  });

  group('SchedulerMcpTools', () {
    test('allSchemas returns all tool schemas', () {
      final schemas = SchedulerMcpTools.allSchemas();

      expect(schemas.length, equals(8));
      expect(
        schemas.map((s) => s['name']),
        containsAll([
          'scheduler.listSchedules',
          'scheduler.createSchedule',
          'scheduler.pauseSchedule',
          'scheduler.resumeSchedule',
          'scheduler.triggerNow',
          'scheduler.getExecutionStatus',
          'scheduler.cancelExecution',
          'scheduler.getQueueStats',
        ]),
      );
    });
  });
}
