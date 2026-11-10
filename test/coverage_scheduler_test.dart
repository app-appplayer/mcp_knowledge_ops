// Scheduler: models, queue statistics, composite triggers, deadlines,
// concurrency and deduplication, the cron loop, the MCP tools and events.

import 'dart:async';

import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';
import 'package:mcp_knowledge_ops/src/scheduler/scheduler.dart' as sch
    show
        EventBatchConfig,
        EventDebounceConfig,
        EventFilter,
        ExecutionError,
        ExecutionFilter,
        ExecutionMetrics,
        ExecutionRequest,
        ExecutionResult,
        FilterCondition,
        FilterOperator,
        ScheduleRegistration,
        ScheduleRetryConfig,
        SchedulerExecution,
        TriggerInfo;
import 'package:test/test.dart';

class _Deadlines implements DeadlineProvider {
  _Deadlines(this.at);
  final DateTime? at;
  @override
  Future<DateTime?> getDeadline(DeadlineSource source) async => at;
}

PendingExecution _pending(String id, int priority,
        {DateTime? after, DateTime? at}) =>
    PendingExecution(
      id: id,
      scheduleId: 's',
      target: ExecutionTarget(type: TargetType.pipeline, id: 'p'),
      priority: priority,
      enqueuedAt: at ?? DateTime.now(),
      executeAfter: after,
    );

