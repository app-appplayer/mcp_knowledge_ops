/// Ops Exception - Error taxonomy for knowledge ops execution.
///
/// Provides a comprehensive exception hierarchy for pipeline, workflow,
/// gate, and execution errors with retry and recovery metadata.
library;

// ---------------------------------------------------------------------------
// Base exception
// ---------------------------------------------------------------------------

/// Abstract base class for all knowledge ops exceptions.
///
/// Every ops exception carries a human-readable message, optional structured
/// error code, optional details map, optional stack trace, and retry guidance.
abstract class OpsException implements Exception {
  /// Human-readable error message.
  final String message;

  /// Optional structured error code string (e.g. 'OPS-PIPE-001').
  final String? code;

  /// Optional details providing additional context.
  final Map<String, dynamic>? details;

  /// Optional stack trace captured at the point of error.
  final StackTrace? stackTrace;

  /// Whether the operation that caused this exception can be retried.
  bool get retryable;

  /// Suggested delay before retry. Returns [Duration.zero] for non-retryable.
  Duration get suggestedDelay;

  const OpsException(
    this.message, {
    this.code,
    this.details,
    this.stackTrace,
  });

  @override
  String toString() => '${runtimeType}($code): $message';
}

// ---------------------------------------------------------------------------
// Pipeline errors
// ---------------------------------------------------------------------------

/// Exception thrown during pipeline execution.
///
/// Carries the pipeline identifier and optionally the stage where the
/// failure occurred.
class PipelineException extends OpsException {
  /// Pipeline that raised the error.
  final String pipelineId;

  /// Stage within the pipeline where the error occurred (if applicable).
  final String? stageId;

  @override
  bool get retryable => false;

  @override
  Duration get suggestedDelay => Duration.zero;

  const PipelineException(
    super.message, {
    super.code,
    required this.pipelineId,
    this.stageId,
    super.details,
    super.stackTrace,
  });

  @override
  String toString() =>
      'PipelineException($code, pipeline=$pipelineId'
      '${stageId != null ? ', stage=$stageId' : ''}): $message';
}

// ---------------------------------------------------------------------------
// Stage errors
// ---------------------------------------------------------------------------

/// Exception thrown during stage execution.
///
/// Stage exceptions are retryable by default with a 1-second suggested delay,
/// since transient failures at the stage level are common.
class StageException extends OpsException {
  /// Stage that raised the error.
  final String stageId;

  /// Handler that was executing when the error occurred (if applicable).
  final String? handlerId;

  @override
  bool get retryable => true;

  @override
  Duration get suggestedDelay => const Duration(seconds: 1);

  const StageException(
    super.message, {
    super.code,
    required this.stageId,
    this.handlerId,
    super.details,
    super.stackTrace,
  });

  /// Create a StageException from an arbitrary error.
  factory StageException.fromError(
    Object error, {
    required String stageId,
    String? handlerId,
    StackTrace? stackTrace,
  }) {
    return StageException(
      error.toString(),
      stageId: stageId,
      handlerId: handlerId,
      stackTrace: stackTrace,
    );
  }

  @override
  String toString() =>
      'StageException($code, stage=$stageId'
      '${handlerId != null ? ', handler=$handlerId' : ''}): $message';
}

// ---------------------------------------------------------------------------
// Retryable / Permanent
// ---------------------------------------------------------------------------

/// Exception indicating a retryable transient failure.
///
/// Carries retry attempt metadata so callers can implement backoff strategies.
class RetryableOpsException extends OpsException {
  /// Current attempt number (1-based).
  final int attemptNumber;

  /// Duration until the next retry should be attempted.
  final Duration nextRetryIn;

  @override
  bool get retryable => true;

  @override
  Duration get suggestedDelay => nextRetryIn;

  const RetryableOpsException(
    super.message, {
    super.code,
    this.attemptNumber = 0,
    this.nextRetryIn = const Duration(seconds: 1),
    super.details,
    super.stackTrace,
  });

