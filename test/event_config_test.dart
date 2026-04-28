/// EventConfig Tests
///
/// Tests for EventConfig and its nested configuration classes:
/// EventBusConfig, EventPortConfig, HandlerConfig, DefaultRetryPolicy,
/// and MonitoringConfig, verifying their default values.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  group('EventConfig', () {
    test('default constructor uses default sub-configs', () {
      const config = EventConfig();
      expect(config.bus, isA<EventBusConfig>());
      expect(config.eventPort, isA<EventPortConfig>());
      expect(config.handlers, isA<HandlerConfig>());
      expect(config.monitoring, isA<MonitoringConfig>());
    });
  });

  group('EventBusConfig', () {
    test('defaults are correct', () {
      const config = EventBusConfig();
      expect(config.maxConcurrentPublish, equals(100));
      expect(config.publishTimeout, equals(const Duration(seconds: 30)));
      expect(config.enableBatching, isTrue);
      expect(config.batchSize, equals(100));
      expect(config.batchWindow,
          equals(const Duration(milliseconds: 100)));
    });

    test('custom values override defaults', () {
      const config = EventBusConfig(
        maxConcurrentPublish: 50,
        publishTimeout: Duration(seconds: 10),
        enableBatching: false,
        batchSize: 200,
        batchWindow: Duration(milliseconds: 500),
      );

      expect(config.maxConcurrentPublish, equals(50));
      expect(config.publishTimeout, equals(const Duration(seconds: 10)));
      expect(config.enableBatching, isFalse);
      expect(config.batchSize, equals(200));
      expect(config.batchWindow,
          equals(const Duration(milliseconds: 500)));
    });
  });

  group('EventPortConfig', () {
    test('defaults are correct', () {
      const config = EventPortConfig();
      expect(config.enablePersistence, isTrue);
      expect(config.enableCorrelationIndex, isTrue);
    });

    test('custom values override defaults', () {
      const config = EventPortConfig(
        enablePersistence: false,
        enableCorrelationIndex: false,
      );

      expect(config.enablePersistence, isFalse);
      expect(config.enableCorrelationIndex, isFalse);
    });
  });

  group('HandlerConfig', () {
    test('defaults are correct', () {
      const config = HandlerConfig();
      expect(config.timeout, equals(const Duration(minutes: 5)));
      expect(config.defaultConcurrency, equals(10));
      expect(config.defaultRetryPolicy, isNull);
      expect(config.enableCircuitBreaker, isTrue);
      expect(config.circuitBreakerThreshold, equals(5));
      expect(config.circuitBreakerResetTimeout,
          equals(const Duration(minutes: 1)));
    });

    test('custom values override defaults', () {
      const config = HandlerConfig(
        timeout: Duration(seconds: 30),
        defaultConcurrency: 5,
        defaultRetryPolicy: DefaultRetryPolicy(maxAttempts: 5),
        enableCircuitBreaker: false,
        circuitBreakerThreshold: 10,
        circuitBreakerResetTimeout: Duration(minutes: 5),
      );

      expect(config.timeout, equals(const Duration(seconds: 30)));
      expect(config.defaultConcurrency, equals(5));
      expect(config.defaultRetryPolicy, isNotNull);
      expect(config.defaultRetryPolicy!.maxAttempts, equals(5));
      expect(config.enableCircuitBreaker, isFalse);
      expect(config.circuitBreakerThreshold, equals(10));
      expect(config.circuitBreakerResetTimeout,
          equals(const Duration(minutes: 5)));
    });
  });

  group('DefaultRetryPolicy', () {
    test('defaults are correct', () {
      const policy = DefaultRetryPolicy();
      expect(policy.maxAttempts, equals(3));
      expect(policy.initialDelay, equals(const Duration(seconds: 1)));
      expect(policy.backoffMultiplier, equals(2.0));
    });

    test('custom values override defaults', () {
      const policy = DefaultRetryPolicy(
        maxAttempts: 5,
        initialDelay: Duration(milliseconds: 500),
        backoffMultiplier: 1.5,
      );

      expect(policy.maxAttempts, equals(5));
      expect(policy.initialDelay,
          equals(const Duration(milliseconds: 500)));
      expect(policy.backoffMultiplier, equals(1.5));
    });
  });

  group('MonitoringConfig', () {
    test('defaults are correct', () {
      const config = MonitoringConfig();
      expect(config.enableMetrics, isTrue);
      expect(config.enableTracing, isTrue);
      expect(config.metricsInterval,
          equals(const Duration(seconds: 60)));
      expect(config.samplingRate, equals(1.0));
    });

    test('custom values override defaults', () {
      const config = MonitoringConfig(
        enableMetrics: false,
        enableTracing: false,
        metricsInterval: Duration(seconds: 30),
        samplingRate: 0.5,
      );

      expect(config.enableMetrics, isFalse);
      expect(config.enableTracing, isFalse);
      expect(config.metricsInterval,
          equals(const Duration(seconds: 30)));
      expect(config.samplingRate, equals(0.5));
    });
  });
}
