/// Circuit Breaker - Fault tolerance for failing operations.
///
/// Implements the circuit breaker pattern to prevent cascading failures
/// and allow systems to recover gracefully from transient errors.
library;

import 'dart:async';
import 'dart:math';

// =============================================================================
// Circuit Breaker States
// =============================================================================

/// Circuit breaker state.
enum CircuitState {
  /// Circuit is functioning normally - all calls pass through.
  closed,

  /// Circuit is tripped - calls fail fast without attempting the operation.
  open,

  /// Circuit is testing recovery - limited calls allowed to test if the
  /// underlying issue has been resolved.
  halfOpen,
}

// =============================================================================
// Circuit Breaker Configuration
// =============================================================================

/// Configuration for circuit breaker behavior.
class CircuitBreakerConfig {
  /// Number of failures before the circuit trips open.
  final int failureThreshold;

  /// Number of successes in half-open state to close the circuit.
  final int successThreshold;

  /// Duration to wait before attempting to reset (enter half-open state).
  final Duration resetTimeout;

  /// Maximum duration to stay in half-open state before tripping again.
  final Duration? halfOpenTimeout;

  /// Optional sliding window for failure counting.
  final Duration? slidingWindow;

  /// Maximum number of requests in half-open state.
  final int halfOpenMaxRequests;

  const CircuitBreakerConfig({
    this.failureThreshold = 5,
    this.successThreshold = 3,
    this.resetTimeout = const Duration(seconds: 30),
    this.halfOpenTimeout,
    this.slidingWindow,
    this.halfOpenMaxRequests = 3,
  });

  /// Conservative configuration for critical operations.
  factory CircuitBreakerConfig.conservative() => const CircuitBreakerConfig(
        failureThreshold: 3,
        successThreshold: 5,
        resetTimeout: Duration(minutes: 1),
        halfOpenMaxRequests: 1,
      );

  /// Aggressive configuration for fast recovery.
  factory CircuitBreakerConfig.aggressive() => const CircuitBreakerConfig(
        failureThreshold: 10,
        successThreshold: 2,
        resetTimeout: Duration(seconds: 10),
        halfOpenMaxRequests: 5,
      );
}

// =============================================================================
// Circuit Breaker Exceptions
// =============================================================================

/// Exception thrown when circuit breaker is open.
class CircuitOpenException implements Exception {
  /// Error message.
  final String message;

  /// When the circuit was opened.
  final DateTime openedAt;

  /// When the circuit will attempt reset.
  final DateTime resetAt;

  /// The circuit breaker name.
  final String circuitName;

  const CircuitOpenException({
    required this.message,
    required this.openedAt,
    required this.resetAt,
    required this.circuitName,
  });

  /// Remaining time until reset attempt.
  Duration get remainingTime {
    final remaining = resetAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  String toString() =>
      'CircuitOpenException: $message (circuit: $circuitName, reset in: ${remainingTime.inSeconds}s)';
}

// =============================================================================
// Circuit Breaker Listener
// =============================================================================

/// Listener for circuit breaker state changes.
abstract class CircuitBreakerListener {
  /// Called when circuit state changes.
  void onStateChange(String name, CircuitState from, CircuitState to);

  /// Called when a failure is recorded.
  void onFailure(String name, Object error, int failureCount);

  /// Called when a success is recorded.
  void onSuccess(String name, int successCount);

  /// Called when a request is rejected (circuit open).
  void onRejected(String name);
}

/// Default no-op listener.
class NoOpCircuitBreakerListener implements CircuitBreakerListener {
  const NoOpCircuitBreakerListener();

  @override
  void onStateChange(String name, CircuitState from, CircuitState to) {}

  @override
  void onFailure(String name, Object error, int failureCount) {}

  @override
  void onSuccess(String name, int successCount) {}

  @override
  void onRejected(String name) {}
}

// =============================================================================
// Circuit Breaker Implementation
// =============================================================================

/// Circuit breaker for failing services.
///
/// Prevents cascading failures by failing fast when a service is unhealthy.
class CircuitBreaker {
  /// Circuit breaker name for identification.
  final String name;

  /// Configuration.
  final CircuitBreakerConfig config;

  /// Optional listener for events.
  final CircuitBreakerListener? listener;

  /// Current circuit state.
  CircuitState _state = CircuitState.closed;

  /// Failure count in current window.
  int _failureCount = 0;

  /// Success count in half-open state.
  int _successCount = 0;

  /// Request count in half-open state.
  int _halfOpenRequestCount = 0;

  /// Timestamp of last failure.
  DateTime? _lastFailureTime;

  /// Timestamp when circuit was opened.
  DateTime? _openedAt;

  /// Timestamp when half-open state started.
  DateTime? _halfOpenStartedAt;

