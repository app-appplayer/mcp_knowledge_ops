// Event router, publisher, dead-letter queue, reliability helpers,
// integrations and replay: branches the other event tests do not reach.

import 'dart:async';
import 'dart:async' as da;

import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart' hide RetryPolicy;
import 'package:test/test.dart';

import 'test_helpers.dart';

class _ErroringPort implements EventPort {
  final controller = StreamController<PortEvent>.broadcast();
  @override
  Future<void> publish(PortEvent event) async => controller.add(event);
  @override
  Stream<PortEvent> subscribe(String eventType) => controller.stream;
  @override
  Stream<PortEvent> subscribeAll() => controller.stream;
  @override
  Future<void> unsubscribe(String eventType) async {}
}

class _FailingPort extends MockEventPort {
  _FailingPort(this.failTimes, {this.slow = false});
  int failTimes;
  final bool slow;
  int attempts = 0;
  @override
  Future<void> publish(PortEvent event) async {
    attempts++;
    if (slow) await Future<void>.delayed(const Duration(milliseconds: 50));
    if (failTimes-- > 0) throw StateError('publish failed');
    await super.publish(event);
  }
}

void main() {
  group('router', () {
    late EventRouter router;
    setUp(() => router = EventRouter(logger: testLogger().$1));

    test('patterns: middle wildcards, double wildcards, missing segments',
        () async {
      final hits = <String>[];
      for (final p in ['a.*.c', 'x.**', 'a.b.*', 'q.*.r.*']) {
        router.register(p, (e) async => hits.add('$p<${e.eventType}'));
      }
      Future<int> route(String t) => router.route(testOpsEvent(eventType: t));
      expect(await route('a.b.c'), 2);
      expect(await route('a'), 0); // too short for a middle star
      expect(await route('a.b.c.d'), 0); // too long
      expect(await route('x.y.z'), 1);
      expect(await route('q.s'), 0); // the middle wildcard needs more
      expect(hits, containsAll(['a.*.c<a.b.c', 'a.b.*<a.b.c', 'x.**<x.y.z']));
    });

    test('an interceptor that throws suppresses the event', () async {
      router.addInterceptor((e, next) async => throw StateError('bad'));
      router.register('t', (e) async {});
      expect(await router.route(testOpsEvent(eventType: 't')), 0);
    });
  });

  group('publisher', () {
    late MockEventPort port;
    setUp(() => port = MockEventPort());

    test('records an audit entry before publishing', () async {
      final recorder = InMemoryAuditRecorder();
      final publisher = OpsEventPublisher(
          eventPort: port, logger: testLogger().$1, auditRecorder: recorder);
      await publisher.publish(testOpsEvent(eventType: 'a.b'));
      expect(port.publishedEvents, hasLength(1));
      expect(recorder.events.single.action, 'a.b');
    });

    test('publishWithAck retries failures and timeouts, then gives up',
        () async {
      final failing = _FailingPort(1);
      final ok = OpsEventPublisher(eventPort: failing, logger: testLogger().$1);
      await ok.publishWithAck(testOpsEvent(), maxRetries: 3);
      expect(failing.attempts, 2);

      final timeouts = _FailingPort(0, slow: true);
      final slow =
          OpsEventPublisher(eventPort: timeouts, logger: testLogger().$1);
      await expectLater(
          slow.publishWithAck(testOpsEvent(),
              timeout: const Duration(milliseconds: 5), maxRetries: 2),
          throwsA(isA<da.TimeoutException>()));
      expect(timeouts.attempts, 2);

      final always = _FailingPort(10);
      final bad = OpsEventPublisher(eventPort: always, logger: testLogger().$1);
      await expectLater(
          bad.publishWithAck(testOpsEvent(), maxRetries: 2), throwsStateError);

      await expectLater(
          ok.publishWithAck(testOpsEvent(), maxRetries: 0), throwsStateError);
    });
  });

  group('dead letter queue', () {
    late MockKvStorage kv;
    late MockEventPort port;
    late MockNotificationPort notifications;
    late DeadLetterQueue dlq;
    setUp(() {
      kv = MockKvStorage();
      port = MockEventPort();
      notifications = MockNotificationPort();
      dlq = DeadLetterQueue(
          kvStorage: kv,
          eventPort: port,
          notification: notifications,
          logger: testLogger().$1);
    });

    test('every hundredth entry raises an alert', () async {
      for (var i = 1; i <= 100; i++) {
        await dlq.enqueue(testOpsEvent(eventId: 'e$i'), 'h', StateError('x'),
            StackTrace.empty, 1);
      }
      expect(notifications.sentNotifications, hasLength(1));
      expect(notifications.sentNotifications.single.notificationId,
          'dlq-alert-100');
      expect(await dlq.getPendingCount(), 100);
    });

    test('retry, discard, requeue, and not found', () async {
      await dlq.enqueue(testOpsEvent(eventId: 'a'), 'h', StateError('x'),
          StackTrace.empty, 2);
      final retried = await dlq.process('a', action: DlqAction.retry);
      expect(retried.success, isTrue);
      expect(port.publishedEvents, hasLength(1));
      expect(
          (await dlq.process('a', action: DlqAction.retry)).success, isFalse);

      await dlq.enqueue(testOpsEvent(eventId: 'b'), 'h', StateError('x'),
          StackTrace.empty, 2);
      final requeued = await dlq.process('b', action: DlqAction.requeue);
      expect(requeued.success, isTrue);
      expect((await dlq.process('zz', action: DlqAction.requeue)).success,
          isFalse);
      final discarded =
          await dlq.process('b', action: DlqAction.discard, reason: 'junk');
      expect(discarded.success, isTrue);
    });
  });

  group('reliability', () {
    test('expired exception text', () {
      expect(EventExpiredException('old').toString(),
          'EventExpiredException: old');
      expect(IdempotencyContract.idempotencyWindow, const Duration(days: 7));
      expect(CausalOrderingContract.rule1, isNotEmpty);
    });

    test('a half-open circuit keeps letting calls through', () async {
      final breaker =
          EventCircuitBreaker(failureThreshold: 1, resetTimeout: Duration.zero);
      breaker.recordFailure('h');
      expect(breaker.canExecute('h'), isTrue); // open → half-open at once
      expect(breaker.canExecute('h'), isTrue); // half-open
      breaker.recordSuccess('h'); // closed again
      expect(breaker.canExecute('h'), isTrue);
      breaker.recordSuccess('never-failed');
    });

    test('each ordering violation maps to an action', () async {
      final (metrics, _) = testMetrics();
      final handler =
          OrderingViolationHandler(logger: testLogger().$1, metrics: metrics);
      Future<OrderingAction> act(ViolationType t) =>
          handler.handleViolation(testOpsEvent(), OrderingViolation(t, 'why'));
      final wait = await act(ViolationType.missingCause);
      expect(wait, isA<WaitWithTimeoutAction>());
      expect(
          (wait as WaitWithTimeoutAction).timeout, const Duration(seconds: 30));
      expect(wait.onTimeout, isA<DlqOrderingAction>());
      expect(await act(ViolationType.duplicateEvent), isA<SkipAction>());
      expect(await act(ViolationType.expiredEvent), isA<DlqOrderingAction>());
      expect(await act(ViolationType.futureEvent),
          isA<ProcessWithWarningAction>());
    });
  });

  group('integrations', () {
    test('fact graph updates cascade when dependents exist', () async {
      final facts = MockFactsPort()
        ..queryResult = [
          FactRecord(
              id: 'dep',
              workspaceId: 'w',
              type: 't',
              content: const {},
              createdAt: DateTime.utc(2026))
        ];
      final port = MockEventPort();
      final publisher =
          OpsEventPublisher(eventPort: port, logger: testLogger().$1);
      final integration =
          FactGraphEventIntegration(publisher: publisher, facts: facts);

      expect(
          await integration.withEvent(
              operationName: 'op',
              entityId: 'e',
              runId: 'r',
              workspaceId: 'w',
              operation: () async => 7),
          7);
      expect(port.publishedEvents, hasLength(1));

      await integration
          .onFactGraphUpdated(testOpsEvent(payload: {'factId': 'f'}));
      expect(port.publishedEvents, hasLength(2));
      await integration
          .onFactGraphUpdated(testOpsEvent(payload: {})); // no fact id
      expect(port.publishedEvents, hasLength(2));

      facts.queryResult = [];
      await integration
          .onFactGraphUpdated(testOpsEvent(payload: {'factId': 'f'}));
      expect(port.publishedEvents, hasLength(2)); // no dependents
      await FactGraphEventIntegration(facts: facts)
          .onFactGraphUpdated(testOpsEvent(payload: {'factId': 'f'}));
      await FactGraphEventIntegration().onFactGraphUpdated(testOpsEvent());
      expect(
          await FactGraphEventIntegration().withEvent(
              operationName: 'o',
              entityId: 'e',
              runId: 'r',
              workspaceId: 'w',
              operation: () async => 1),
          1);

      final router = EventRouter(logger: testLogger().$1);
      integration.registerHandlers(router);
      expect(router.registeredPatterns,
          contains('ops.integration.factgraph_updated'));
    });

    test('notifications for approvals, failures and completions', () async {
      final notifications = MockNotificationPort();
      final handlers = NotificationEventHandlers(notification: notifications);
      for (final t in [
        'ops.workflow.approval_requested',
        'ops.execution.failed',
        'ops.pipeline.failed',
        'ops.workflow.failed',
        'ops.workflow.completed',
        'ops.something.else',
      ]) {
        await handlers.onNotificationRequired(testOpsEvent(
            eventType: t, payload: {'workflowId': 'w', 'error': 'e'}));
      }
      expect(notifications.sentNotifications, hasLength(5));
      await handlers.onNotificationRequired(
          testOpsEvent(eventType: 'ops.execution.failed'));
      expect(
          notifications.sentNotifications.last.body, contains('Unknown error'));
      await NotificationEventHandlers().onNotificationRequired(
          testOpsEvent(eventType: 'ops.execution.failed'));
      final router = EventRouter(logger: testLogger().$1);
      handlers.registerHandlers(router);
      expect(router.registeredPatterns, hasLength(5));
    });
  });

  group('subscriber stream errors', () {
    test('a stream error is logged, not thrown', () async {
      final port = _ErroringPort();
      final (logger, sink) = testLogger();
      final subscriber = OpsEventSubscriber(eventPort: port, logger: logger);
      subscriber.subscribeWithHandler('e', (e) async {});
      port.controller.addError(StateError('stream broke'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
          sink.entries
              .any((e) => e.message.contains('Subscription stream error')),
          isTrue);
      await subscriber.cancelAll();
    });
  });

  group('replay', () {
    late MockKvStorage kv;
    late EventPersister persister;
    late EventRouter router;
    late EventReplayer replayer;
    final stream = EventStreams.execution('x1');

    OpsEvent at(int day, {String type = 't', String id = ''}) => OpsEvent(
        eventId: id.isEmpty ? 'e$day' : id,
        eventType: type,
        correlationId: 'c',
        runId: 'r',
        workspaceId: 'w',
        timestamp: DateTime.utc(2026, 1, day),
        payload: const {},
        meta: const OpsEventMeta(source: 's'));

    setUp(() async {
      kv = MockKvStorage();
      persister = EventPersister(kvStorage: kv);
      router = EventRouter(logger: testLogger().$1);
      replayer =
          EventReplayer(kvStorage: kv, router: router, logger: testLogger().$1);
      for (final d in [1, 2, 3]) {
        await persister.persist(stream, at(d));
      }
    });

    test('replays every event through the router', () async {
      final seen = <String>[];
      router.register('t', (e) async => seen.add(e.eventId));
      final r = await replayer.replayExecution('x1');
      expect(r.totalEvents, 3);
      expect(r.replayedEvents, 3);
      expect(seen, ['e1', 'e2', 'e3']);
      expect(r.results.every((x) => x.isSuccess), isTrue);
    });

    test('from a position and inside a time window; missing log entries skip',
        () async {
      final seen = <String>[];
      router.register('t', (e) async => seen.add(e.eventId));
      final fromPos = await replayer.replayExecution('x1', fromPosition: 2);
      expect(fromPos.replayedEvents, 2);
      seen.clear();
      final window = await replayer.replayExecution('x1',
          fromTimestamp: DateTime.utc(2026, 1, 2),
          toTimestamp: DateTime.utc(2026, 1, 2, 12));
      expect(seen, ['e2']);
      expect(window.skippedEvents, 2);
      await kv.remove(EventStorageKeys.eventLog(stream, 2));
      final gap = await replayer.replayExecution('x1');
      expect(gap.skippedEvents, 1);
      expect((await replayer.replayExecution('nothing')).totalEvents, 0);
    });

    test('a dry run invokes nothing; a failing handler is recorded', () async {
      var calls = 0;
      router.register('t', (e) async {
        calls++;
        throw StateError('handler broke');
      });
      final dry = await replayer.replayExecution('x1', dryRun: true);
      expect(calls, 0);
      expect(dry.replayedEvents, 3);
      router.addInterceptor((e, next) async => throw StateError('hard'));
      final failed = await replayer.replayExecution('x1');
      expect(failed.results.length, 3);
    });
  });
}
