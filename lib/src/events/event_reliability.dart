/// Event Reliability - Idempotency, causal ordering, circuit breaker, and violation handling.
///
/// Provides reliability guarantees for event-driven operations:
/// - IdempotentHandler: Deduplication via KvStoragePort
/// - CausalOrderEnforcer: Ensures happens-before ordering
/// - EventCircuitBreaker: Protects handlers from cascading failures
/// - OrderingViolationHandler: Graceful handling of out-of-order events
library;

import '../ports/ops_port.dart';
import '../observability/logger.dart';
import '../observability/metrics_collector.dart';
import 'ops_event.dart';
import 'event_subscriber.dart';

// ═══════════════════════════════════════════════════════════════════
// Idempotent Handler
// ═══════════════════════════════════════════════════════════════════

/// Idempotency contract for at-least-once delivery.
class IdempotencyContract {
  IdempotencyContract._();

  /// Idempotency window: 7 days.
  /// Events older than window are rejected on replay.
  static const idempotencyWindow = Duration(days: 7);
}

/// Exception thrown when an event is outside the idempotency window.
class EventExpiredException implements Exception {
  final String message;
  EventExpiredException(this.message);

  @override
  String toString() => 'EventExpiredException: $message';
}

/// Idempotent handler wrapper using KvStoragePort for deduplication state.
/// Key convention: "idempotency:{eventId}"
class IdempotentHandler {
  final EventHandler _handler;
  final KvStoragePort _kvStorage;
  final Duration _window;

  IdempotentHandler(
    this._handler,
    this._kvStorage, {
    Duration window = const Duration(days: 7),
  }) : _window = window;

  /// Handle an event with idempotency guarantee.
  ///
  /// Checks KvStoragePort for prior processing of this eventId.
  /// Rejects events outside the idempotency window.
  Future<void> handle(OpsEvent event) async {
    // Check if already processed via KvStoragePort
    final key = 'idempotency:${event.eventId}';
    final processed = await _kvStorage.get(key);
    if (processed != null) {
      return; // Skip duplicate
    }

    // Check if within idempotency window
    if (DateTime.now().difference(event.timestamp) > _window) {
      throw EventExpiredException(
        'Event ${event.eventId} is outside idempotency window',
      );
    }

    // Process and record
    await _handler(event);
    await _kvStorage.set(
        key, {'processedAt': DateTime.now().toIso8601String()});
  }
}

// ═══════════════════════════════════════════════════════════════════
// Causal Order Enforcer
// ═══════════════════════════════════════════════════════════════════

/// Causal ordering contract for happens-before relationships.
class CausalOrderingContract {
  CausalOrderingContract._();

  /// Rule 1: If event A causes event B, A is delivered before B.
  static const rule1 = 'causation_before_effect';

  /// Rule 2: Events from same source preserve emission order.
  static const rule2 = 'source_order_preserved';

  /// Rule 3: Events with same correlationId are processed in order.
  static const rule3 = 'correlation_order_preserved';
}

/// Causal order enforcer that ensures happens-before relationships.
///
/// Events with causationId are queued until their causing event
/// has been delivered. Events without causationId are delivered immediately.
class CausalOrderEnforcer {
  final Map<String, DateTime> _lastDelivered = {};
  final Map<String, List<OpsEvent>> _pendingEvents = {};

  /// Check if event can be delivered (all causal dependencies met).
  bool canDeliver(OpsEvent event) {
    // No causation = can always deliver
    if (event.causationId == null) return true;

    // Check if causing event was delivered
    return _lastDelivered.containsKey(event.causationId);
  }

  /// Deliver event and record, queueing if dependencies are not met.
  Future<void> deliver(OpsEvent event, EventHandler handler) async {
    if (!canDeliver(event)) {
      // Queue for later delivery
      _pendingEvents
          .putIfAbsent(event.causationId!, () => [])
          .add(event);
      return;
    }

    await handler(event);

    // Record delivery
    _lastDelivered[event.eventId] = DateTime.now();

    // Check if any pending events can now be delivered
    await _deliverPending(event.eventId, handler);
  }

