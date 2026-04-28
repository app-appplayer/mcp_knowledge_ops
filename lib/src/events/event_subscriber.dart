/// EventSubscriber - Subscribes to OpsEvents from the EventPort.
///
/// Provides stream-based subscriptions, handler-based subscriptions with
/// concurrency control and retry policies, and subscription lifecycle
/// management with statistics tracking.
library;

import 'dart:async';

import '../ports/ops_port.dart';
import '../observability/logger.dart';
import 'ops_event.dart';

/// Handler function for processing an event.
typedef EventHandler = Future<void> Function(OpsEvent event);

/// Retry policy for handler-based subscriptions.
class RetryPolicy {
  /// Maximum number of retry attempts.
  final int maxRetries;

  /// Initial delay before first retry.
  final Duration initialDelay;

  /// Maximum delay cap.
  final Duration maxDelay;

  /// Backoff multiplier applied per retry.
  final double backoffMultiplier;

  const RetryPolicy({
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
  });

  /// Calculate the delay for a given attempt number (1-based).
  Duration delayForAttempt(int attempt) {
    if (attempt <= 1) return initialDelay;

    var delay = initialDelay;
    for (var i = 1; i < attempt; i++) {
      delay = Duration(
        milliseconds: (delay.inMilliseconds * backoffMultiplier).round(),
      );
      if (delay > maxDelay) return maxDelay;
    }
    return delay;
  }
}

/// Statistics for a subscription.
class SubscriptionStats {
  /// Total events received.
  int received;

  /// Events successfully processed.
  int processed;

  /// Events that resulted in errors.
  int errors;

  SubscriptionStats({
    this.received = 0,
    this.processed = 0,
    this.errors = 0,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'received': received,
        'processed': processed,
        'errors': errors,
      };

  @override
  String toString() => 'SubscriptionStats(received: $received, '
      'processed: $processed, errors: $errors)';
}

/// A managed subscription with lifecycle control and statistics.
class Subscription {
  /// Unique subscription identifier.
  final String id;

  /// Event type pattern this subscription matches.
  final String pattern;

  /// Whether the subscription is currently active.
  bool _isActive;

  /// Whether the subscription is paused.
  bool _isPaused;

  /// Subscription statistics.
  final SubscriptionStats stats;

  /// Internal stream subscription for cleanup.
  StreamSubscription<PortEvent>? _streamSubscription;

  /// Cancellation callback.
  final Future<void> Function()? _onCancel;

  Subscription({
    required this.id,
    required this.pattern,
    Future<void> Function()? onCancel,
  })  : _isActive = true,
        _isPaused = false,
        stats = SubscriptionStats(),
        _onCancel = onCancel;

  /// Whether the subscription is active (not cancelled).
  bool get isActive => _isActive;

  /// Whether the subscription is paused.
  bool get isPaused => _isPaused;

  /// Pause the subscription. Events will be buffered by the stream.
  Future<void> pause() async {
    if (!_isActive || _isPaused) return;
    _isPaused = true;
    _streamSubscription?.pause();
  }

  /// Resume a paused subscription.
  Future<void> resume() async {
    if (!_isActive || !_isPaused) return;
    _isPaused = false;
    _streamSubscription?.resume();
  }

  /// Cancel the subscription permanently.
  Future<void> cancel() async {
    if (!_isActive) return;
    _isActive = false;
    _isPaused = false;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    await _onCancel?.call();
  }

  /// Attach the underlying stream subscription for lifecycle management.
  void attachStreamSubscription(StreamSubscription<PortEvent> sub) {
    _streamSubscription = sub;
  }
}

/// Abstract event subscriber contract.
abstract class EventSubscriber {
  /// Subscribe to events matching the given type pattern.
  ///
  /// Returns a stream of [OpsEvent] instances converted from [PortEvent].
  Stream<OpsEvent> subscribe(String typePattern);

