/// Event Metrics - Metrics collection for the event system.
///
/// Provides metric names, interceptor-based metric capture, and
/// integration with the [MetricsCollector] for event observability.
library;

import 'ops_event.dart';
import '../observability/metrics_collector.dart';

/// Standard metric names for the event system.
///
/// These constants define the canonical metric names used throughout
/// the event architecture for consistent observability.
abstract final class EventMetricNames {
  /// Total events published.
  static const String eventsPublished = 'ops.events.published';

  /// Total events consumed/processed.
  static const String eventsConsumed = 'ops.events.processed';

  /// Total events that failed processing.
  static const String eventsFailed = 'ops.events.failed';

  /// Total events retried after failure.
  static const String eventsRetried = 'ops.events.retried';

  /// Event processing latency in milliseconds.
  static const String eventLatency = 'ops.events.processing_time';

  /// Dead letter queue size.
  static const String dlqSize = 'ops.events.dlq.size';

  /// Handler execution duration in milliseconds.
  static const String handlerDuration = 'ops.events.handler.duration';

  /// Total events dropped (unroutable or suppressed).
  static const String eventsDropped = 'ops.events.dropped';

  /// Event queue depth.
  static const String queueDepth = 'ops.events.queue_depth';

  /// Event replay count.
  static const String replayCount = 'ops.events.replay_count';
}

/// Metrics collection for the event system.
///
/// Wraps a [MetricsCollector] to provide event-specific metric recording
/// and an interceptor that can be registered on the [EventRouter].
class EventMetrics {
  /// The underlying metrics collector.
  final MetricsCollector _collector;

  EventMetrics({required MetricsCollector collector}) : _collector = collector;

  /// Register standard event system metrics with the collector.
  ///
  /// Initializes gauge values and sets up the metrics namespace.
  void registerMetrics() {
    _collector.gauge(EventMetricNames.dlqSize, 0);
    _collector.gauge(EventMetricNames.queueDepth, 0);
  }

  /// Interceptor that captures metrics for each event processed.
  ///
  /// Designed to be registered with [EventRouter.addInterceptor].
  /// Records processing count, timing, and success/failure status.
  Future<void> metricsInterceptor(
    OpsEvent event,
    Future<void> Function() next,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      await next();

      _collector.increment(EventMetricNames.eventsConsumed, 1, {
        'event_type': event.eventType,
        'status': 'success',
      });
    } catch (e) {
      _collector.increment(EventMetricNames.eventsFailed, 1, {
        'event_type': event.eventType,
        'status': 'error',
      });
      rethrow;
    } finally {
      stopwatch.stop();
      _collector.histogram(
        EventMetricNames.eventLatency,
        stopwatch.elapsedMilliseconds.toDouble(),
        {'event_type': event.eventType},
      );
    }
  }

  /// Record a publish event.
  void recordPublish(String eventType) {
    _collector.increment(EventMetricNames.eventsPublished, 1, {
      'event_type': eventType,
    });
  }

  /// Record a retry attempt.
  void recordRetry(String eventType) {
    _collector.increment(EventMetricNames.eventsRetried, 1, {
      'event_type': eventType,
    });
  }

  /// Record an event being dropped.
  void recordDrop(String eventType) {
    _collector.increment(EventMetricNames.eventsDropped, 1, {
      'event_type': eventType,
    });
  }

  /// Update the DLQ size gauge.
  void updateDlqSize(int size) {
    _collector.gauge(EventMetricNames.dlqSize, size.toDouble());
  }

  /// Update the queue depth gauge.
  void updateQueueDepth(int depth) {
    _collector.gauge(EventMetricNames.queueDepth, depth.toDouble());
  }
}
