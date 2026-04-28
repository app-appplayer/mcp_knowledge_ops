/// Metrics Collector Tests - Tests for MetricsCollector, MetricTimer, sinks,
/// and related metric models.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // MetricsCollector
  // ═══════════════════════════════════════════════════════════════

  group('MetricsCollector', () {
    late InMemoryMetricSink sink;
    late MetricsCollector collector;

    setUp(() {
      sink = InMemoryMetricSink();
      collector = MetricsCollector(sink: sink);
    });

    test('increment() records counter metric', () {
      collector.increment('requests_total');

      expect(sink.metrics.length, equals(1));
      final metric = sink.metrics.first;
      expect(metric.name, equals('requests_total'));
      expect(metric.type, equals(MetricType.counter));
      expect(metric.value, equals(1.0));
    });

    test('increment() with custom value', () {
      collector.increment('bytes_sent', 256);

      expect(sink.metrics.first.value, equals(256.0));
    });

    test('increment() with labels', () {
      collector.increment(
          'requests_total', 1, {'method': 'GET', 'status': '200'});

      final metric = sink.metrics.first;
      expect(metric.labels['method'], equals('GET'));
      expect(metric.labels['status'], equals('200'));
    });

    test('gauge() records gauge metric', () {
      collector.gauge('memory_usage', 1024.5);

      expect(sink.metrics.length, equals(1));
      final metric = sink.metrics.first;
      expect(metric.name, equals('memory_usage'));
      expect(metric.type, equals(MetricType.gauge));
      expect(metric.value, equals(1024.5));
    });

    test('gauge() with labels', () {
      collector.gauge('cpu_usage', 75.0, {'core': '0'});

      final metric = sink.metrics.first;
      expect(metric.labels['core'], equals('0'));
    });

    test('histogram() records histogram metric', () {
      collector.histogram('request_duration', 42.5);

      expect(sink.metrics.length, equals(1));
      final metric = sink.metrics.first;
      expect(metric.name, equals('request_duration'));
      expect(metric.type, equals(MetricType.histogram));
      expect(metric.value, equals(42.5));
    });

    test('histogram() with labels', () {
      collector.histogram('latency', 15.0, {'endpoint': '/api/data'});

      final metric = sink.metrics.first;
      expect(metric.labels['endpoint'], equals('/api/data'));
    });

    test('timer().observeDuration() records duration', () {
      final timer = collector.timer('operation_duration');

      // Let some time pass (minimal)
      timer.observeDuration();

      expect(sink.metrics.length, equals(1));
      final metric = sink.metrics.first;
      expect(metric.name, equals('operation_duration'));
      expect(metric.type, equals(MetricType.histogram));
      expect(metric.value, greaterThanOrEqualTo(0));
    });

    test('recordDuration() records as histogram', () {
      collector.recordDuration(
          'batch_duration', const Duration(milliseconds: 500));

      expect(sink.metrics.length, equals(1));
      final metric = sink.metrics.first;
      expect(metric.name, equals('batch_duration'));
      expect(metric.type, equals(MetricType.histogram));
      expect(metric.value, equals(500.0));
    });

    test('getMetrics() returns all metrics', () {
      collector.increment('counter_a');
      collector.gauge('gauge_b', 10.0);
      collector.histogram('hist_c', 5.0);

      final allMetrics = collector.getMetrics();
      expect(allMetrics.length, equals(3));
    });

    test('getMetrics() with prefix filters', () {
      collector.increment('ops.pipeline.success');
      collector.increment('ops.pipeline.failure');
      collector.gauge('ops.scheduler.depth', 5.0);

      final pipelineMetrics = collector.getMetrics(prefix: 'ops.pipeline');
      expect(pipelineMetrics.length, equals(2));

      final schedulerMetrics = collector.getMetrics(prefix: 'ops.scheduler');
      expect(schedulerMetrics.length, equals(1));
    });

    test('getMetric() returns latest value for named metric', () {
      collector.gauge('temperature', 20.0);
      collector.gauge('temperature', 25.0);
      collector.gauge('temperature', 30.0);

      final value = collector.getMetric('temperature');
      expect(value, equals(30.0));
    });

    test('getMetric() returns null for unknown metric', () {
      final value = collector.getMetric('nonexistent');
      expect(value, isNull);
    });

    test('child() creates collector with additional labels', () {
      final child = collector.child({'service': 'pipeline'});

      child.increment('requests_total');

      final metric = sink.metrics.first;
      expect(metric.labels['service'], equals('pipeline'));
    });

    test('child() inherits parent labels', () {
      final parent = MetricsCollector(
        sink: sink,
        defaultLabels: {'env': 'test'},
      );
      final child = parent.child({'service': 'pipeline'});

      child.increment('requests_total');

      final metric = sink.metrics.first;
      expect(metric.labels['env'], equals('test'));
      expect(metric.labels['service'], equals('pipeline'));
    });

    test('default labels are applied to all metrics', () {
      final labeled = MetricsCollector(
        sink: sink,
        defaultLabels: {'region': 'us-east'},
      );

      labeled.increment('counter');
      labeled.gauge('gauge', 1.0);
      labeled.histogram('hist', 2.0);

      for (final metric in sink.metrics) {
        expect(metric.labels['region'], equals('us-east'));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // MetricTimer
  // ═══════════════════════════════════════════════════════════════

  group('MetricTimer', () {
    late InMemoryMetricSink sink;
    late MetricsCollector collector;

    setUp(() {
      sink = InMemoryMetricSink();
      collector = MetricsCollector(sink: sink);
    });

    test('stop() returns duration', () {
      final timer = collector.timer('op');
      final duration = timer.stop();

      expect(duration, isA<Duration>());
      expect(duration.inMicroseconds, greaterThanOrEqualTo(0));
    });

    test('elapsed returns time without stopping', () {
      final timer = collector.timer('op');
      final elapsed = timer.elapsed;

      expect(elapsed, isA<Duration>());
      expect(timer.isStopped, isFalse);
    });

    test('isStopped reflects state', () {
      final timer = collector.timer('op');
      expect(timer.isStopped, isFalse);

      timer.stop();
      expect(timer.isStopped, isTrue);
    });

    test('timer has correct name and labels', () {
      final timer =
          collector.timer('operation', {'step': 'validate'});

      expect(timer.name, equals('operation'));
      expect(timer.labels['step'], equals('validate'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // InMemoryMetricSink
  // ═══════════════════════════════════════════════════════════════

  group('InMemoryMetricSink', () {
    late InMemoryMetricSink sink;

    setUp(() {
      sink = InMemoryMetricSink();
    });

    test('records metrics', () {
      sink.record(Metric(
        name: 'test',
        type: MetricType.counter,
        value: 1.0,
        timestamp: DateTime.now(),
      ));

      expect(sink.metrics.length, equals(1));
    });

    test('metricsByName() filters correctly', () {
      sink.record(Metric(
        name: 'a',
        type: MetricType.counter,
        value: 1.0,
        timestamp: DateTime.now(),
      ));
      sink.record(Metric(
        name: 'b',
        type: MetricType.gauge,
        value: 2.0,
        timestamp: DateTime.now(),
      ));
      sink.record(Metric(
        name: 'a',
        type: MetricType.counter,
        value: 3.0,
        timestamp: DateTime.now(),
      ));

      final aMetrics = sink.metricsByName('a');
      expect(aMetrics.length, equals(2));
    });

    test('latestValue() returns most recent value', () {
      sink.record(Metric(
        name: 'temp',
        type: MetricType.gauge,
        value: 20.0,
        timestamp: DateTime.now(),
      ));
      sink.record(Metric(
        name: 'temp',
        type: MetricType.gauge,
        value: 25.0,
        timestamp: DateTime.now(),
      ));

      expect(sink.latestValue('temp'), equals(25.0));
    });

    test('latestValue() returns null for unknown metric', () {
      expect(sink.latestValue('nonexistent'), isNull);
    });

    test('sum() sums counter values', () {
      sink.record(Metric(
        name: 'hits',
        type: MetricType.counter,
        value: 5.0,
        timestamp: DateTime.now(),
      ));
      sink.record(Metric(
        name: 'hits',
        type: MetricType.counter,
        value: 3.0,
        timestamp: DateTime.now(),
      ));

      expect(sink.sum('hits'), equals(8.0));
    });

    test('clear() removes all metrics', () {
      sink.record(Metric(
        name: 'test',
        type: MetricType.counter,
        value: 1.0,
        timestamp: DateTime.now(),
      ));
      sink.clear();

      expect(sink.metrics, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Metric
  // ═══════════════════════════════════════════════════════════════

  group('Metric', () {
    test('toJson() serializes correctly', () {
      final metric = Metric(
        name: 'test_metric',
        type: MetricType.gauge,
        value: 42.5,
        labels: {'env': 'prod'},
        timestamp: DateTime(2024, 1, 1),
        unit: 'ms',
        description: 'A test metric',
      );

      final json = metric.toJson();
      expect(json['name'], equals('test_metric'));
      expect(json['type'], equals('gauge'));
      expect(json['value'], equals(42.5));
      expect(json['labels'], equals({'env': 'prod'}));
      expect(json['unit'], equals('ms'));
      expect(json['description'], equals('A test metric'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // HistogramMetric
  // ═══════════════════════════════════════════════════════════════

  group('HistogramMetric', () {
    test('mean calculates correctly', () {
      const histogram = HistogramMetric(
        name: 'latency',
        buckets: [
          HistogramBucket(upperBound: 10, count: 5),
          HistogramBucket(upperBound: 50, count: 10),
          HistogramBucket(upperBound: 100, count: 15),
        ],
        count: 15,
        sum: 750.0,
      );

      expect(histogram.mean, equals(50.0));
    });

    test('mean returns 0 when count is 0', () {
      const histogram = HistogramMetric(
        name: 'empty',
        buckets: [],
        count: 0,
        sum: 0.0,
      );

      expect(histogram.mean, equals(0.0));
    });

    test('toJson() serializes correctly', () {
      const histogram = HistogramMetric(
        name: 'request_duration',
        buckets: [
          HistogramBucket(upperBound: 100, count: 5),
        ],
        count: 5,
        sum: 300.0,
        labels: {'service': 'api'},
      );

      final json = histogram.toJson();
      expect(json['name'], equals('request_duration'));
      expect(json['type'], equals('histogram'));
      expect(json['count'], equals(5));
      expect(json['sum'], equals(300.0));
      expect(json['mean'], equals(60.0));
      expect(json['labels'], equals({'service': 'api'}));
      expect((json['buckets'] as List).length, equals(1));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // HistogramBucket
  // ═══════════════════════════════════════════════════════════════

  group('HistogramBucket', () {
    test('toJson() serializes correctly', () {
      const bucket = HistogramBucket(upperBound: 100.0, count: 42);

      final json = bucket.toJson();
      expect(json['upperBound'], equals(100.0));
      expect(json['count'], equals(42));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // SummaryMetric
  // ═══════════════════════════════════════════════════════════════

  group('SummaryMetric', () {
    test('toJson() serializes correctly', () {
      final summary = SummaryMetric(
        name: 'response_time',
        quantiles: {0.5: 100.0, 0.95: 250.0, 0.99: 500.0},
        count: 1000,
        sum: 120000.0,
        labels: const {'endpoint': '/api'},
      );

      final json = summary.toJson();
      expect(json['name'], equals('response_time'));
      expect(json['type'], equals('summary'));
      expect(json['count'], equals(1000));
      expect(json['sum'], equals(120000.0));
      expect(json['labels'], equals({'endpoint': '/api'}));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // MetricsConfig
  // ═══════════════════════════════════════════════════════════════

  group('MetricsConfig', () {
    test('default values', () {
      const config = MetricsConfig();
      expect(config.enabled, isTrue);
      expect(config.reportingInterval, equals(const Duration(seconds: 60)));
      expect(config.defaultBuckets, isNotEmpty);
      expect(config.maxCardinality, equals(1000));
    });

    test('custom configuration', () {
      const config = MetricsConfig(
        enabled: false,
        reportingInterval: Duration(seconds: 30),
        defaultBuckets: [10, 50, 100],
        maxCardinality: 500,
      );
      expect(config.enabled, isFalse);
      expect(config.reportingInterval, equals(const Duration(seconds: 30)));
      expect(config.defaultBuckets, equals([10, 50, 100]));
      expect(config.maxCardinality, equals(500));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Standard metric constants
  // ═══════════════════════════════════════════════════════════════

  group('Standard metric constants', () {
    // Note: PipelineMetrics, WorkflowMetrics, SchedulerMetrics are hidden
    // from the barrel export. We test via the observability sub-library directly.
    // Since they are hidden in the barrel, we verify the existence of
    // InMemoryMetricSink and MetricsConfig which are exported.

    test('MetricType enum has all values', () {
      expect(MetricType.values.length, equals(4));
      expect(MetricType.values,
          containsAll([MetricType.counter, MetricType.gauge,
              MetricType.histogram, MetricType.summary]));
    });
  });
}
