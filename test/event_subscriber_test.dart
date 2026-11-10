/// Tests for OpsEventSubscriber, Subscription, SubscriptionStats, and RetryPolicy.
///
/// Covers subscription creation, lifecycle management,
/// stats tracking, backoff calculation, and cancelAll.
library;

import 'package:test/test.dart';

import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart' hide RetryPolicy;
// RetryPolicy is hidden from the barrel; import directly.
import 'package:mcp_knowledge_ops/src/events/event_subscriber.dart';

import 'test_helpers.dart';

void main() {
  group('SubscriptionStats', () {
    test('defaults to zero counts', () {
      final stats = SubscriptionStats();

      expect(stats.received, equals(0));
      expect(stats.processed, equals(0));
      expect(stats.errors, equals(0));
    });

    test('toJson serializes all fields', () {
      final stats = SubscriptionStats(
        received: 10,
        processed: 8,
        errors: 2,
      );

      final json = stats.toJson();

      expect(json['received'], equals(10));
      expect(json['processed'], equals(8));
      expect(json['errors'], equals(2));
    });

    test('toString includes all counts', () {
      final stats = SubscriptionStats(
        received: 5,
        processed: 4,
        errors: 1,
      );

      final str = stats.toString();

      expect(str, contains('received: 5'));
      expect(str, contains('processed: 4'));
      expect(str, contains('errors: 1'));
    });

    test('tracks mutable counts', () {
      final stats = SubscriptionStats();

      stats.received++;
      stats.received++;
      stats.processed++;
      stats.errors++;

      expect(stats.received, equals(2));
      expect(stats.processed, equals(1));
      expect(stats.errors, equals(1));
    });
  });

  group('RetryPolicy', () {
    test('has sensible defaults', () {
      const policy = RetryPolicy();

      expect(policy.maxRetries, equals(3));
      expect(policy.initialDelay, equals(const Duration(milliseconds: 500)));
      expect(policy.maxDelay, equals(const Duration(seconds: 30)));
      expect(policy.backoffMultiplier, equals(2.0));
    });

    test('delayForAttempt returns initialDelay for attempt 1', () {
      const policy = RetryPolicy(
        initialDelay: Duration(milliseconds: 100),
      );

      expect(
          policy.delayForAttempt(1), equals(const Duration(milliseconds: 100)));
    });

    test('delayForAttempt calculates exponential backoff', () {
      const policy = RetryPolicy(
        initialDelay: Duration(milliseconds: 100),
        backoffMultiplier: 2.0,
        maxDelay: Duration(seconds: 60),
      );

      // attempt 1 => 100ms
      expect(
          policy.delayForAttempt(1), equals(const Duration(milliseconds: 100)));
      // attempt 2 => 100 * 2 = 200ms
      expect(
          policy.delayForAttempt(2), equals(const Duration(milliseconds: 200)));
      // attempt 3 => 200 * 2 = 400ms
      expect(
          policy.delayForAttempt(3), equals(const Duration(milliseconds: 400)));
    });

    test('delayForAttempt caps at maxDelay', () {
      const policy = RetryPolicy(
        initialDelay: Duration(seconds: 10),
        backoffMultiplier: 3.0,
        maxDelay: Duration(seconds: 30),
      );

      // attempt 2 => 10 * 3 = 30s (equals max)
      expect(policy.delayForAttempt(2), equals(const Duration(seconds: 30)));
      // attempt 3 => would be 90s, but capped at 30s
      expect(policy.delayForAttempt(3), equals(const Duration(seconds: 30)));
    });

    test('delayForAttempt returns initialDelay for attempt <= 1', () {
      const policy = RetryPolicy(
        initialDelay: Duration(milliseconds: 500),
      );

      expect(
          policy.delayForAttempt(0), equals(const Duration(milliseconds: 500)));
      expect(policy.delayForAttempt(-1),
          equals(const Duration(milliseconds: 500)));
    });
  });

  group('Subscription', () {
    test('starts active and not paused', () {
      final sub = Subscription(
        id: 'sub-1',
        pattern: 'ops.pipeline.*',
      );

      expect(sub.isActive, isTrue);
      expect(sub.isPaused, isFalse);
      expect(sub.id, equals('sub-1'));
      expect(sub.pattern, equals('ops.pipeline.*'));
    });

    test('lifecycle: active -> paused -> resumed -> cancelled', () async {
      final sub = Subscription(
        id: 'sub-lifecycle',
        pattern: 'test.pattern',
      );

      // Active
      expect(sub.isActive, isTrue);
      expect(sub.isPaused, isFalse);

      // Pause
      await sub.pause();
      expect(sub.isActive, isTrue);
      expect(sub.isPaused, isTrue);

      // Resume
      await sub.resume();
      expect(sub.isActive, isTrue);
      expect(sub.isPaused, isFalse);

      // Cancel
      await sub.cancel();
      expect(sub.isActive, isFalse);
      expect(sub.isPaused, isFalse);
    });

    test('pause is idempotent when already paused', () async {
      final sub = Subscription(id: 'sub-2', pattern: 'test.*');

      await sub.pause();
      await sub.pause(); // should be no-op

      expect(sub.isPaused, isTrue);
    });

    test('resume is idempotent when not paused', () async {
      final sub = Subscription(id: 'sub-3', pattern: 'test.*');

      await sub.resume(); // should be no-op, not paused

      expect(sub.isPaused, isFalse);
    });

    test('cancel is idempotent when already cancelled', () async {
      final sub = Subscription(id: 'sub-4', pattern: 'test.*');

      await sub.cancel();
      await sub.cancel(); // should be no-op

      expect(sub.isActive, isFalse);
    });

    test('pause after cancel is no-op', () async {
      final sub = Subscription(id: 'sub-5', pattern: 'test.*');

      await sub.cancel();
      await sub.pause();

      expect(sub.isActive, isFalse);
      expect(sub.isPaused, isFalse);
    });

    test('stats are initialized to zero', () {
      final sub = Subscription(id: 'sub-6', pattern: 'test.*');

      expect(sub.stats.received, equals(0));
      expect(sub.stats.processed, equals(0));
      expect(sub.stats.errors, equals(0));
    });

    test('onCancel callback is invoked on cancel', () async {
      var cancelled = false;
      final sub = Subscription(
        id: 'sub-7',
        pattern: 'test.*',
        onCancel: () async {
          cancelled = true;
        },
      );

      await sub.cancel();

      expect(cancelled, isTrue);
    });
  });

  group('OpsEventSubscriber', () {
    late MockEventPort eventPort;
    late ExecutionLogger logger;
    late OpsEventSubscriber subscriber;

    setUp(() {
      eventPort = MockEventPort();
      final loggerPair = testLogger();
      logger = loggerPair.$1;
      subscriber = OpsEventSubscriber(
        eventPort: eventPort,
        logger: logger,
      );
    });

    test('subscribe returns a stream', () {
      final stream = subscriber.subscribe('ops.pipeline.started');

      expect(stream, isA<Stream<OpsEvent>>());
    });

    test('subscribeWithHandler creates a managed subscription', () {
      final sub = subscriber.subscribeWithHandler(
        'ops.pipeline.*',
        (event) async {},
      );

      expect(sub, isA<Subscription>());
      expect(sub.isActive, isTrue);
      expect(sub.pattern, equals('ops.pipeline.*'));
    });

    test('activeSubscriptions tracks active subscriptions', () {
      subscriber.subscribeWithHandler('pattern-1', (event) async {});
      subscriber.subscribeWithHandler('pattern-2', (event) async {});

      expect(subscriber.activeSubscriptions, hasLength(2));
    });

    test('cancelAll cancels all subscriptions', () async {
      final sub1 = subscriber.subscribeWithHandler('p-1', (event) async {});
      final sub2 = subscriber.subscribeWithHandler('p-2', (event) async {});

      await subscriber.cancelAll();

      expect(sub1.isActive, isFalse);
      expect(sub2.isActive, isFalse);
      expect(subscriber.activeSubscriptions, isEmpty);
    });

    test('unsubscribe cancels specific subscription', () async {
      final sub = subscriber.subscribeWithHandler('p-1', (event) async {});

      await subscriber.unsubscribe(sub);

      expect(sub.isActive, isFalse);
    });
  });
}
