/// Stage Executor - Executes individual stages within pipelines/workflows.
///
/// Handles stage execution, retry logic, and failure handling.
library;

import '../models/execution_context.dart';
import '../models/stage.dart';
import '../ports/ops_port.dart';
import 'handler_registry.dart';

/// Executes individual stages.
class StageExecutor {
  /// Handler registry.
  final HandlerRegistry _handlers;

  /// Ports for handler composition.
  final OpsPorts? ports;

  StageExecutor({
    required HandlerRegistry handlers,
    this.ports,
  }) : _handlers = handlers;

  /// Execute a stage.
  Future<StageResult> execute(
    Stage stage,
    dynamic input,
    ExecutionContext context,
  ) async {
    final startTime = DateTime.now();

    try {
      // Check skip condition
      if (stage.condition != null) {
        if (!_evaluateCondition(stage.condition!, context)) {
          return StageResult.skipped(stage.id, 'Condition not met');
        }
      }

      // Get handler
      final handler = _handlers.get(stage.handler);
      if (handler == null) {
        throw StageException('Handler not found: ${stage.handler}');
      }

      // Build handler context with port access
      final handlerContext = HandlerContext(
        runId: context.runId,
        stageId: stage.id,
        traceId: context.traceId,
        asOf: context.asOf,
        config: stage.config,
        ports: ports,
      );

      // Execute with timeout
      final result = await _executeWithTimeout(
        () => handler.execute(input, handlerContext),
        stage.timeout ?? context.config.timeout,
      );

      return StageResult.completed(
        stage.id,
        result,
        DateTime.now().difference(startTime),
      );
    } catch (e, stack) {
      return _handleStageFailure(stage, e, stack, startTime);
    }
  }

  /// Execute with retry.
  Future<StageResult> executeWithRetry(
    Stage stage,
    dynamic input,
    ExecutionContext context,
  ) async {
    final retryConfig = stage.retryConfig;
    if (retryConfig == null) {
      return execute(stage, input, context);
    }

    StageResult? lastResult;
    for (var attempt = 1; attempt <= retryConfig.maxAttempts; attempt++) {
      final result = await execute(stage, input, context);

      if (result.status != StageStatus.failed) {
        return result;
      }

      lastResult = result;

      if (attempt < retryConfig.maxAttempts) {
        final delay = retryConfig.delayForAttempt(attempt);
        await Future.delayed(delay);
      }
    }

    return lastResult ?? StageResult.failed(stage.id, 'Max retries exceeded');
  }

  Future<dynamic> _executeWithTimeout(
    Future<dynamic> Function() operation,
    Duration timeout,
  ) async {
    return await operation().timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'Stage execution timed out after ${timeout.inSeconds}s',
      ),
    );
  }

  bool _evaluateCondition(String condition, ExecutionContext context) {
    final trimmed = condition.trim();

    if (trimmed == 'true') return true;
    if (trimmed == 'false') return false;

    // Check for negation
    if (trimmed.startsWith('!')) {
      final varName = trimmed.substring(1).trim();
      return context.getState(varName) == null;
    }

    // Check for state variable truthy
    final value = context.getState(trimmed);
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.isNotEmpty;
    if (value is num) return value != 0;
    return true;
  }

  StageResult _handleStageFailure(
    Stage stage,
    Object error,
    StackTrace stack,
    DateTime startTime,
  ) {
    switch (stage.onFailure) {
      case OnFailure.fail:
        return StageResult(
          stageId: stage.id,
          status: StageStatus.failed,
          error: error.toString(),
          startedAt: startTime,
          completedAt: DateTime.now(),
        );
      case OnFailure.skip:
        return StageResult.skipped(stage.id, error.toString());
      case OnFailure.manualOverride:
        return StageResult.pending(stage.id, 'Manual override required');
      case OnFailure.retry:
        return StageResult(
          stageId: stage.id,
          status: StageStatus.failed,
          error: error.toString(),
          startedAt: startTime,
          completedAt: DateTime.now(),
        );
    }
  }
}

/// Stage execution exception.
class StageException implements Exception {
  final String message;
  final String? stageId;
  final Object? cause;
  final StackTrace? stackTrace;

  StageException(
    this.message, {
    this.stageId,
    this.cause,
    this.stackTrace,
  });

  factory StageException.fromError(
    String stageId,
    Object error,
    StackTrace stack,
  ) {
    return StageException(
      error.toString(),
      stageId: stageId,
      cause: error,
      stackTrace: stack,
    );
  }

  @override
  String toString() => 'StageException: $message';
}

/// Timeout exception.
class TimeoutException implements Exception {
  final String message;

  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}

/// Retryable exception marker.
class RetryableException implements Exception {
  final String stageId;
  final String message;

  RetryableException(this.stageId, this.message);

  @override
  String toString() => 'RetryableException($stageId): $message';
}
