/// EventReliability Tests
///
/// Tests for IdempotentHandler, CausalOrderEnforcer, EventCircuitBreaker,
/// and OrderingGuarantees from the event reliability module.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

void main() {
  group('IdempotentHandler', () {
    late InMemoryKvStoragePort kvStorage;

    setUp(() {
      kvStorage = InMemoryKvStoragePort();
    });

    test('processes event once and records in KvStorage', () async {
      var processCount = 0;

      final handler = IdempotentHandler(
        (event) async {
          processCount++;
        },
        kvStorage,
      );

      // Use recent timestamp to be within the idempotency window
      final event = OpsEvent(
        eventId: 'evt-idem-1',
        eventType: 'test.idem',
        correlationId: 'corr-1',
        runId: 'run-1',
        workspaceId: 'ws-1',
        timestamp: DateTime.now(),
        payload: {},
        meta: testMeta(),
      );
      await handler.handle(event);

      expect(processCount, equals(1));

      // Verify idempotency key was stored
      final stored = await kvStorage.get('idempotency:evt-idem-1');
      expect(stored, isNotNull);
    });

    test('rejects duplicate event (processes only once)', () async {
      var processCount = 0;

      final handler = IdempotentHandler(
        (event) async {
          processCount++;
        },
        kvStorage,
      );

      // Use recent timestamp to be within the idempotency window
      final event = OpsEvent(
        eventId: 'evt-idem-dup',
        eventType: 'test.idem',
        correlationId: 'corr-1',
        runId: 'run-1',
        workspaceId: 'ws-1',
        timestamp: DateTime.now(),
        payload: {},
        meta: testMeta(),
      );

      // Process first time
      await handler.handle(event);
      expect(processCount, equals(1));

      // Process same event again - should be skipped
      await handler.handle(event);
      expect(processCount, equals(1));
    });

    test('throws EventExpiredException for events outside window', () async {
      final handler = IdempotentHandler(
        (event) async {},
        kvStorage,
        window: const Duration(seconds: 1),
      );

      // Create event with old timestamp (beyond 1 second window)
      final oldEvent = OpsEvent(
        eventId: 'evt-old',
        eventType: 'test.old',
        correlationId: 'corr-1',
        runId: 'run-1',
        workspaceId: 'ws-1',
        timestamp: DateTime.now().subtract(const Duration(seconds: 10)),
        payload: {},
        meta: testMeta(),
      );

      expect(
        () => handler.handle(oldEvent),
        throwsA(isA<EventExpiredException>()),
      );
    });
  });

  group('CausalOrderEnforcer', () {
    late CausalOrderEnforcer enforcer;

    setUp(() {
      enforcer = CausalOrderEnforcer();
    });

    test('canDeliver returns true for event without causationId', () {
      final event = testOpsEvent(eventId: 'evt-1');
      expect(enforcer.canDeliver(event), isTrue);
    });

    test('canDeliver returns false when causing event not yet delivered', () {
      final event = OpsEvent(
        eventId: 'evt-child',
        eventType: 'test.child',
        correlationId: 'corr-1',
        causationId: 'evt-parent',
        runId: 'run-1',
        workspaceId: 'ws-1',
        timestamp: DateTime(2024, 1, 1),
        payload: {},
        meta: testMeta(),
      );

      expect(enforcer.canDeliver(event), isFalse);
    });

    test('deliver queues event when causal dependency not met', () async {
      final delivered = <String>[];

      final child = OpsEvent(
        eventId: 'evt-child',
        eventType: 'test.child',
        correlationId: 'corr-1',
        causationId: 'evt-parent',
        runId: 'run-1',
        workspaceId: 'ws-1',
        timestamp: DateTime(2024, 1, 1),
        payload: {},
        meta: testMeta(),
      );

      // Try to deliver child first - should be queued
      await enforcer.deliver(child, (event) async {
        delivered.add(event.eventId);
      });

      expect(delivered, isEmpty);
    });

    test('deliver processes pending events when dependency arrives', () async {
      final delivered = <String>[];

      final parent = testOpsEvent(eventId: 'evt-parent');
      final child = OpsEvent(
        eventId: 'evt-child',
        eventType: 'test.child',
        correlationId: 'corr-1',
        causationId: 'evt-parent',
        runId: 'run-1',
        workspaceId: 'ws-1',
        timestamp: DateTime(2024, 1, 1),
        payload: {},
        meta: testMeta(),
      );

      Future<void> handler(OpsEvent event) async {
        delivered.add(event.eventId);
      }

      // Deliver child first (queued)
      await enforcer.deliver(child, handler);
      expect(delivered, isEmpty);

      // Deliver parent - should trigger child delivery
      await enforcer.deliver(parent, handler);
      expect(delivered, contains('evt-parent'));
      expect(delivered, contains('evt-child'));
    });
  });

  group('EventCircuitBreaker', () {
    test('closed state allows execution', () {
      final breaker = EventCircuitBreaker(failureThreshold: 3);

      expect(breaker.canExecute('handler-a'), isTrue);
    });

    test('remains closed under threshold', () {
      final breaker = EventCircuitBreaker(failureThreshold: 3);

      breaker.recordFailure('handler-a');
      breaker.recordFailure('handler-a');

      // 2 failures < threshold of 3 - still closed
      expect(breaker.canExecute('handler-a'), isTrue);
    });

    test('transitions to open after threshold failures', () {
      final breaker = EventCircuitBreaker(
        failureThreshold: 3,
        resetTimeout: const Duration(minutes: 5),
      );

      breaker.recordFailure('handler-a');
      breaker.recordFailure('handler-a');
      breaker.recordFailure('handler-a');

      // 3 failures >= threshold of 3 - circuit opens
      expect(breaker.canExecute('handler-a'), isFalse);
    });

    test('recordSuccess in halfOpen state closes the circuit', () {
      final breaker = EventCircuitBreaker(
        failureThreshold: 1,
        // Use zero reset timeout so we immediately transition to halfOpen
        resetTimeout: Duration.zero,
      );

      breaker.recordFailure('handler-a');
      // Circuit is open, but resetTimeout is zero
      // so canExecute should transition to halfOpen and return true
      expect(breaker.canExecute('handler-a'), isTrue);

      breaker.recordSuccess('handler-a');
      // After success in halfOpen, should be closed
      expect(breaker.canExecute('handler-a'), isTrue);
    });

    test('different handlers have independent circuit states', () {
      final breaker = EventCircuitBreaker(failureThreshold: 2);

      breaker.recordFailure('handler-a');
      breaker.recordFailure('handler-a');

      // handler-a should be open
      expect(breaker.canExecute('handler-a'), isFalse);

      // handler-b should still be closed (independent)
      expect(breaker.canExecute('handler-b'), isTrue);
    });
  });

  group('CircuitStatus', () {
    test('has expected values', () {
      expect(CircuitStatus.values, hasLength(3));
      expect(CircuitStatus.values, contains(CircuitStatus.closed));
      expect(CircuitStatus.values, contains(CircuitStatus.open));
      expect(CircuitStatus.values, contains(CircuitStatus.halfOpen));
    });
  });

  group('OrderingGuarantees', () {
    test('defaults preset has expected values', () {
      const defaults = OrderingGuarantees.defaults;
      expect(defaults.streamOrdering, equals(StreamOrdering.strict));
      expect(defaults.crossStreamOrdering,
          equals(CrossStreamOrdering.correlationOrdered));
      expect(defaults.deliverySemantics, equals(DeliverySemantics.atLeastOnce));
      expect(defaults.consumerOrdering, equals(ConsumerOrdering.fifo));
    });

    test('highThroughput preset has relaxed values', () {
      const ht = OrderingGuarantees.highThroughput;
      expect(ht.streamOrdering, equals(StreamOrdering.bestEffort));
      expect(ht.crossStreamOrdering, equals(CrossStreamOrdering.none));
      expect(ht.deliverySemantics, equals(DeliverySemantics.atMostOnce));
      expect(ht.consumerOrdering, equals(ConsumerOrdering.unordered));
    });

    test('strict preset has full ordering guarantees', () {
      const strict = OrderingGuarantees.strict;
      expect(strict.streamOrdering, equals(StreamOrdering.strict));
      expect(
          strict.crossStreamOrdering, equals(CrossStreamOrdering.totalOrder));
      expect(strict.deliverySemantics, equals(DeliverySemantics.exactlyOnce));
      expect(strict.consumerOrdering, equals(ConsumerOrdering.fifo));
    });

    test('custom constructor allows overriding fields', () {
      const custom = OrderingGuarantees(
        streamOrdering: StreamOrdering.causal,
        crossStreamOrdering: CrossStreamOrdering.none,
        deliverySemantics: DeliverySemantics.exactlyOnce,
        consumerOrdering: ConsumerOrdering.priority,
      );

      expect(custom.streamOrdering, equals(StreamOrdering.causal));
      expect(custom.crossStreamOrdering, equals(CrossStreamOrdering.none));
      expect(custom.deliverySemantics, equals(DeliverySemantics.exactlyOnce));
      expect(custom.consumerOrdering, equals(ConsumerOrdering.priority));
    });
  });

  group('EventCircuitState', () {
    test('copyWith creates modified copy', () {
      const state = EventCircuitState(
        status: CircuitStatus.closed,
        failures: 2,
      );

      final opened = state.copyWith(
        status: CircuitStatus.open,
        failures: 3,
        resetAt: DateTime(2024, 6, 1),
      );

      expect(opened.status, equals(CircuitStatus.open));
      expect(opened.failures, equals(3));
      expect(opened.resetAt, equals(DateTime(2024, 6, 1)));

      // Original unchanged
      expect(state.status, equals(CircuitStatus.closed));
      expect(state.failures, equals(2));
    });
  });
}
