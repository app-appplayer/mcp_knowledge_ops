/// Pipeline Executor - Executes pipelines with stage management.
///
/// Provides pipeline execution with retry, checkpointing, and observability.
library;

import 'pipeline.dart';
import 'pipeline_handler.dart';

/// Executes pipelines.
///
/// **Deprecated**: Use [ExecutionEngine.executePipeline] instead.
/// ExecutionEngine provides gates, checkpoints, parallel execution,
/// port composition, and richer event emission. This class will be
/// removed in a future release.
@Deprecated('Use ExecutionEngine.executePipeline() instead')
class PipelineExecutor {
  /// Handler registry.
  final PipelineHandlerRegistry _registry;

  /// Event listener.
  final PipelineEventListener? _listener;

  PipelineExecutor({
    required PipelineHandlerRegistry registry,
    PipelineEventListener? listener,
  })  : _registry = registry,
        _listener = listener;

  /// Execute a pipeline.
  Future<PipelineResult<T>> execute<TInput, T>(
    Pipeline<TInput, T> pipeline,
    TInput input,
    PipelineContext context,
  ) async {
    final startTime = DateTime.now();
    final stageResults = <StageResult>[];

    _emitEvent(PipelineStartedEvent(
      pipelineId: pipeline.id,
      runId: context.runId,
      timestamp: startTime,
    ));

    try {
      // Sort stages by order
      final sortedStages = List<PipelineStage>.from(pipeline.stages)
        ..sort((a, b) => a.order.compareTo(b.order));

      // Store input in context
      context.updateState('_input', input);
      context.updateState('_currentStage', 0);

      // Execute stages
      for (final stage in sortedStages) {
        final stageResult = await _executeStage(
          pipeline,
          stage,
          context,
        );
        stageResults.add(stageResult);

        if (stageResult.status == StageStatus.failed) {
          switch (context.config.onError) {
            case OnErrorStrategy.fail:
              throw PipelineExecutionException(
                code: 'STAGE_FAILED',
                message: 'Stage ${stage.id} failed: ${stageResult.error}',
                stageId: stage.id,
              );
            case OnErrorStrategy.skip:
              continue;
            case OnErrorStrategy.retry:
              // Retry logic already handled in _executeStage
              break;
          }
        }
      }

      final duration = DateTime.now().difference(startTime);
      final metrics = _computeMetrics(stageResults, duration);

      final output = context.getState<T>('_output');

      _emitEvent(PipelineCompletedEvent(
        pipelineId: pipeline.id,
        runId: context.runId,
        success: true,
        metrics: metrics,
        timestamp: DateTime.now(),
      ));

      return PipelineResult.success(
        output: output as T,
        stages: stageResults,
        metrics: metrics,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      final metrics = _computeMetrics(stageResults, duration);

      final error = e is PipelineExecutionException
          ? PipelineError(
              code: e.code,
              message: e.message,
              stageId: e.stageId,
              cause: e.cause,
            )
          : PipelineError(
              code: 'EXECUTION_ERROR',
              message: e.toString(),
            );

      _emitEvent(PipelineCompletedEvent(
        pipelineId: pipeline.id,
        runId: context.runId,
        success: false,
        metrics: metrics,
        timestamp: DateTime.now(),
      ));

      return PipelineResult.failure(
        error: error,
        stages: stageResults,
        metrics: metrics,
      );
    }
  }

  Future<StageResult> _executeStage(
    Pipeline pipeline,
    PipelineStage stage,
    PipelineContext context,
  ) async {
    final startTime = DateTime.now();

    _emitEvent(StageStartedEvent(
      pipelineId: pipeline.id,
      runId: context.runId,
      stageId: stage.id,
      timestamp: startTime,
    ));

    // Check condition
    if (stage.condition != null &&
        !_evaluateCondition(stage.condition!, context)) {
      final result = StageResult(
        stageId: stage.id,
        status: StageStatus.skipped,
        startedAt: startTime,
        completedAt: DateTime.now(),
      );

      _emitEvent(StageCompletedEvent(
        pipelineId: pipeline.id,
        runId: context.runId,
        stageId: stage.id,
        duration: result.duration ?? Duration.zero,
        timestamp: DateTime.now(),
      ));

      return result;
    }

    // Get handler
    final handler = _registry.get(stage.handler);
    if (handler == null) {
      return StageResult(
        stageId: stage.id,
        status: StageStatus.failed,
        startedAt: startTime,
        completedAt: DateTime.now(),
        error: 'Handler not found: ${stage.handler}',
      );
    }

    // Build stage input
    final stageInput = _buildStageInput(stage, context);

    // Execute with retry
    final retryConfig =
        context.config.retryPolicy?.getConfigForStage(stage.id) ??
            stage.retryConfig;

    try {
      final output = await _executeWithRetry(
        () => handler.execute(stageInput, _buildHandlerContext(context, stage)),
        retryConfig,
      );

      // Apply output mapping
      _applyOutputMapping(stage, output, context);

      final result = StageResult(
        stageId: stage.id,
        status: StageStatus.completed,
        startedAt: startTime,
        completedAt: DateTime.now(),
        output: output,
      );

      _emitEvent(StageCompletedEvent(
        pipelineId: pipeline.id,
        runId: context.runId,
        stageId: stage.id,
        duration: result.duration ?? Duration.zero,
        timestamp: DateTime.now(),
      ));

      return result;
    } catch (e) {
      final result = StageResult(
        stageId: stage.id,
        status: StageStatus.failed,
        startedAt: startTime,
        completedAt: DateTime.now(),
        error: e.toString(),
      );

      _emitEvent(StageFailedEvent(
        pipelineId: pipeline.id,
        runId: context.runId,
        stageId: stage.id,
        error: e.toString(),
        timestamp: DateTime.now(),
      ));

      return result;
    }
  }

  Future<dynamic> _executeWithRetry(
    Future<dynamic> Function() operation,
    RetryConfig? config,
  ) async {
    if (config == null) {
      return operation();
    }

    Object? lastError;
    for (var attempt = 1; attempt <= config.maxAttempts; attempt++) {
      try {
        return await operation();
      } catch (e) {
        lastError = e;

        if (attempt < config.maxAttempts) {
          final delay = config.delayForAttempt(attempt);
          await Future.delayed(delay);
        }
      }
    }

    throw lastError!;
  }

  bool _evaluateCondition(String condition, PipelineContext context) {
    // Simple condition evaluation
    final trimmed = condition.trim();

    if (trimmed == 'true') return true;
    if (trimmed == 'false') return false;

    // Check for state variable existence
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

  Map<String, dynamic> _buildStageInput(
    PipelineStage stage,
    PipelineContext context,
  ) {
    final input = <String, dynamic>{};

    // Apply input mapping
    for (final entry in stage.inputMapping.entries) {
      final value = context.getState(entry.value);
      if (value != null) {
        input[entry.key] = value;
      }
    }

    // Include default state values
    if (input.isEmpty) {
      input['_input'] = context.getState('_input');
      input.addAll(context.state);
    }

    return input;
  }

  void _applyOutputMapping(
    PipelineStage stage,
    dynamic output,
    PipelineContext context,
  ) {
    if (output == null) return;

    if (stage.outputMapping.isEmpty) {
      // Default: store output with stage ID
      context.updateState(stage.id, output);
      context.updateState('_output', output);
    } else {
      // Apply explicit mapping
      if (output is Map<String, dynamic>) {
        for (final entry in stage.outputMapping.entries) {
          final value = output[entry.key];
          if (value != null) {
            context.updateState(entry.value, value);
          }
        }
      }
    }
  }

  HandlerContext _buildHandlerContext(
    PipelineContext context,
    PipelineStage stage,
  ) {
    return HandlerContext(
      runId: context.runId,
      stageId: stage.id,
      traceId: context.traceId ?? '',
      asOf: context.asOf,
      config: context.config.extra,
    );
  }

  PipelineMetrics _computeMetrics(
    List<StageResult> stageResults,
    Duration totalDuration,
  ) {
    final stageDurations = <String, Duration>{};
    var itemsProcessed = 0;
    var itemsFailed = 0;

    for (final result in stageResults) {
      if (result.duration != null) {
        stageDurations[result.stageId] = result.duration!;
      }
      if (result.status == StageStatus.completed) {
        itemsProcessed++;
      } else if (result.status == StageStatus.failed) {
        itemsFailed++;
      }
    }

    return PipelineMetrics(
      totalDuration: totalDuration,
      stageDurations: stageDurations,
      itemsProcessed: itemsProcessed,
      itemsFailed: itemsFailed,
    );
  }

  void _emitEvent(PipelineEvent event) {
    _listener?.onEvent(event);
  }
}

/// Pipeline execution exception.
class PipelineExecutionException implements Exception {
  final String code;
  final String message;
  final String? stageId;
  final Object? cause;

  PipelineExecutionException({
    required this.code,
    required this.message,
    this.stageId,
    this.cause,
  });

  @override
  String toString() => 'PipelineExecutionException($code): $message';
}

/// Pipeline event listener.
abstract class PipelineEventListener {
  void onEvent(PipelineEvent event);
}

/// Base pipeline event.
abstract class PipelineEvent {
  String get type;
  String get pipelineId;
  String get runId;
  DateTime get timestamp;
}

/// Pipeline started event.
class PipelineStartedEvent implements PipelineEvent {
  @override
  final String type = 'pipeline_started';
  @override
  final String pipelineId;
  @override
  final String runId;
  @override
  final DateTime timestamp;

  const PipelineStartedEvent({
    required this.pipelineId,
    required this.runId,
    required this.timestamp,
  });
}

/// Stage started event.
class StageStartedEvent implements PipelineEvent {
  @override
  final String type = 'stage_started';
  @override
  final String pipelineId;
  @override
  final String runId;
  final String stageId;
  @override
  final DateTime timestamp;

  const StageStartedEvent({
    required this.pipelineId,
    required this.runId,
    required this.stageId,
    required this.timestamp,
  });
}

/// Stage completed event.
class StageCompletedEvent implements PipelineEvent {
  @override
  final String type = 'stage_completed';
  @override
  final String pipelineId;
  @override
  final String runId;
  final String stageId;
  final Duration duration;
  @override
  final DateTime timestamp;

  const StageCompletedEvent({
    required this.pipelineId,
    required this.runId,
    required this.stageId,
    required this.duration,
    required this.timestamp,
  });
}

/// Stage failed event.
class StageFailedEvent implements PipelineEvent {
  @override
  final String type = 'stage_failed';
  @override
  final String pipelineId;
  @override
  final String runId;
  final String stageId;
  final String error;
  @override
  final DateTime timestamp;

  const StageFailedEvent({
    required this.pipelineId,
    required this.runId,
    required this.stageId,
    required this.error,
    required this.timestamp,
  });
}

/// Pipeline completed event.
class PipelineCompletedEvent implements PipelineEvent {
  @override
  final String type = 'pipeline_completed';
  @override
  final String pipelineId;
  @override
  final String runId;
  final bool success;
  final PipelineMetrics metrics;
  @override
  final DateTime timestamp;

  const PipelineCompletedEvent({
    required this.pipelineId,
    required this.runId,
    required this.success,
    required this.metrics,
    required this.timestamp,
  });
}

/// Pipeline failed event per spec section 9.
class PipelineFailedEvent implements PipelineEvent {
  @override
  final String type = 'pipeline_failed';
  @override
  final String pipelineId;
  @override
  final String runId;

  /// Error description.
  final String error;

  /// The stage that failed, if applicable.
  final String? failedStage;

  @override
  final DateTime timestamp;

  const PipelineFailedEvent({
    required this.pipelineId,
    required this.runId,
    required this.error,
    this.failedStage,
    required this.timestamp,
  });
}