  /// Failure timestamps for sliding window.
  final List<DateTime> _failureTimestamps = [];

  CircuitBreaker(
    this.name,
    this.config, {
    this.listener,
  });

  /// Current circuit state.
  CircuitState get state => _state;

  /// Whether the circuit allows requests.
  bool get isAllowed {
    switch (_state) {
      case CircuitState.closed:
        return true;
      case CircuitState.open:
        return _shouldAttemptReset();
      case CircuitState.halfOpen:
        return _halfOpenRequestCount < config.halfOpenMaxRequests;
    }
  }

  /// Execute operation with circuit breaker protection.
  Future<T> execute<T>(Future<T> Function() operation) async {
    // Check circuit state
    if (_state == CircuitState.open) {
      if (_shouldAttemptReset()) {
        _transitionTo(CircuitState.halfOpen);
      } else {
        listener?.onRejected(name);
        throw CircuitOpenException(
          message: 'Circuit $name is open',
          openedAt: _openedAt!,
          resetAt: _openedAt!.add(config.resetTimeout),
          circuitName: name,
        );
      }
    }

    // Track half-open requests
    if (_state == CircuitState.halfOpen) {
      if (_halfOpenRequestCount >= config.halfOpenMaxRequests) {
        listener?.onRejected(name);
        throw CircuitOpenException(
          message: 'Circuit $name half-open request limit reached',
          openedAt: _openedAt!,
          resetAt: _halfOpenStartedAt!.add(config.resetTimeout),
          circuitName: name,
        );
      }
      _halfOpenRequestCount++;
    }

    try {
      final result = await operation();
      _recordSuccess();
      return result;
    } catch (e) {
      _recordFailure(e);
      rethrow;
    }
  }

  /// Record a successful operation.
  void _recordSuccess() {
    listener?.onSuccess(name, _successCount + 1);

    if (_state == CircuitState.halfOpen) {
      _successCount++;

      if (_successCount >= config.successThreshold) {
        _reset();
      }
    } else {
      // Reset failure count on success in closed state
      _failureCount = 0;
      _failureTimestamps.clear();
    }
  }

  /// Record a failed operation.
  void _recordFailure(Object error) {
    _failureCount++;
    _lastFailureTime = DateTime.now();
    _failureTimestamps.add(DateTime.now());

    // Clean up old failures outside sliding window
    if (config.slidingWindow != null) {
      final cutoff = DateTime.now().subtract(config.slidingWindow!);
      _failureTimestamps.removeWhere((t) => t.isBefore(cutoff));
      _failureCount = _failureTimestamps.length;
    }

    listener?.onFailure(name, error, _failureCount);

    if (_state == CircuitState.halfOpen) {
      _trip();
    } else if (_failureCount >= config.failureThreshold) {
      _trip();
    }
  }

  /// Trip the circuit breaker open.
  void _trip() {
    _transitionTo(CircuitState.open);
    _openedAt = DateTime.now();
    _successCount = 0;
    _halfOpenRequestCount = 0;
  }

  /// Reset the circuit breaker to closed state.
  void _reset() {
    _transitionTo(CircuitState.closed);
    _failureCount = 0;
    _successCount = 0;
    _halfOpenRequestCount = 0;
    _openedAt = null;
    _halfOpenStartedAt = null;
    _failureTimestamps.clear();
  }

  /// Transition to a new state.
  void _transitionTo(CircuitState newState) {
    if (_state == newState) return;

    final oldState = _state;
    _state = newState;

    if (newState == CircuitState.halfOpen) {
      _halfOpenStartedAt = DateTime.now();
      _halfOpenRequestCount = 0;
    }

    listener?.onStateChange(name, oldState, newState);
  }

  /// Check if it's time to attempt reset.
  bool _shouldAttemptReset() {
    if (_openedAt == null) return true;
    return DateTime.now().isAfter(_openedAt!.add(config.resetTimeout));
  }

  /// Force reset the circuit (for testing/admin purposes).
  void forceReset() {
    _reset();
  }

  /// Force trip the circuit (for testing/admin purposes).
  void forceTrip() {
    _trip();
  }

  /// Get circuit breaker statistics.
  CircuitBreakerStats getStats() {
    return CircuitBreakerStats(
      name: name,
      state: _state,
      failureCount: _failureCount,
      successCount: _successCount,
      lastFailureTime: _lastFailureTime,
      openedAt: _openedAt,
      halfOpenRequestCount: _halfOpenRequestCount,
    );
  }
}

/// Circuit breaker statistics.
class CircuitBreakerStats {
  final String name;
  final CircuitState state;
  final int failureCount;
  final int successCount;
  final DateTime? lastFailureTime;
  final DateTime? openedAt;
  final int halfOpenRequestCount;