  /// Subscribe with a handler function and managed subscription.
  ///
  /// [concurrency] controls how many events can be processed in parallel.
  /// [retryPolicy] configures automatic retry on handler failure.
  Subscription subscribeWithHandler(
    String typePattern,
    EventHandler handler, {
    int concurrency,
    RetryPolicy? retryPolicy,
  });

  /// Unsubscribe and cancel a managed subscription.
  Future<void> unsubscribe(Subscription subscription);
}

/// Concrete subscriber that converts [PortEvent] streams into
/// [OpsEvent] streams with managed subscriptions.
class OpsEventSubscriber implements EventSubscriber {
  /// The underlying event port.
  final EventPort _eventPort;

  /// Logger for subscription operations.
  final ExecutionLogger _logger;

  /// Active managed subscriptions indexed by ID.
  final Map<String, Subscription> _subscriptions = {};

  /// Counter for generating subscription IDs.
  int _nextId = 0;

  OpsEventSubscriber({
    required EventPort eventPort,
    required ExecutionLogger logger,
  })  : _eventPort = eventPort,
        _logger = logger.child('event_subscriber');

  @override
  Stream<OpsEvent> subscribe(String typePattern) {
    _logger.debug('Creating stream subscription', {
      'pattern': typePattern,
    });

    // For exact type subscriptions, delegate directly to EventPort.
    // For wildcard patterns, subscribe to all and filter.
    if (typePattern.contains('*')) {
      return _eventPort.subscribeAll().where((portEvent) {
        return _matchesPattern(portEvent.type, typePattern);
      }).map(_convertPortEvent);
    }

    return _eventPort.subscribe(typePattern).map(_convertPortEvent);
  }

  @override
  Subscription subscribeWithHandler(
    String typePattern,
    EventHandler handler, {
    int concurrency = 1,
    RetryPolicy? retryPolicy,
  }) {
    final subscriptionId = _generateSubscriptionId();
    final subscription = Subscription(
      id: subscriptionId,
      pattern: typePattern,
      onCancel: () async {
        _subscriptions.remove(subscriptionId);
        _logger.debug('Subscription cancelled', {
          'subscriptionId': subscriptionId,
          'pattern': typePattern,
        });
      },
    );

    _subscriptions[subscriptionId] = subscription;

    _logger.info('Creating handler subscription', {
      'subscriptionId': subscriptionId,
      'pattern': typePattern,
      'concurrency': concurrency,
      'hasRetryPolicy': retryPolicy != null,
    });

    // Choose the appropriate port stream based on pattern.
    final Stream<PortEvent> portStream;
    if (typePattern.contains('*')) {
      portStream = _eventPort.subscribeAll().where((portEvent) {
        return _matchesPattern(portEvent.type, typePattern);
      });
    } else {
      portStream = _eventPort.subscribe(typePattern);
    }

    // Semaphore for concurrency control.
    var activeCount = 0;
    final pendingCompleter = <Completer<void>>[];

    final streamSub = portStream.listen(
      (portEvent) {
        if (!subscription.isActive) return;

        subscription.stats.received++;
        final opsEvent = _convertPortEvent(portEvent);

        // Concurrency gate: queue if at max concurrency.
        _executeConcurrently(
          event: opsEvent,
          handler: handler,
          subscription: subscription,
          retryPolicy: retryPolicy,
          concurrency: concurrency,
          activeCount: () => activeCount,
          incrementActive: () => activeCount++,
          decrementActive: () => activeCount--,
          pendingCompleters: pendingCompleter,
        );
      },
      onError: (Object error, StackTrace stack) {
        _logger.error(
          'Subscription stream error',
          error: error,
          context: {'stackTrace': stack.toString()},
        );
      },
    );

    subscription.attachStreamSubscription(streamSub);
    return subscription;
  }

  @override
  Future<void> unsubscribe(Subscription subscription) async {
    _logger.debug('Unsubscribing', {
      'subscriptionId': subscription.id,
      'pattern': subscription.pattern,
      'stats': subscription.stats.toJson(),
    });

    await subscription.cancel();
    _subscriptions.remove(subscription.id);
  }

