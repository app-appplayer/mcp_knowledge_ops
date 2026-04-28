/// Event Config - Top-level configuration for the event system.
///
/// Defines configuration classes for the event bus, handler execution,
/// EventPort adapter settings, and monitoring/observability features.
library;

/// Top-level event system configuration.
///
/// Aggregates all event subsystem configurations into a single
/// configuration object for initialization.
class EventConfig {
  /// Event bus configuration.
  final EventBusConfig bus;

  /// EventPort adapter configuration.
  final EventPortConfig eventPort;

  /// Handler execution configuration.
  final HandlerConfig handlers;

  /// Monitoring and observability configuration.
  final MonitoringConfig monitoring;

  const EventConfig({
    this.bus = const EventBusConfig(),
    this.eventPort = const EventPortConfig(),
    this.handlers = const HandlerConfig(),
    this.monitoring = const MonitoringConfig(),
  });
}

/// Event bus configuration.
///
/// Controls publishing behavior including concurrency limits,
/// timeouts, and batching settings.
class EventBusConfig {
  /// Maximum number of concurrent publish operations.
  final int maxConcurrentPublish;

  /// Timeout for individual publish operations.
  final Duration publishTimeout;

  /// Whether to enable event batching for throughput.
  final bool enableBatching;

  /// Maximum batch size when batching is enabled.
  final int batchSize;

  /// Time window to collect events before flushing a batch.
  final Duration batchWindow;

  const EventBusConfig({
    this.maxConcurrentPublish = 100,
    this.publishTimeout = const Duration(seconds: 30),
    this.enableBatching = true,
    this.batchSize = 100,
    this.batchWindow = const Duration(milliseconds: 100),
  });
}

/// EventPort adapter configuration.
///
/// Controls how OpsEvents are mapped and delivered through the EventPort.
class EventPortConfig {
  /// Whether to persist events via KvStoragePort after publishing.
  final bool enablePersistence;

  /// Whether to maintain correlation indexes.
  final bool enableCorrelationIndex;

  const EventPortConfig({
    this.enablePersistence = true,
    this.enableCorrelationIndex = true,
  });
}

/// Handler execution configuration.
///
/// Controls handler concurrency, timeouts, retry behavior,
/// and circuit breaker settings.
class HandlerConfig {
  /// Default handler execution timeout.
  final Duration timeout;

  /// Default concurrency for handler executions.
  final int defaultConcurrency;

  /// Default retry policy for failed handlers.
  final DefaultRetryPolicy? defaultRetryPolicy;

  /// Whether to enable the circuit breaker pattern.
  final bool enableCircuitBreaker;

  /// Number of consecutive failures before opening the circuit.
  final int circuitBreakerThreshold;

  /// Duration before attempting to close an open circuit.
  final Duration circuitBreakerResetTimeout;

  const HandlerConfig({
    this.timeout = const Duration(minutes: 5),
    this.defaultConcurrency = 10,
    this.defaultRetryPolicy,
    this.enableCircuitBreaker = true,
    this.circuitBreakerThreshold = 5,
    this.circuitBreakerResetTimeout = const Duration(minutes: 1),
  });
}

/// Default retry policy for event handlers.
class DefaultRetryPolicy {
  /// Maximum retry attempts.
  final int maxAttempts;

  /// Initial delay between retries.
  final Duration initialDelay;

  /// Backoff multiplier.
  final double backoffMultiplier;

  const DefaultRetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
  });
}

/// Monitoring and observability configuration for the event system.
///
/// Controls metrics collection, distributed tracing, and sampling.
class MonitoringConfig {
  /// Whether to enable metrics collection.
  final bool enableMetrics;

  /// Whether to enable distributed tracing.
  final bool enableTracing;

  /// Interval for periodic metrics reporting.
  final Duration metricsInterval;

  /// Sampling rate for tracing (0.0 to 1.0).
  final double samplingRate;

  const MonitoringConfig({
    this.enableMetrics = true,
    this.enableTracing = true,
    this.metricsInterval = const Duration(seconds: 60),
    this.samplingRate = 1.0,
  });
}