  const CircuitBreakerStats({
    required this.name,
    required this.state,
    required this.failureCount,
    required this.successCount,
    this.lastFailureTime,
    this.openedAt,
    required this.halfOpenRequestCount,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'state': state.name,
        'failureCount': failureCount,
        'successCount': successCount,
        'lastFailureTime': lastFailureTime?.toIso8601String(),
        'openedAt': openedAt?.toIso8601String(),
        'halfOpenRequestCount': halfOpenRequestCount,
      };
}

// =============================================================================
// Circuit Breaker Registry
// =============================================================================

/// Registry for managing multiple circuit breakers.
class CircuitBreakerRegistry {
  final Map<String, CircuitBreaker> _breakers = {};
  final CircuitBreakerConfig _defaultConfig;
  final CircuitBreakerListener? _listener;

  CircuitBreakerRegistry({
    CircuitBreakerConfig? defaultConfig,
    CircuitBreakerListener? listener,
  })  : _defaultConfig = defaultConfig ?? const CircuitBreakerConfig(),
        _listener = listener;

  /// Get or create a circuit breaker by name.
  CircuitBreaker getOrCreate(String name, [CircuitBreakerConfig? config]) {
    return _breakers.putIfAbsent(
      name,
      () => CircuitBreaker(
        name,
        config ?? _defaultConfig,
        listener: _listener,
      ),
    );
  }

  /// Get a circuit breaker by name.
  CircuitBreaker? get(String name) => _breakers[name];

  /// Remove a circuit breaker.
  void remove(String name) => _breakers.remove(name);

  /// Reset all circuit breakers.
  void resetAll() {
    for (final breaker in _breakers.values) {
      breaker.forceReset();
    }
  }

  /// Get statistics for all circuit breakers.
  List<CircuitBreakerStats> getAllStats() {
    return _breakers.values.map((b) => b.getStats()).toList();
  }

  /// Get all open circuits.
  List<String> getOpenCircuits() {
    return _breakers.entries
        .where((e) => e.value.state == CircuitState.open)
        .map((e) => e.key)
        .toList();
  }
}

// =============================================================================
// Retry with Circuit Breaker
// =============================================================================

/// Retry configuration.
class ResilientRetryConfig {
  /// Maximum number of retry attempts.
  final int maxAttempts;

  /// Initial delay before first retry.
  final Duration initialDelay;

  /// Maximum delay between retries.
  final Duration maxDelay;

  /// Multiplier for exponential backoff.
  final double backoffMultiplier;

  /// Jitter factor (0-1) to randomize delays.
  final double jitterFactor;

  const ResilientRetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
    this.jitterFactor = 0.1,
  });

  /// Calculate delay for a given attempt.
  Duration calculateDelay(int attempt) {
    if (attempt <= 0) return Duration.zero;

    // Exponential backoff
    final baseMs = initialDelay.inMilliseconds *
        pow(backoffMultiplier, attempt - 1).toInt();
    var delayMs = baseMs.clamp(0, maxDelay.inMilliseconds);

    // Add jitter
    if (jitterFactor > 0) {
      final jitter = (delayMs * jitterFactor * (Random().nextDouble() * 2 - 1))
          .toInt();
      delayMs = (delayMs + jitter).clamp(0, maxDelay.inMilliseconds);
    }

    return Duration(milliseconds: delayMs);
  }
}

/// Executor that combines retry logic with circuit breaker.
class ResilientExecutor {
  final CircuitBreaker circuitBreaker;
  final ResilientRetryConfig retryConfig;

  ResilientExecutor({
    required this.circuitBreaker,
    ResilientRetryConfig? retryConfig,
  }) : retryConfig = retryConfig ?? const ResilientRetryConfig();

  /// Execute operation with retry and circuit breaker protection.
  Future<T> execute<T>(
    Future<T> Function() operation, {
    bool Function(Object error)? isRetryable,
  }) async {
    var attempt = 0;
    Object? lastError;
    StackTrace? lastStack;

    while (attempt < retryConfig.maxAttempts) {
      attempt++;

      try {
        return await circuitBreaker.execute(operation);
      } on CircuitOpenException {
        // Don't retry if circuit is open
        rethrow;
      } catch (e, stack) {
        lastError = e;
        lastStack = stack;

        // Check if we should retry
        final shouldRetry = isRetryable?.call(e) ?? true;
        if (!shouldRetry || attempt >= retryConfig.maxAttempts) {
          break;
        }

        // Wait before retry
        final delay = retryConfig.calculateDelay(attempt);
        await Future.delayed(delay);
      }
    }

    // Rethrow the last error
    Error.throwWithStackTrace(lastError!, lastStack!);
  }
}
