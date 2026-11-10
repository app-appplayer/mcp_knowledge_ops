/// Metrics Collector - Execution metrics for observability.
///
/// Provides metric collection for pipeline and workflow execution.
library;

/// Metrics collector.
class MetricsCollector {
  /// Metric sink.
  final MetricSink _sink;

  /// Default labels.
  final Map<String, String> _defaultLabels;

  MetricsCollector({
    MetricSink? sink,
    Map<String, String>? defaultLabels,
  })  : _sink = sink ?? InMemoryMetricSink(),
        _defaultLabels = defaultLabels ?? {};

  /// Get the underlying metric sink.
  MetricSink get sink => _sink;

  /// Increment a counter.
  void increment(
    String name, [
    double value = 1.0,
    Map<String, String>? labels,
  ]) {
    _sink.record(Metric(
      name: name,
      type: MetricType.counter,
      value: value,
      labels: {..._defaultLabels, ...?labels},
      timestamp: DateTime.now(),
    ));
  }

  /// Set a gauge value.
  void gauge(
    String name,
    double value, [
    Map<String, String>? labels,
  ]) {
    _sink.record(Metric(
      name: name,
      type: MetricType.gauge,
      value: value,
      labels: {..._defaultLabels, ...?labels},
      timestamp: DateTime.now(),
    ));
  }

  /// Record a histogram value.
  void histogram(
    String name,
    double value, [
    Map<String, String>? labels,
  ]) {
    _sink.record(Metric(
      name: name,
      type: MetricType.histogram,
      value: value,
      labels: {..._defaultLabels, ...?labels},
      timestamp: DateTime.now(),
    ));
  }

  /// Start a timer.
  MetricTimer timer(String name, [Map<String, String>? labels]) {
    return MetricTimer(
      name: name,
      labels: {..._defaultLabels, ...?labels},
      collector: this,
    );
  }

  /// Record duration.
  void recordDuration(
    String name,
    Duration duration, [
    Map<String, String>? labels,
  ]) {
    histogram(name, duration.inMilliseconds.toDouble(), labels);
  }

  /// Query all recorded metrics, optionally filtered by name prefix.
  List<Metric> getMetrics({String? prefix}) {
    final sink = _sink;
    if (sink is InMemoryMetricSink) {
      if (prefix == null) return sink.metrics;
      return sink.metrics.where((m) => m.name.startsWith(prefix)).toList();
    }
    return const [];
  }

  /// Query the latest value for a named metric.
  double? getMetric(String name) {
    final sink = _sink;
    if (sink is InMemoryMetricSink) {
      return sink.latestValue(name);
    }
    return null;
  }

  /// Create child collector with additional labels.
  MetricsCollector child(Map<String, String> labels) {
    return MetricsCollector(
      sink: _sink,
      defaultLabels: {..._defaultLabels, ...labels},
    );
  }
}

/// Metric type.
enum MetricType {
  counter,
  gauge,
  histogram,
  summary,
}

/// Metric data point.
class Metric {
  /// Metric name.
  final String name;

  /// Metric type.
  final MetricType type;

  /// Metric value.
  final double value;

  /// Labels.
  final Map<String, String> labels;

  /// Timestamp.
  final DateTime timestamp;

  /// Unit of measurement (e.g. 'ms', 'bytes', 'count').
  final String? unit;

  /// Human-readable description of the metric.
  final String? description;

  const Metric({
    required this.name,
    required this.type,
    required this.value,
    this.labels = const {},
    required this.timestamp,
    this.unit,
    this.description,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'value': value,
        'labels': labels,
        'timestamp': timestamp.toIso8601String(),
        if (unit != null) 'unit': unit,
        if (description != null) 'description': description,
      };
}

/// Metric timer.
class MetricTimer {
  /// Metric name.
  final String name;

  /// Labels.
  final Map<String, String> labels;

  /// Collector.
  final MetricsCollector collector;

  /// Start time.
  final DateTime _startTime;

  /// Stop time.
  DateTime? _stopTime;

  MetricTimer({
    required this.name,
    required this.labels,
    required this.collector,
  }) : _startTime = DateTime.now();

  /// Stop the timer and return duration.
  Duration stop() {
    _stopTime = DateTime.now();
    return _stopTime!.difference(_startTime);
  }

  /// Observe the duration (stops and records).
  void observeDuration() {
    final duration = stop();
    collector.recordDuration(name, duration, labels);
  }

  /// Get elapsed time without stopping.
  Duration get elapsed => DateTime.now().difference(_startTime);

  /// Check if timer is stopped.
  bool get isStopped => _stopTime != null;
}

/// Metric sink interface.
abstract class MetricSink {
  /// Record a metric.
  void record(Metric metric);

  /// Flush buffered metrics.
  Future<void> flush();

  /// Close sink.
  Future<void> close();
}

/// In-memory metric sink for testing.
class InMemoryMetricSink implements MetricSink {
  final List<Metric> _metrics = [];