  Future<void> _deliverPending(String eventId, EventHandler handler) async {
    final pending = _pendingEvents.remove(eventId);
    if (pending == null) return;

    // Sort by timestamp and deliver
    pending.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final event in pending) {
      await deliver(event, handler);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// Circuit Breaker
// ═══════════════════════════════════════════════════════════════════

/// Circuit breaker status.
enum CircuitStatus {
  /// Circuit is closed (normal operation).
  closed,

  /// Circuit is open (blocking requests).
  open,

  /// Circuit is half-open (allowing test request).
  halfOpen,
}

/// Circuit breaker state for a handler.
class EventCircuitState {
  /// Current circuit status.
  final CircuitStatus status;

  /// Number of consecutive failures.
  final int failures;

  /// When the circuit should attempt to reset.
  final DateTime? resetAt;

  const EventCircuitState({
    required this.status,
    this.failures = 0,
    this.resetAt,
  });

  /// Create a copy with modifications.
  EventCircuitState copyWith({
    CircuitStatus? status,
    int? failures,
    DateTime? resetAt,
  }) {
    return EventCircuitState(
      status: status ?? this.status,
      failures: failures ?? this.failures,
      resetAt: resetAt ?? this.resetAt,
    );
  }
}

/// Circuit breaker for event handlers.
///
/// Tracks failures per handler and opens the circuit when failures
/// exceed the threshold, preventing cascading failures.
class EventCircuitBreaker {
  /// Number of failures before opening circuit.
  final int failureThreshold;

  /// Duration before attempting to close circuit.
  final Duration resetTimeout;

  final Map<String, EventCircuitState> _states = {};

  EventCircuitBreaker({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(minutes: 1),
  });

  /// Check if handler can execute.
  bool canExecute(String handlerName) {
    final state = _states[handlerName];
    if (state == null) return true;

    switch (state.status) {
      case CircuitStatus.closed:
        return true;
      case CircuitStatus.open:
        // `resetAt` itself counts as elapsed: a zero timeout must half-open
        // at once even on a clock that ticks only every millisecond.
        if (!DateTime.now().isBefore(state.resetAt!)) {
          _states[handlerName] =
              state.copyWith(status: CircuitStatus.halfOpen);
          return true;
        }
        return false;
      case CircuitStatus.halfOpen:
        return true;
    }
  }

  /// Record success for a handler.
  void recordSuccess(String handlerName) {
    final state = _states[handlerName];
    if (state?.status == CircuitStatus.halfOpen) {
      _states[handlerName] =
          const EventCircuitState(status: CircuitStatus.closed);
    }
  }

  /// Record failure for a handler.
  void recordFailure(String handlerName) {
    final state = _states[handlerName] ??
        const EventCircuitState(status: CircuitStatus.closed);

    final newFailures = state.failures + 1;

    if (newFailures >= failureThreshold) {
      _states[handlerName] = EventCircuitState(
        status: CircuitStatus.open,
        failures: newFailures,
        resetAt: DateTime.now().add(resetTimeout),
      );
    } else {
      _states[handlerName] = state.copyWith(failures: newFailures);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// Ordering Violation Handler
// ═══════════════════════════════════════════════════════════════════

/// Types of ordering violations.
enum ViolationType {
  /// Causing event has not been delivered yet.
  missingCause,

  /// Event was already processed (duplicate).
  duplicateEvent,

  /// Event is outside the idempotency window.
  expiredEvent,

  /// Event timestamp is in the future (clock skew).
  futureEvent,
}

/// Describes an ordering violation.
class OrderingViolation {
  /// Type of violation.
  final ViolationType type;

  /// Human-readable details.
  final String details;

  const OrderingViolation(this.type, this.details);
}

/// Action to take when an ordering violation is detected.
sealed class OrderingAction {
  const OrderingAction();

  /// Skip the event (already processed).
  static const skip = SkipAction();

  /// Send to dead letter queue.
  static const dlq = DlqOrderingAction();

  /// Process anyway with a warning.
  static const processWithWarning = ProcessWithWarningAction();

  /// Wait for dependency with timeout, then fallback.
  static WaitWithTimeoutAction waitWithTimeout({
    required Duration timeout,
    required OrderingAction onTimeout,
  }) =>
      WaitWithTimeoutAction(timeout, onTimeout);
}

/// Skip the event.
class SkipAction extends OrderingAction {
  const SkipAction();
}

/// Send event to dead letter queue.
class DlqOrderingAction extends OrderingAction {
  const DlqOrderingAction();
}

/// Process event with warning logged.
class ProcessWithWarningAction extends OrderingAction {
  const ProcessWithWarningAction();
}

/// Wait for dependency with timeout.
class WaitWithTimeoutAction extends OrderingAction {
  /// How long to wait for the dependency.
  final Duration timeout;

  /// Action to take if timeout expires.
  final OrderingAction onTimeout;

  const WaitWithTimeoutAction(this.timeout, this.onTimeout);
}

/// Handles ordering violations gracefully.
///
/// Logs violations, records metrics, and determines the appropriate
/// action based on violation type.
class OrderingViolationHandler {
  /// Logger for violation events.
  final ExecutionLogger logger;

  /// Metrics collector for violation tracking.
  final MetricsCollector metrics;

  OrderingViolationHandler({
    required this.logger,
    required this.metrics,
  });

  /// Called when an out-of-order event is detected.
  Future<OrderingAction> handleViolation(
    OpsEvent event,
    OrderingViolation violation,
  ) async {
    logger.warn('Ordering violation detected', {
      'eventId': event.eventId,
      'violationType': violation.type.name,
      'details': violation.details,
    });

    metrics.increment('events.ordering_violations', 1, {
      'type': violation.type.name,
    });

    switch (violation.type) {
      case ViolationType.missingCause:
        // Wait for causing event with timeout
        return OrderingAction.waitWithTimeout(
          timeout: const Duration(seconds: 30),
          onTimeout: OrderingAction.dlq,
        );

      case ViolationType.duplicateEvent:
        // Already processed, skip
        return OrderingAction.skip;

      case ViolationType.expiredEvent:
        // Too old, send to DLQ for manual review
        return OrderingAction.dlq;

      case ViolationType.futureEvent:
        // Clock skew, process anyway with warning
        return OrderingAction.processWithWarning;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// Ordering Guarantees
// ═══════════════════════════════════════════════════════════════════

/// Ordering semantics within a single event stream.
enum StreamOrdering {
  /// Events are delivered in the order they were published.
  strict,

  /// Events may be delivered out of order for throughput.
  bestEffort,

  /// Events are ordered by causation chain.
  causal,
}

/// Ordering semantics across multiple event streams.
enum CrossStreamOrdering {
  /// No ordering guarantees across streams.
  none,

  /// Events with the same correlationId are ordered.
  correlationOrdered,

  /// Global total order across all streams.
  totalOrder,
}

/// Delivery semantics for event transport.
enum DeliverySemantics {
  /// Each event is delivered at most once (may be lost).
  atMostOnce,

  /// Each event is delivered at least once (may be duplicated).
  atLeastOnce,

  /// Each event is delivered exactly once.
  exactlyOnce,
}

/// Ordering semantics for event consumers.
enum ConsumerOrdering {
  /// Events are processed in FIFO order per consumer.
  fifo,

  /// Events are processed by priority.
  priority,

  /// Events are processed in any order for maximum throughput.
  unordered,
}

/// Declares the ordering and delivery guarantees for an event stream.
///
/// Used to configure the event bus and inform consumers about
/// what ordering and delivery semantics they can rely on.
class OrderingGuarantees {
  /// Ordering within a single stream.
  final StreamOrdering streamOrdering;

  /// Ordering across streams.
  final CrossStreamOrdering crossStreamOrdering;

  /// Delivery semantics.
  final DeliverySemantics deliverySemantics;

  /// Consumer-side ordering.
  final ConsumerOrdering consumerOrdering;

  const OrderingGuarantees({
    this.streamOrdering = StreamOrdering.strict,
    this.crossStreamOrdering = CrossStreamOrdering.correlationOrdered,
    this.deliverySemantics = DeliverySemantics.atLeastOnce,
    this.consumerOrdering = ConsumerOrdering.fifo,
  });

  /// Default guarantees: strict stream ordering, correlation-based
  /// cross-stream ordering, at-least-once delivery, FIFO consumer.
  static const defaults = OrderingGuarantees();

  /// High-throughput profile: relaxed ordering for maximum throughput.
  static const highThroughput = OrderingGuarantees(
    streamOrdering: StreamOrdering.bestEffort,
    crossStreamOrdering: CrossStreamOrdering.none,
    deliverySemantics: DeliverySemantics.atMostOnce,
    consumerOrdering: ConsumerOrdering.unordered,
  );

  /// Strict profile: full ordering guarantees.
  static const strict = OrderingGuarantees(
    streamOrdering: StreamOrdering.strict,
    crossStreamOrdering: CrossStreamOrdering.totalOrder,
    deliverySemantics: DeliverySemantics.exactlyOnce,
    consumerOrdering: ConsumerOrdering.fifo,
  );
}
