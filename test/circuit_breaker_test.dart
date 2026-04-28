/// CircuitBreaker Tests - Tests for circuit breaker fault tolerance.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // CircuitBreakerConfig
  // ═══════════════════════════════════════════════════════════════

  group('CircuitBreakerConfig', () {
    test('default values', () {
      const config = CircuitBreakerConfig();
      expect(config.failureThreshold, equals(5));
      expect(config.successThreshold, equals(3));
      expect(config.resetTimeout, equals(const Duration(seconds: 30)));
      expect(config.halfOpenTimeout, isNull);
      expect(config.slidingWindow, isNull);
      expect(config.halfOpenMaxRequests, equals(3));
    });

    test('conservative preset has lower failure threshold', () {
      final config = CircuitBreakerConfig.conservative();
      expect(config.failureThreshold, equals(3));
      expect(config.successThreshold, equals(5));
      expect(config.resetTimeout, equals(const Duration(minutes: 1)));
      expect(config.halfOpenMaxRequests, equals(1));
    });

    test('aggressive preset has higher failure threshold', () {
      final config = CircuitBreakerConfig.aggressive();
      expect(config.failureThreshold, equals(10));
      expect(config.successThreshold, equals(2));
      expect(config.resetTimeout, equals(const Duration(seconds: 10)));
      expect(config.halfOpenMaxRequests, equals(5));
    });

    test('custom config values', () {
      const config = CircuitBreakerConfig(
        failureThreshold: 7,
        successThreshold: 4,
        resetTimeout: Duration(seconds: 45),
        halfOpenMaxRequests: 2,
      );
      expect(config.failureThreshold, equals(7));
      expect(config.successThreshold, equals(4));
      expect(config.resetTimeout, equals(const Duration(seconds: 45)));
      expect(config.halfOpenMaxRequests, equals(2));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // CircuitBreaker
  // ═══════════════════════════════════════════════════════════════

  group('CircuitBreaker', () {
    late CircuitBreaker breaker;

    setUp(() {
      breaker = CircuitBreaker(
        'test-circuit',
        const CircuitBreakerConfig(
          failureThreshold: 3,
          successThreshold: 2,
          resetTimeout: Duration(milliseconds: 100),
        ),
      );
    });

    test('initial state is closed', () {
      expect(breaker.state, equals(CircuitState.closed));
    });

    test('isAllowed is true when closed', () {
      expect(breaker.isAllowed, isTrue);
    });

    test('successful executions keep circuit closed', () async {
      for (var i = 0; i < 5; i++) {
        await breaker.execute(() async => 'success');
      }
      expect(breaker.state, equals(CircuitState.closed));
    });

    test('execute returns operation result on success', () async {
      final result = await breaker.execute(() async => 42);
      expect(result, equals(42));
    });

    test('exceeding failure threshold opens circuit', () async {
      for (var i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail $i'));
        } catch (_) {
          // Expected
        }
      }
      expect(breaker.state, equals(CircuitState.open));
    });

    test('open circuit throws CircuitOpenException', () async {
      // Trip the circuit
      breaker.forceTrip();
      expect(breaker.state, equals(CircuitState.open));

      expect(
        () => breaker.execute(() async => 'never'),
        throwsA(isA<CircuitOpenException>()),
      );
    });

    test('CircuitOpenException contains circuit name', () async {
      breaker.forceTrip();

      try {
        await breaker.execute(() async => 'never');
        fail('Should have thrown CircuitOpenException');
      } on CircuitOpenException catch (e) {
        expect(e.circuitName, equals('test-circuit'));
        expect(e.message, contains('test-circuit'));
        expect(e.openedAt, isA<DateTime>());
        expect(e.resetAt, isA<DateTime>());
      }
    });

    test('forceReset resets to closed', () async {
      breaker.forceTrip();
      expect(breaker.state, equals(CircuitState.open));

      breaker.forceReset();
      expect(breaker.state, equals(CircuitState.closed));
    });

    test('forceTrip forces circuit open', () {
      expect(breaker.state, equals(CircuitState.closed));
      breaker.forceTrip();
      expect(breaker.state, equals(CircuitState.open));
    });

    test('getStats returns current statistics', () async {
      await breaker.execute(() async => 'ok');

      final stats = breaker.getStats();
      expect(stats.name, equals('test-circuit'));
      expect(stats.state, equals(CircuitState.closed));
      expect(stats.failureCount, equals(0));
    });

    test('getStats reflects failure count', () async {
      try {
        await breaker.execute(() async => throw Exception('fail'));
      } catch (_) {
        // Expected
      }

      final stats = breaker.getStats();
      expect(stats.failureCount, equals(1));
    });

    test('success resets failure count in closed state', () async {
      // Record some failures (but not enough to trip)
      try {
        await breaker.execute(() async => throw Exception('fail'));
      } catch (_) {
        // Expected
      }
      expect(breaker.getStats().failureCount, equals(1));

      // Successful execution resets failure count
      await breaker.execute(() async => 'success');
      expect(breaker.getStats().failureCount, equals(0));
    });

    test('failed execution rethrows the original error', () async {
      expect(
        () => breaker.execute(() async => throw StateError('original')),
        throwsStateError,
      );
    });

    test('circuit transitions to halfOpen after reset timeout', () async {
      breaker.forceTrip();
      expect(breaker.state, equals(CircuitState.open));

      // Wait for the reset timeout
      await Future.delayed(const Duration(milliseconds: 150));

      // Next call should transition to half-open and execute
      final result = await breaker.execute(() async => 'recovered');
      expect(result, equals('recovered'));
      // State should be halfOpen (or closed if enough successes)
    });

    test('getStats toJson serializes', () {
      final stats = breaker.getStats();
      final json = stats.toJson();
      expect(json['name'], equals('test-circuit'));
      expect(json['state'], equals('closed'));
      expect(json['failureCount'], isA<int>());
    });

    test('CircuitOpenException remainingTime is non-negative', () {
      final exception = CircuitOpenException(
        message: 'test',
        openedAt: DateTime.now().subtract(const Duration(seconds: 100)),
        resetAt: DateTime.now().subtract(const Duration(seconds: 50)),
        circuitName: 'test',
      );
      expect(exception.remainingTime, equals(Duration.zero));
    });

    test('CircuitOpenException toString includes circuit name', () {
      final exception = CircuitOpenException(
        message: 'Circuit open',
        openedAt: DateTime.now(),
        resetAt: DateTime.now().add(const Duration(seconds: 30)),
        circuitName: 'my-circuit',
      );
      expect(exception.toString(), contains('my-circuit'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // CircuitBreaker with Listener
  // ═══════════════════════════════════════════════════════════════

  group('CircuitBreaker with listener', () {
    test('listener receives state changes', () async {
      final transitions = <(CircuitState, CircuitState)>[];
      final listener = _TestListener(
        onStateChangeFn: (name, from, to) {
          transitions.add((from, to));
        },
      );

      final breaker = CircuitBreaker(
        'listener-test',
        const CircuitBreakerConfig(failureThreshold: 2),
        listener: listener,
      );

      // Cause failures to trip
      for (var i = 0; i < 2; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {
          // Expected
        }
      }

      expect(transitions.isNotEmpty, isTrue);
      expect(transitions.last.$2, equals(CircuitState.open));
    });

    test('NoOpCircuitBreakerListener does not throw', () {
      const listener = NoOpCircuitBreakerListener();
      // All methods should be no-ops
      listener.onStateChange('test', CircuitState.closed, CircuitState.open);
      listener.onFailure('test', Exception('e'), 1);
      listener.onSuccess('test', 1);
      listener.onRejected('test');
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // CircuitBreakerRegistry
  // ═══════════════════════════════════════════════════════════════

  group('CircuitBreakerRegistry', () {
    late CircuitBreakerRegistry registry;

    setUp(() {
      registry = CircuitBreakerRegistry();
    });

    test('getOrCreate creates new circuit breaker', () {
      final breaker = registry.getOrCreate('service-a');
      expect(breaker, isNotNull);
      expect(breaker.name, equals('service-a'));
      expect(breaker.state, equals(CircuitState.closed));
    });

    test('getOrCreate returns existing circuit breaker', () {
      final first = registry.getOrCreate('service-a');
      final second = registry.getOrCreate('service-a');
      expect(identical(first, second), isTrue);
    });

    test('getOrCreate with custom config', () {
      final breaker = registry.getOrCreate(
        'custom',
        CircuitBreakerConfig.conservative(),
      );
      expect(breaker.config.failureThreshold, equals(3));
    });

    test('get returns null for nonexistent circuit', () {
      expect(registry.get('nonexistent'), isNull);
    });

    test('get returns existing circuit breaker', () {
      registry.getOrCreate('service-a');
      final breaker = registry.get('service-a');
      expect(breaker, isNotNull);
      expect(breaker!.name, equals('service-a'));
    });

    test('remove deletes circuit breaker', () {
      registry.getOrCreate('to-remove');
      expect(registry.get('to-remove'), isNotNull);

      registry.remove('to-remove');
      expect(registry.get('to-remove'), isNull);
    });

    test('resetAll resets all circuit breakers', () async {
      final a = registry.getOrCreate(
        'service-a',
        const CircuitBreakerConfig(failureThreshold: 1),
      );
      final b = registry.getOrCreate(
        'service-b',
        const CircuitBreakerConfig(failureThreshold: 1),
      );

      // Trip both circuits
      a.forceTrip();
      b.forceTrip();
      expect(a.state, equals(CircuitState.open));
      expect(b.state, equals(CircuitState.open));

      registry.resetAll();
      expect(a.state, equals(CircuitState.closed));
      expect(b.state, equals(CircuitState.closed));
    });

    test('getAllStats returns stats for all breakers', () {
      registry.getOrCreate('service-a');
      registry.getOrCreate('service-b');
      registry.getOrCreate('service-c');

      final stats = registry.getAllStats();
      expect(stats.length, equals(3));
      expect(
        stats.map((s) => s.name).toList(),
        containsAll(['service-a', 'service-b', 'service-c']),
      );
    });

    test('getOpenCircuits returns only open circuits', () {
      final a = registry.getOrCreate('open-a');
      registry.getOrCreate('closed-b');
      final c = registry.getOrCreate('open-c');

      a.forceTrip();
      c.forceTrip();

      final open = registry.getOpenCircuits();
      expect(open.length, equals(2));
      expect(open, containsAll(['open-a', 'open-c']));
      expect(open, isNot(contains('closed-b')));
    });

    test('getOpenCircuits returns empty when all closed', () {
      registry.getOrCreate('service-a');
      registry.getOrCreate('service-b');

      final open = registry.getOpenCircuits();
      expect(open, isEmpty);
    });

    test('registry with default config', () {
      final customRegistry = CircuitBreakerRegistry(
        defaultConfig: CircuitBreakerConfig.conservative(),
      );

      final breaker = customRegistry.getOrCreate('test');
      expect(breaker.config.failureThreshold, equals(3));
    });

    test('registry with listener', () {
      final transitions = <String>[];
      final listener = _TestListener(
        onStateChangeFn: (name, from, to) {
          transitions.add('$name: $from -> $to');
        },
      );

      final registryWithListener = CircuitBreakerRegistry(
        listener: listener,
      );
      final breaker = registryWithListener.getOrCreate('monitored');
      breaker.forceTrip();

      expect(transitions.isNotEmpty, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // ResilientRetryConfig
  // ═══════════════════════════════════════════════════════════════

  group('ResilientRetryConfig', () {
    test('default values', () {
      const config = ResilientRetryConfig();
      expect(config.maxAttempts, equals(3));
      expect(config.initialDelay, equals(const Duration(seconds: 1)));
      expect(config.maxDelay, equals(const Duration(minutes: 5)));
      expect(config.backoffMultiplier, equals(2.0));
      expect(config.jitterFactor, equals(0.1));
    });

    test('calculateDelay returns zero for attempt 0', () {
      const config = ResilientRetryConfig();
      expect(config.calculateDelay(0), equals(Duration.zero));
    });

    test('calculateDelay increases with attempts', () {
      const config = ResilientRetryConfig(
        initialDelay: Duration(seconds: 1),
        backoffMultiplier: 2.0,
        jitterFactor: 0.0,
      );

      final delay1 = config.calculateDelay(1);
      final delay2 = config.calculateDelay(2);
      final delay3 = config.calculateDelay(3);

      expect(delay1.inMilliseconds, equals(1000));
      expect(delay2.inMilliseconds, equals(2000));
      expect(delay3.inMilliseconds, equals(4000));
    });

    test('calculateDelay is capped by maxDelay', () {
      const config = ResilientRetryConfig(
        initialDelay: Duration(seconds: 10),
        maxDelay: Duration(seconds: 20),
        backoffMultiplier: 10.0,
        jitterFactor: 0.0,
      );

      final delay = config.calculateDelay(5);
      expect(delay.inMilliseconds, lessThanOrEqualTo(20000));
    });
  });
}

/// Test listener for circuit breaker events.
class _TestListener implements CircuitBreakerListener {
  final void Function(String name, CircuitState from, CircuitState to)?
      onStateChangeFn;

  _TestListener({
    this.onStateChangeFn,
  });

  @override
  void onStateChange(String name, CircuitState from, CircuitState to) {
    onStateChangeFn?.call(name, from, to);
  }

  @override
  void onFailure(String name, Object error, int failureCount) {}

  @override
  void onSuccess(String name, int successCount) {}

  @override
  void onRejected(String name) {}
}