  /// Get all active subscriptions (for diagnostics).
  List<Subscription> get activeSubscriptions =>
      _subscriptions.values.where((s) => s.isActive).toList();

  /// Cancel all active subscriptions.
  Future<void> cancelAll() async {
    final subs = List<Subscription>.from(_subscriptions.values);
    for (final sub in subs) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }

  /// Convert a port event to an ops event.
  OpsEvent _convertPortEvent(PortEvent portEvent) {
    return OpsEvent.fromPortEvent(portEvent);
  }

  /// Execute handler with concurrency control and optional retry.
  Future<void> _executeConcurrently({
    required OpsEvent event,
    required EventHandler handler,
    required Subscription subscription,
    required RetryPolicy? retryPolicy,
    required int concurrency,
    required int Function() activeCount,
    required void Function() incrementActive,
    required void Function() decrementActive,
    required List<Completer<void>> pendingCompleters,
  }) async {
    // Wait if at max concurrency.
    while (activeCount() >= concurrency) {
      final completer = Completer<void>();
      pendingCompleters.add(completer);
      await completer.future;
    }

    incrementActive();

    try {
      await _handleWithRetry(event, handler, subscription, retryPolicy);
    } finally {
      decrementActive();

      // Release next waiting handler.
      if (pendingCompleters.isNotEmpty) {
        final next = pendingCompleters.removeAt(0);
        if (!next.isCompleted) {
          next.complete();
        }
      }
    }
  }

  /// Execute handler with retry policy.
  Future<void> _handleWithRetry(
    OpsEvent event,
    EventHandler handler,
    Subscription subscription,
    RetryPolicy? retryPolicy,
  ) async {
    final maxAttempts = (retryPolicy?.maxRetries ?? 0) + 1;
    var attempt = 0;

    while (attempt < maxAttempts) {
      attempt++;
      try {
        await handler(event);
        subscription.stats.processed++;
        return;
      } catch (e, stack) {
        if (attempt >= maxAttempts) {
          subscription.stats.errors++;
          _logger.error(
            'Handler failed after all retries',
            error: e,
            context: {'stackTrace': stack.toString()},
          );
          return;
        }

        final delay = retryPolicy!.delayForAttempt(attempt);
        _logger.warn('Handler failed, retrying', {
          'eventId': event.eventId,
          'eventType': event.eventType,
          'attempt': attempt,
          'maxAttempts': maxAttempts,
          'retryDelayMs': delay.inMilliseconds,
          'error': e.toString(),
        });
        await Future<void>.delayed(delay);
      }
    }
  }

  /// Check if an event type matches a wildcard pattern.
  ///
  /// Supports trailing wildcards: 'ops.pipeline.*' matches 'ops.pipeline.started'.
  bool _matchesPattern(String eventType, String pattern) {
    if (pattern == '*') return true;
    if (!pattern.contains('*')) return eventType == pattern;

    // Convert glob pattern to segments for matching.
    final patternSegments = pattern.split('.');
    final typeSegments = eventType.split('.');

    for (var i = 0; i < patternSegments.length; i++) {
      final seg = patternSegments[i];
      if (seg == '*') {
        // Trailing wildcard matches any single segment.
        if (i == patternSegments.length - 1) {
          return typeSegments.length >= i + 1;
        }
        // Intermediate wildcard matches one segment.
        if (i >= typeSegments.length) return false;
        continue;
      }
      if (seg == '**') {
        // Double wildcard matches zero or more segments.
        return true;
      }
      if (i >= typeSegments.length) return false;
      if (seg != typeSegments[i]) return false;
    }

    return typeSegments.length == patternSegments.length;
  }

  /// Generate a unique subscription ID.
  String _generateSubscriptionId() {
    _nextId++;
    final ts = DateTime.now().microsecondsSinceEpoch;
    return 'sub_${ts}_$_nextId';
  }
}