  @override
  String toString() =>
      'RetryableOpsException($code, attempt=$attemptNumber, '
      'nextRetryIn=${nextRetryIn.inMilliseconds}ms): $message';
}

/// Exception indicating a permanent, non-retryable failure.
///
/// Callers should not retry the operation; instead they should escalate or
/// take corrective action.
class PermanentOpsException extends OpsException {
  @override
  bool get retryable => false;

  @override
  Duration get suggestedDelay => Duration.zero;

  const PermanentOpsException(
    super.message, {
    super.code,
    super.details,
    super.stackTrace,
  });
}

// ---------------------------------------------------------------------------
// Gate errors
// ---------------------------------------------------------------------------

/// Exception thrown when a quality gate evaluation fails.
///
/// Carries the gate identifier and a structured [GateResult] describing
/// which conditions passed or failed.
class GateException extends OpsException {
  /// Gate that raised the error.
  final String gateId;

  /// Structured gate evaluation result.
  final GateEvaluationResult result;

  @override
  bool get retryable => false;

  @override
  Duration get suggestedDelay => Duration.zero;

  const GateException(
    super.message, {
    super.code,
    required this.gateId,
    required this.result,
    super.details,
    super.stackTrace,
  });

  @override
  String toString() =>
      'GateException($code, gate=$gateId, passed=${result.passed}): $message';
}

/// Structured result of a gate evaluation.
class GateEvaluationResult {
  /// Whether the gate passed overall.
  final bool passed;

  /// Per-condition results.
  final List<GateConditionResult> conditionResults;

  /// Evaluation timestamp.
  final DateTime evaluatedAt;

  const GateEvaluationResult({
    required this.passed,
    this.conditionResults = const [],
    required this.evaluatedAt,
  });
}

/// Result of evaluating a single gate condition.
class GateConditionResult {
  /// Condition identifier.
  final String conditionId;

  /// Whether this condition passed.
  final bool passed;

  /// Actual value evaluated.
  final dynamic actualValue;

  /// Expected value or threshold.
  final dynamic expectedValue;

  const GateConditionResult({
    required this.conditionId,
    required this.passed,
    this.actualValue,
    this.expectedValue,
  });
}

// ---------------------------------------------------------------------------
// Timeout errors
// ---------------------------------------------------------------------------

/// Exception thrown when an operation exceeds its timeout.
class OpsTimeoutException extends OpsException {
  /// The timeout duration that was exceeded.
  final Duration timeout;

  /// The operation that timed out (if applicable).
  final String? operation;

  @override
  bool get retryable => true;

  @override
  Duration get suggestedDelay => const Duration(seconds: 5);

  const OpsTimeoutException(
    super.message, {
    super.code,
    required this.timeout,
    this.operation,
    super.details,
    super.stackTrace,
  });

  @override
  String toString() =>
      'OpsTimeoutException($code, timeout=${timeout.inMilliseconds}ms'
      '${operation != null ? ', operation=$operation' : ''}): $message';
}

// ---------------------------------------------------------------------------
// Resource errors
// ---------------------------------------------------------------------------

/// Exception thrown when a required resource is unavailable or exhausted.
///
/// Resource exceptions are retryable by default with a 1-minute suggested
/// delay, since resource availability often recovers over time.
class ResourceException extends OpsException {
  /// Type of resource (e.g. "kvStorage", "llm", "factGraph").
  final String resourceType;

  /// Specific resource identifier (if applicable).
  final String? resourceId;

  @override
  bool get retryable => true;

  @override
  Duration get suggestedDelay => const Duration(minutes: 1);

  const ResourceException(
    super.message, {
    super.code,
    required this.resourceType,
    this.resourceId,
    super.details,
    super.stackTrace,
  });

  @override
  String toString() =>
      'ResourceException($code, type=$resourceType'
      '${resourceId != null ? ', id=$resourceId' : ''}): $message';
}

// ---------------------------------------------------------------------------
// Validation errors
// ---------------------------------------------------------------------------