  /// Get all metrics.
  List<Metric> get metrics => List.unmodifiable(_metrics);

  /// Get metrics by name.
  List<Metric> metricsByName(String name) {
    return _metrics.where((m) => m.name == name).toList();
  }

  /// Get latest value for a metric.
  double? latestValue(String name) {
    final matching = metricsByName(name);
    if (matching.isEmpty) return null;
    return matching.last.value;
  }

  /// Get sum of counter values.
  double sum(String name) {
    return metricsByName(name)
        .where((m) => m.type == MetricType.counter)
        .fold(0.0, (sum, m) => sum + m.value);
  }

  /// Clear metrics.
  void clear() => _metrics.clear();

  @override
  void record(Metric metric) {
    _metrics.add(metric);
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}

// ═══════════════════════════════════════════════════════════════════
// Histogram and Summary Metrics
// ═══════════════════════════════════════════════════════════════════

/// Histogram bucket definition.
class HistogramBucket {
  /// Upper bound for this bucket.
  final double upperBound;

  /// Count of observations in this bucket.
  final int count;

  const HistogramBucket({
    required this.upperBound,
    required this.count,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'upperBound': upperBound,
        'count': count,
      };
}

/// Histogram metric with distribution information.
class HistogramMetric {
  /// Metric name.
  final String name;

  /// Buckets with counts.
  final List<HistogramBucket> buckets;

  /// Total count of observations.
  final int count;

  /// Sum of all observed values.
  final double sum;

  /// Labels.
  final Map<String, String> labels;

  const HistogramMetric({
    required this.name,
    required this.buckets,
    required this.count,
    required this.sum,
    this.labels = const {},
  });

  /// Mean of the observations.
  double get mean => count > 0 ? sum / count : 0.0;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'name': name,
        'type': 'histogram',
        'buckets': buckets.map((b) => b.toJson()).toList(),
        'count': count,
        'sum': sum,
        'mean': mean,
        'labels': labels,
      };
}

/// Summary metric with percentile information.
class SummaryMetric {
  /// Metric name.
  final String name;

  /// Percentile values (e.g. {0.5: 100, 0.95: 250, 0.99: 500}).
  final Map<double, double> quantiles;

  /// Total count of observations.
  final int count;

  /// Sum of all observed values.
  final double sum;

  /// Labels.
  final Map<String, String> labels;

  const SummaryMetric({
    required this.name,
    required this.quantiles,
    required this.count,
    required this.sum,
    this.labels = const {},
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'name': name,
        'type': 'summary',
        'quantiles': quantiles.map((k, v) => MapEntry(k.toString(), v)),
        'count': count,
        'sum': sum,
        'labels': labels,
      };
}

// ═══════════════════════════════════════════════════════════════════
// Metrics Configuration
// ═══════════════════════════════════════════════════════════════════

/// Metrics collection configuration.
class MetricsConfig {
  /// Whether metrics collection is enabled.
  final bool enabled;

  /// Reporting interval for periodic metrics flush.
  final Duration reportingInterval;

  /// Default histogram bucket boundaries.
  final List<double> defaultBuckets;

  /// Maximum number of unique label combinations per metric.
  final int maxCardinality;

  const MetricsConfig({
    this.enabled = true,
    this.reportingInterval = const Duration(seconds: 60),
    this.defaultBuckets = const [
      5,
      10,
      25,
      50,
      100,
      250,
      500,
      1000,
      2500,
      5000,
      10000
    ],
    this.maxCardinality = 1000,
  });
}

// ═══════════════════════════════════════════════════════════════════
// Standard Metrics Constants
// ═══════════════════════════════════════════════════════════════════

/// Standard pipeline metric names.
abstract final class PipelineMetrics {
  static const duration = 'ops.pipeline.duration';
  static const stageCount = 'ops.pipeline.stage_count';
  static const stageDuration = 'ops.pipeline.stage.duration';
  static const successTotal = 'ops.pipeline.success.total';
  static const failureTotal = 'ops.pipeline.failure.total';
  static const retryTotal = 'ops.pipeline.retry.total';
}

/// Standard workflow metric names.
abstract final class WorkflowMetrics {
  static const duration = 'ops.workflow.duration';
  static const stepCount = 'ops.workflow.step_count';
  static const stepDuration = 'ops.workflow.step.duration';
  static const gateEvaluationDuration = 'ops.workflow.gate.duration';
  static const successTotal = 'ops.workflow.success.total';
  static const failureTotal = 'ops.workflow.failure.total';
  static const approvalWaitDuration = 'ops.workflow.approval.wait_duration';
}

/// Standard scheduler metric names.
abstract final class SchedulerMetrics {
  static const scheduledTotal = 'ops.scheduler.scheduled.total';
  static const triggeredTotal = 'ops.scheduler.triggered.total';
  static const missedTotal = 'ops.scheduler.missed.total';
  static const queueDepth = 'ops.scheduler.queue.depth';
  static const executionDuration = 'ops.scheduler.execution.duration';
}