void main() {
  group('configuration and value objects', () {
    test('ScheduleConfig copyWith and json', () {
      const c = ScheduleConfig(tags: ['a'], metadata: {'k': 1});
      final copy = c.copyWith(
          enabled: false,
          priority: 9,
          maxConcurrent: 3,
          deduplicate: true,
          dedupeWindow: const Duration(seconds: 2),
          timeout: const Duration(seconds: 3),
          retryOnFailure: true,
          tags: ['b'],
          metadata: {'z': 2});
      expect(copy.enabled, isFalse);
      expect(copy.priority, 9);
      expect(copy.maxConcurrent, 3);
      expect(copy.tags, ['b']);
      final kept = c.copyWith();
      expect(kept.priority, 5);
      expect(kept.tags, ['a']);
      final json = copy.toJson();
      expect(json['dedupeWindowMs'], 2000);
      expect(json['timeoutMs'], 3000);
      expect(json['tags'], ['b']);
      expect(json['metadata'], {'z': 2});
      expect(const ScheduleConfig().toJson().containsKey('tags'), isFalse);
    });

    test('execution target, pending execution, queue stats, status json', () {
      final withAll = ExecutionTarget(
          type: TargetType.workflow,
          id: 'w',
          input: const {'a': 1},
          config: const {'b': 2});
      expect(withAll.toJson()['input'], {'a': 1});
      expect(withAll.toJson()['config'], {'b': 2});
      expect(ExecutionTarget(type: TargetType.runbook, id: 'r').toJson().length,
          2);

      final now = DateTime.utc(2026);
      expect(_pending('a', 5).isReady(now), isTrue);
      expect(
          _pending('a', 5, after: now.add(const Duration(hours: 1)))
              .isReady(now),
          isFalse);
      expect(_pending('a', 5, after: now).isReady(now), isTrue); // same moment
      final p = PendingExecution(
          id: 'a',
          scheduleId: 's',
          target: ExecutionTarget(type: TargetType.pipeline, id: 'p'),
          enqueuedAt: now,
          executeAfter: now,
          metadata: const {'m': 1});
      expect(p.toJson()['executeAfter'], now.toIso8601String());
      expect(p.toJson()['metadata'], {'m': 1});
      expect(_pending('b', 1).toJson().containsKey('executeAfter'), isFalse);

      final stats = QueueStats(pending: 1, running: 2, completed: 3, failed: 4);
      expect(stats.total, 10);
      expect(stats.toJson()['failed'], 4);

      final status = SchedulerStatus(activeSchedules: 1, lastActivityAt: now);
      expect(status.toJson()['lastActivityAt'], now.toIso8601String());
      expect(SchedulerStatus().toJson().containsKey('lastActivityAt'), isFalse);
    });

    test('schedule aliases and copy', () {
      final s = Schedule(
          id: 's',
          trigger: ManualTrigger(),
          action: (d) async {},
          createdAt: DateTime.utc(2026),
          lastRunAt: DateTime.utc(2026, 2));
      // ignore: deprecated_member_use_from_same_package
      expect(s.taskId, 's');
      expect(s.registeredAt, DateTime.utc(2026));
      expect(s.lastExecutedAt, DateTime.utc(2026, 2));
      expect(s.copyWith(runningCount: 2).runningCount, 2);
    });

    test('event, deadline, escalation and queue value objects', () {
      expect(
          const sch.EventFilter(
              eventType: 'e', source: 's', conditions: {'a': 1}).toJson(),
          {
            'eventType': 'e',
            'source': 's',
            'conditions': {'a': 1}
          });
      expect(const sch.EventFilter().toJson(), isEmpty);
      expect(const sch.EventBatchConfig(enabled: true, maxSize: 3).enabled,
          isTrue);
      expect(
          const sch.EventDebounceConfig().window, const Duration(seconds: 5));
      expect(DeadlineSource.external('http://x').endpoint, 'http://x');
      expect(DeadlineSource.schedule('s').scheduleId, 's');
      expect(
          DeadlineSource.entityField(entityType: 't', field: 'f').field, 'f');
      final action = EscalationAction(type: EscalationActionType.notify);
      final threshold = EscalationThreshold(
          offsetBefore: const Duration(hours: 1), action: action);
      expect(
          EscalationConfig(enabled: true, thresholds: [threshold]).thresholds,
          hasLength(1));
    });

    test('execution manager records', () {
      final t = DateTime.utc(2026);
      final info = sch.TriggerInfo(
          type: 'cron', triggeredAt: t, triggeredBy: 'u', context: const {});
      expect(
          sch.ExecutionRequest(scheduleId: 's', triggeredBy: info, priority: 1)
              .priority,
          1);
      final exec = sch.SchedulerExecution(
          id: 'e',
          scheduleId: 's',
          status: 'queued',
          triggeredBy: info,
          queuedAt: t,
          result: const sch.ExecutionResult(success: true),
          error: const sch.ExecutionError(
              code: 'c', message: 'm', retryable: false),
          metrics: const sch.ExecutionMetrics(totalDuration: Duration.zero));
      expect(exec.result!.success, isTrue);
      expect(const sch.ExecutionFilter(limit: 1).limit, 1);
      expect(
          sch.ScheduleRegistration(
                  schedule: Schedule(
                      id: 's',
                      trigger: ManualTrigger(),
                      action: (d) async {},
                      createdAt: t),
                  isNew: true)
              .isNew,
          isTrue);
      const retry = sch.ScheduleRetryConfig();
      expect(retry.delayForAttempt(0), const Duration(seconds: 1));
      expect(retry.delayForAttempt(3), const Duration(seconds: 4));
      expect(retry.delayForAttempt(40), const Duration(minutes: 5));
      const fc = sch.FilterCondition(
          field: 'f', operator: sch.FilterOperator.eq, value: 1);
      expect(fc.toJson(), {'field': 'f', 'operator': 'eq', 'value': 1});
    });
  });

  group('execution queue', () {
    test('orders by priority, removes, clears, peeks', () {
      final q = ExecutionQueue();
      expect(q.isEmpty, isTrue);
      expect(q.peek(), isNull);
      expect(q.dequeue(), isNull);
      q.enqueue(_pending('low', 1));
      q.enqueue(_pending('high', 9));
      q.enqueue(_pending('mid', 5));
      q.enqueue(_pending('low2', 1));
      expect(q.size, 4);
      expect(q.peek()!.id, 'high');
      expect(q.remove('mid'), isTrue);
      expect(q.remove('nope'), isFalse);
      expect(q.dequeue()!.id, 'high');
      q.clear();
      expect(q.isEmpty, isTrue);
    });

    test('statistics: waits, throughput, errors, reset', () async {
      final q = ExecutionQueue();
      q.enqueue(_pending('a', 5,
          at: DateTime.now().subtract(const Duration(milliseconds: 20))));
      q.enqueue(_pending('b', 5,
          at: DateTime.now().subtract(const Duration(milliseconds: 20))));
      q.dequeue();
      q.dequeue();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      q.recordCompletion(const Duration(milliseconds: 10));
      q.recordFailure(const Duration(milliseconds: 30));
      final s = q.getStats();
      expect(s.completed, 1);
      expect(s.failed, 1);
      expect(s.errorRate, 0.5);
      expect(s.avgExecutionTime, const Duration(milliseconds: 20));
      expect(s.avgWaitTime, greaterThan(Duration.zero));
      expect(s.throughputPerMinute, greaterThan(0));
      q.resetStats();
      final r = q.getStats();
      expect(r.completed, 0);
      expect(r.avgWaitTime, Duration.zero);
      expect(r.throughputPerMinute, 0);
    });
  });

  group('composite triggers', () {
    EventTrigger e(String name) => EventTrigger(name);

    test('and, or and sequence', () async {
      final and = CompositeTrigger(
          operator: CompositeOperator.and, triggers: [e('a'), e('b')]);
      and.recordTriggerFired('event_a');
      expect(and.isSatisfied(), isFalse);
      and.recordTriggerFired('event_b');
      expect(and.isSatisfied(), isTrue);
      and.reset();
      expect(and.isSatisfied(), isFalse);

      final or = CompositeTrigger(
          operator: CompositeOperator.or, triggers: [e('a'), e('b')]);
      expect(or.isSatisfied(), isFalse);
      or.recordTriggerFired('event_b');
      expect(or.isSatisfied(), isTrue);

      final seq = CompositeTrigger(
          operator: CompositeOperator.sequence,
          triggers: [e('a'), e('b')],
          sequenceTimeout: const Duration(milliseconds: 30));
      seq.recordTriggerFired('event_a');
      expect(seq.isSatisfied(), isFalse); // not all fired
      await Future<void>.delayed(const Duration(milliseconds: 2));
      seq.recordTriggerFired('event_b');
      expect(seq.isSatisfied(), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(seq.isSatisfied(), isFalse); // timed out, state reset
      seq.recordTriggerFired('event_b');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      seq.recordTriggerFired('event_a');
      expect(seq.isSatisfied(), isFalse); // fired out of order

      // A sequence of ids that were never recorded (set size matches).
      final other = CompositeTrigger(
          operator: CompositeOperator.sequence, triggers: [e('a'), e('b')]);
      other.recordTriggerFired('event_a');
      other.recordTriggerFired('event_x');
      expect(other.isSatisfied(), isFalse);
    });
  });

  group('scheduler', () {
    late Scheduler s;
    setUp(() {
      s = Scheduler();
      addTearDown(s.stop);
    });

    test('lifecycle: register, enable, disable, pause, resume, list, status',
        () async {
      var runs = 0;
      await s.register(
          taskId: 'a',
          trigger: ManualTrigger(),
          action: (d) async => runs++,
          config: const ScheduleConfig(tags: ['x']));
      await s.register(
          taskId: 'b',
          trigger: ManualTrigger(),
          action: (d) async {},
          enabled: false);
      expect(s.getTask('b')!.status, ScheduleStatus.disabled);
      s.enable('b');
      s.disable('b');
      s.enable('ghost');
      s.disable('ghost');
      await s.pause('a');
      await s.pause('ghost');
      expect(s.getStatus().pausedSchedules, 1);
      await s.resume('a');
      await s.resume('b'); // not paused: unchanged
      await s.resume('ghost');
      expect(s.listTasks(enabled: true).map((t) => t.id), ['a']);
      expect(
          s.listTasks(status: ScheduleStatus.disabled).map((t) => t.id), ['b']);
      expect(s.listTasks(tags: ['x']).map((t) => t.id), ['a']);
      expect(s.listTasks(tags: const []), hasLength(2));
      final ex = await s.triggerManually('a', data: {'k': 1});
      expect(ex.status, ExecutionStatus.completed);
      expect(runs, 1);
      expect(s.getStatus().activeSchedules, 1);
      expect(s.getStatus().lastActivityAt, isNotNull);
      expect((await s.triggerManually('ghost')).error, contains('not found'));
      await s.unregister('a');
      await s.unregister('ghost');
      expect(s.getTask('a'), isNull);
    });

    test('concurrency limit, deduplication, timeout and failure', () async {
      final gate = Completer<void>();
      await s.register(
          taskId: 'slow', trigger: ManualTrigger(), action: (d) => gate.future);
      final first = s.triggerManually('slow');
      await Future<void>.delayed(Duration.zero);
      final second = await s.triggerManually('slow');
      expect(second.status, ExecutionStatus.skippedConcurrency);
      gate.complete();
      await first;

      await s.register(
          taskId: 'dup',
          trigger: ManualTrigger(),
          action: (d) async {},
          config: const ScheduleConfig(
              deduplicate: true, dedupeWindow: Duration(minutes: 1)));
      expect(
          (await s.triggerManually('dup')).status, ExecutionStatus.completed);
      expect((await s.triggerManually('dup')).status,
          ExecutionStatus.skippedDeduplicated);

      await s.register(
          taskId: 'late',
          trigger: ManualTrigger(),
          action: (d) => Completer<void>().future,
          config: const ScheduleConfig(timeout: Duration(milliseconds: 10)));
      expect((await s.triggerManually('late')).status, ExecutionStatus.failed);

      await s.register(
          taskId: 'bad',
          trigger: ManualTrigger(),
          action: (d) async => throw StateError('x'));
      final bad = await s.triggerManually('bad');
      expect(bad.status, ExecutionStatus.failed);
      expect(bad.toJson()['error'], isNotNull);
      expect(bad.duration, isNotNull);
      expect(s.queue.getStats().failed, greaterThan(0));
    });

    test('events reach tasks and composite triggers', () async {
      var hits = 0;
      expect(await s.emitEvent('e'), isEmpty); // not running
      s.start();
      await s.register(
          taskId: 'ev',
          trigger: EventTrigger('e'),
          action: (d) async => hits++);
      await s.register(
          taskId: 'off',
          trigger: EventTrigger('e'),
          action: (d) async => hits += 100,
          enabled: false);
      await s.register(
          taskId: 'both',
          trigger: CompositeTrigger(operator: CompositeOperator.and, triggers: [
            EventTrigger('a'),
            EventTrigger('b'),
            DeadlineTrigger(
                deadlineSource: DeadlineSource.schedule('x'),
                offset: Duration.zero),
          ]),
          action: (d) async => hits += 10);
      expect(await s.emitEvent('e'), hasLength(1));
      expect(hits, 1);
      expect(await s.emitEvent('a'), isEmpty); // composite not yet satisfied
      await s.unregister('both');
      await s.register(
          taskId: 'either',
          trigger: CompositeTrigger(
              operator: CompositeOperator.or, triggers: [EventTrigger('a')]),
          action: (d) async => hits += 10);
      expect(await s.emitEvent('a'), hasLength(1));
      expect(hits, 11);
      await s.unregister('either');
      await s.unregister('ev');
      expect(await s.emitEvent('e'), isEmpty);
    });

    test('deadlines fire inside their window, once', () async {
      var hits = 0;
      final deadline = DateTime.utc(2026, 1, 1, 12);
      await s.register(
          taskId: 'd',
          trigger: DeadlineTrigger(
              deadlineSource: DeadlineSource.external('x'),
              offset: const Duration(hours: 1)),
          action: (d) async => hits++);
      await s.register(
          taskId: 'paused',
          trigger: DeadlineTrigger(
              deadlineSource: DeadlineSource.external('x'),
              offset: const Duration(hours: 1)),
          action: (d) async => hits += 100,
          enabled: false);
      await s.register(
          taskId: 'cron-ignored',
          trigger: CronTrigger('* * * * *'),
          action: (d) async {});
      final now = DateTime.utc(2026, 1, 1, 11, 30);
      expect(
          await s.checkDeadlines(
              now: now, deadlineProvider: _Deadlines(deadline)),
          isEmpty); // scheduler not running
      s.start();
      expect(
          await s.checkDeadlines(now: now, deadlineProvider: _Deadlines(null)),
          isEmpty);
      expect(
          await s.checkDeadlines(
              now: DateTime.utc(2026, 1, 1, 9),
              deadlineProvider: _Deadlines(deadline)),
          isEmpty); // too early
      final fired = await s.checkDeadlines(
          now: now, deadlineProvider: _Deadlines(deadline));
      expect(fired, hasLength(1));
      expect(hits, 1);
      // lastRunAt is "now" (wall clock), after the trigger time, so no repeat.
      expect(
          await s.checkDeadlines(
              now: now, deadlineProvider: _Deadlines(deadline)),
          isEmpty);
    });

    test('the cron loop runs due cron tasks once started', () async {
      var hits = 0;
      await s.register(
          taskId: 'cron',
          trigger: CronTrigger('* * * * *'),
          action: (d) async => hits++);
      await s.register(
          taskId: 'cron-off',
          trigger: CronTrigger('* * * * *'),
          action: (d) async => hits += 100,
          enabled: false);
      await s.register(
          taskId: 'manual',
          trigger: ManualTrigger(),
          action: (d) async => hits += 1000);
      s.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      s.stop();
      expect(hits, 1);
      expect(s.isRunning, isFalse);
    });
  });

  group('MCP tools', () {
    test('every tool dispatches to the scheduler', () async {
      final s = Scheduler();
      await s.register(
          taskId: 'a', trigger: ManualTrigger(), action: (d) async {});
      final listed =
          await SchedulerMcpTools.dispatch('scheduler.listSchedules', {}, s);
      expect((listed['schedules'] as List).single['id'], 'a');
      final filtered = await SchedulerMcpTools.dispatch(
          'scheduler.listSchedules', {'status': 'paused'}, s);
      expect(filtered['schedules'], isEmpty);
      final unknownStatus = await SchedulerMcpTools.dispatch(
          'scheduler.listSchedules', {'status': 'weird'}, s);
      expect((unknownStatus['schedules'] as List), hasLength(1));
      expect(
          await SchedulerMcpTools.dispatch(
              'scheduler.pauseSchedule', {'scheduleId': 'a'}, s),
          {'success': true});
      expect(s.getTask('a')!.status, ScheduleStatus.paused);
      await SchedulerMcpTools.dispatch(
          'scheduler.resumeSchedule', {'scheduleId': 'a'}, s);
      expect(s.getTask('a')!.status, ScheduleStatus.active);
      final trig = await SchedulerMcpTools.dispatch(
          'scheduler.triggerNow',
          {
            'scheduleId': 'a',
            'input': {'k': 1}
          },
          s);
      expect(trig['status'], 'completed');
      final stats =
          await SchedulerMcpTools.dispatch('scheduler.getQueueStats', {}, s);
      expect(stats['stats'], isA<Map>());
      await expectLater(SchedulerMcpTools.dispatch('scheduler.nope', {}, s),
          throwsArgumentError);
    });
  });

  group('scheduler events', () {
    test('payload accessors and optional fields', () {
      ScheduleTriggeredEvent trig(bool all) => ScheduleTriggeredEvent(
          scheduleId: 's',
          executionId: 'e',
          triggerId: all ? 't' : null,
          triggerType: all ? 'cron' : null,
          context: all ? {'k': 1} : null,
          correlationId: 'c',
          runId: 'r',
          workspaceId: 'w');
      expect(trig(true).triggerContext, {'k': 1});
      expect(trig(true).triggerId, 't');
      expect(trig(false).triggerContext, isNull);
      final done = ExecutionCompletedEvent(
          executionId: 'e',
          success: true,
          duration: const Duration(seconds: 1),
          outputSummary: 'ok',
          correlationId: 'c',
          runId: 'r',
          workspaceId: 'w');
      expect(done.outputSummary, 'ok');
      expect(done.durationMs, 1000);
      final approaching = DeadlineApproachingEvent(
          executionId: 'e',
          remaining: const Duration(seconds: 5),
          scheduleId: 's',
          deadlineAt: DateTime.utc(2026),
          escalationLevel: 2,
          correlationId: 'c',
          runId: 'r',
          workspaceId: 'w');
      expect(approaching.scheduleId, 's');
      expect(approaching.deadlineAt, DateTime.utc(2026).toIso8601String());
      expect(approaching.escalationLevel, 2);
      expect(approaching.remainingMs, 5000);
      final cancelled = ExecutionCancelledEvent(
          executionId: 'e',
          reason: 'why',
          cancelledBy: 'u',
          correlationId: 'c',
          runId: 'r',
          workspaceId: 'w');
      expect(cancelled.cancelledBy, 'u');
      expect(cancelled.reason, 'why');
    });
  });
}