/// Exception thrown when input validation fails.
///
/// Carries a list of structured [ValidationError] instances for detailed
/// reporting of individual validation failures.
class ValidationException extends OpsException {
  /// Individual structured validation errors.
  final List<ValidationError> errors;

  @override
  bool get retryable => false;

  @override
  Duration get suggestedDelay => Duration.zero;

  const ValidationException(
    super.message, {
    super.code,
    required this.errors,
    super.details,
    super.stackTrace,
  });

  @override
  String toString() =>
      'ValidationException($code): $message '
      '[${errors.length} error(s): ${errors.map((e) => e.message).join('; ')}]';
}

/// Structured validation error with field and constraint information.
class ValidationError {
  /// Field or path that failed validation.
  final String field;

  /// Error message.
  final String message;

  /// Actual value that failed validation.
  final dynamic value;

  const ValidationError({
    required this.field,
    required this.message,
    this.value,
  });

  @override
  String toString() => '$field: $message';
}

// ---------------------------------------------------------------------------
// Circuit breaker errors
// ---------------------------------------------------------------------------

/// Exception thrown when a circuit breaker is in the open state.
class CircuitOpenException extends OpsException {
  /// Name of the circuit.
  final String circuitName;

  @override
  bool get retryable => true;

  @override
  Duration get suggestedDelay => const Duration(seconds: 30);

  const CircuitOpenException(
    super.message, {
    super.code,
    required this.circuitName,
    super.details,
    super.stackTrace,
  });

  @override
  String toString() => 'CircuitOpenException(circuit=$circuitName): $message';
}

// ---------------------------------------------------------------------------
// Retry executor
// ---------------------------------------------------------------------------

/// Executes an operation with configurable retry logic.
class RetryExecutor {
  /// Execute an operation with retries.
  ///
  /// Retries up to [maxAttempts] times with exponential backoff and jitter.
  static Future<T> execute<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 60),
    double backoffMultiplier = 2.0,
    double jitterFactor = 0.1,
    bool Function(Object error)? isRetryable,
    void Function(int attempt, Object error, Duration nextDelay)? onRetry,
  }) async {
    Object? lastError;
    StackTrace? lastStack;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await operation();
      } catch (e, stack) {
        lastError = e;
        lastStack = stack;

        if (attempt >= maxAttempts) break;

        // Check if error is retryable
        if (isRetryable != null && !isRetryable(e)) break;
        if (e is OpsException && !e.retryable) break;

        // Calculate delay with jitter
        var delay = initialDelay;
        for (var i = 1; i < attempt; i++) {
          delay = Duration(
            milliseconds: (delay.inMilliseconds * backoffMultiplier).round(),
          );
          if (delay > maxDelay) {
            delay = maxDelay;
            break;
          }
        }

        // Apply jitter
        if (jitterFactor > 0) {
          final jitter = (delay.inMilliseconds * jitterFactor).round();
          final offset = (DateTime.now().microsecond % (jitter * 2 + 1)) - jitter;
          delay = Duration(
            milliseconds: (delay.inMilliseconds + offset).clamp(0, maxDelay.inMilliseconds),
          );
        }

        onRetry?.call(attempt, e, delay);
        await Future<void>.delayed(delay);
      }
    }

    throw RetryableOpsException(
      'Operation failed after $maxAttempts attempts: $lastError',
      attemptNumber: maxAttempts,
      nextRetryIn: Duration.zero,
      stackTrace: lastStack,
    );
  }
}

// ---------------------------------------------------------------------------
// Fallback strategy
// ---------------------------------------------------------------------------

/// Fallback strategy for error recovery.
enum FallbackStrategy {
  /// Use a default value.
  defaultValue,

  /// Use a cached value.
  cachedValue,

  /// Use an alternative operation.
  alternative,

  /// Degrade gracefully.
  degrade,
}

/// Handler for fallback operations.
class FallbackHandler<T> {
  /// The fallback strategy to use.
  final FallbackStrategy strategy;

