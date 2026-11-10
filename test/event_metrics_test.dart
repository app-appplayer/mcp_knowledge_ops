/// EventMetrics Tests
///
/// Tests for EventMetrics: recordPublish, recordRetry, recordDrop,
/// updateDlqSize, updateQueueDepth, registerMetrics, and metricsInterceptor.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

void main() {
  group('EventMetrics', () {
    late MetricsCollector collector;
    late InMemoryMetricSink metricSink;
    late EventMetrics eventMetrics;

    setUp(() {
      final result = testMetrics();
      collector = result.$1;
      metricSink = result.$2;
      eventMetrics = EventMetrics(collector: collector);
    });

    test('recordPublish increments published counter', () {
      eventMetrics.recordPublish('test.event');

      final metrics = metricSink.metricsByName(
        EventMetricNames.eventsPublished,
      );
      expect(metrics, hasLength(1));
      expect(metrics.first.value, equals(1.0));
      expect(metrics.first.labels['event_type'], equals('test.event'));
    });

    test('recordPublish increments for different event types', () {
      eventMetrics.recordPublish('type.a');
      eventMetrics.recordPublish('type.b');
      eventMetrics.recordPublish('type.a');

      final metrics = metricSink.metricsByName(
        EventMetricNames.eventsPublished,
      );
      expect(metrics, hasLength(3));
    });

    test('recordRetry increments retry counter', () {
      eventMetrics.recordRetry('test.event');

      final metrics = metricSink.metricsByName(
        EventMetricNames.eventsRetried,
      );
      expect(metrics, hasLength(1));
      expect(metrics.first.value, equals(1.0));
      expect(metrics.first.labels['event_type'], equals('test.event'));
    });

    test('recordDrop increments dropped counter', () {
      eventMetrics.recordDrop('test.event');

      final metrics = metricSink.metricsByName(
        EventMetricNames.eventsDropped,
      );
      expect(metrics, hasLength(1));
      expect(metrics.first.value, equals(1.0));
    });

    test('updateDlqSize sets gauge value', () {
      eventMetrics.updateDlqSize(42);

      final metrics = metricSink.metricsByName(
        EventMetricNames.dlqSize,
      );
      expect(metrics, hasLength(1));
      expect(metrics.first.value, equals(42.0));
    });

    test('updateQueueDepth sets gauge value', () {
      eventMetrics.updateQueueDepth(10);

      final metrics = metricSink.metricsByName(
        EventMetricNames.queueDepth,
      );
      expect(metrics, hasLength(1));
      expect(metrics.first.value, equals(10.0));
    });

    test('registerMetrics initializes gauges', () {
      eventMetrics.registerMetrics();

      final dlqMetrics = metricSink.metricsByName(
        EventMetricNames.dlqSize,
      );
      final queueMetrics = metricSink.metricsByName(
        EventMetricNames.queueDepth,
      );

      expect(dlqMetrics, hasLength(1));
      expect(dlqMetrics.first.value, equals(0.0));
      expect(queueMetrics, hasLength(1));
      expect(queueMetrics.first.value, equals(0.0));
    });

    test('metricsInterceptor records consumed event on success', () async {
      final event = testOpsEvent(eventType: 'test.interceptor');

      await eventMetrics.metricsInterceptor(event, () async {
        // Simulate successful handler
      });

      final consumed = metricSink.metricsByName(
        EventMetricNames.eventsConsumed,
      );
      expect(consumed, hasLength(1));
      expect(consumed.first.labels['event_type'], equals('test.interceptor'));
      expect(consumed.first.labels['status'], equals('success'));

      // Should also record latency
      final latency = metricSink.metricsByName(
        EventMetricNames.eventLatency,
      );
      expect(latency, hasLength(1));
    });

    test('metricsInterceptor records failed event on error', () async {
      final event = testOpsEvent(eventType: 'test.fail');

      expect(
        () => eventMetrics.metricsInterceptor(event, () async {
          throw StateError('Handler failed');
        }),
        throwsA(isA<StateError>()),
      );

      // Wait for async completion
      await Future<void>.delayed(Duration.zero);

      final failed = metricSink.metricsByName(
        EventMetricNames.eventsFailed,
      );
      expect(failed, hasLength(1));
      expect(failed.first.labels['event_type'], equals('test.fail'));
      expect(failed.first.labels['status'], equals('error'));
    });
  });

  group('EventMetricNames', () {
    test('has expected constant values', () {
      expect(EventMetricNames.eventsPublished, equals('ops.events.published'));
      expect(EventMetricNames.eventsConsumed, equals('ops.events.processed'));
      expect(EventMetricNames.eventsFailed, equals('ops.events.failed'));
      expect(EventMetricNames.eventsRetried, equals('ops.events.retried'));
      expect(
          EventMetricNames.eventLatency, equals('ops.events.processing_time'));
      expect(EventMetricNames.dlqSize, equals('ops.events.dlq.size'));
      expect(EventMetricNames.handlerDuration,
          equals('ops.events.handler.duration'));
      expect(EventMetricNames.eventsDropped, equals('ops.events.dropped'));
      expect(EventMetricNames.queueDepth, equals('ops.events.queue_depth'));
      expect(EventMetricNames.replayCount, equals('ops.events.replay_count'));
    });
  });
}