  /// Default value to return (for [FallbackStrategy.defaultValue]).
  final T? defaultValue;

  /// Alternative operation (for [FallbackStrategy.alternative]).
  final Future<T> Function()? alternative;

  const FallbackHandler({
    required this.strategy,
    this.defaultValue,
    this.alternative,
  });

  /// Execute with fallback on error.
  Future<T> executeWithFallback(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (_) {
      switch (strategy) {
        case FallbackStrategy.defaultValue:
          if (defaultValue != null) return defaultValue as T;
          rethrow;
        case FallbackStrategy.alternative:
          if (alternative != null) return await alternative!();
          rethrow;
        case FallbackStrategy.cachedValue:
        case FallbackStrategy.degrade:
          if (defaultValue != null) return defaultValue as T;
          rethrow;
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Error aggregation for parallel execution
// ---------------------------------------------------------------------------

/// A single execution error with context.
class ExecutionError {
  /// Stage or operation that failed.
  final String operationId;

  /// The error that occurred.
  final Object error;

  /// Stack trace.
  final StackTrace? stackTrace;

  /// Timestamp of the error.
  final DateTime timestamp;

  const ExecutionError({
    required this.operationId,
    required this.error,
    this.stackTrace,
    required this.timestamp,
  });
}

/// Aggregated error from parallel execution.
class AggregateError extends OpsException {
  /// Individual errors.
  final List<ExecutionError> errors;

  @override
  bool get retryable => errors.any((e) =>
      e.error is OpsException && (e.error as OpsException).retryable);

  @override
  Duration get suggestedDelay => Duration.zero;

  AggregateError(
    super.message, {
    super.code,
    required this.errors,
    super.details,
    super.stackTrace,
  });

  @override
  String toString() =>
      'AggregateError: $message (${errors.length} error(s))';
}

/// Collects errors from parallel execution.
class ErrorAggregator {
  final List<ExecutionError> _errors = [];

  /// Add an error.
  void add(String operationId, Object error, [StackTrace? stackTrace]) {
    _errors.add(ExecutionError(
      operationId: operationId,
      error: error,
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
    ));
  }

  /// Check if there are any errors.
  bool get hasErrors => _errors.isNotEmpty;

  /// Get all collected errors.
  List<ExecutionError> get errors => List.unmodifiable(_errors);

  /// Create an AggregateError if there are errors.
  AggregateError? toAggregateError() {
    if (_errors.isEmpty) return null;
    return AggregateError(
      '${_errors.length} operation(s) failed',
      errors: List.from(_errors),
    );
  }

  /// Clear collected errors.
  void clear() => _errors.clear();
}

// ---------------------------------------------------------------------------
// Standardized error response
// ---------------------------------------------------------------------------

/// Standardized error response for API surfaces.
class ErrorResponse {
  /// Error code.
  final String code;

  /// Human-readable error message.
  final String message;

  /// Additional error details.
  final Map<String, dynamic>? details;

  /// Whether the operation can be retried.
  final bool retryable;

  /// Suggested delay before retry (ms).
  final int? retryAfterMs;

  /// Timestamp of the error.
  final DateTime timestamp;

  const ErrorResponse({
    required this.code,
    required this.message,
    this.details,
    this.retryable = false,
    this.retryAfterMs,
    required this.timestamp,
  });

  /// Create from an OpsException.
  factory ErrorResponse.fromException(OpsException exception) {
    return ErrorResponse(
      code: exception.code ?? 'UNKNOWN',
      message: exception.message,
      details: exception.details,
      retryable: exception.retryable,
      retryAfterMs: exception.retryable
          ? exception.suggestedDelay.inMilliseconds
          : null,
      timestamp: DateTime.now(),
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'error': {
          'code': code,
          'message': message,
          if (details != null) 'details': details,
          'retryable': retryable,
          if (retryAfterMs != null) 'retryAfterMs': retryAfterMs,
        },
        'timestamp': timestamp.toIso8601String(),
      };
}
