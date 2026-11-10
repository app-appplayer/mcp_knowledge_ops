/// Execution Engine - Central coordinator for pipeline and workflow execution.
///
/// Orchestrates stage execution, gate evaluation, checkpointing, and observability.
library;

import '../models/execution_context.dart';
import '../models/execution_result.dart';
import '../models/stage.dart';
import '../models/gate.dart';
import '../ports/ops_port.dart';
import 'stage_executor.dart';
import 'gate_evaluator.dart';
import 'checkpoint_manager.dart';
import 'handler_registry.dart';
import 'parallel_executor.dart';

/// Central execution coordinator.
class ExecutionEngine {
  /// Execution configuration.
  final ExecutionEngineConfig config;

  /// Stage executor.
  final StageExecutor stageExecutor;

  /// Parallel stage executor.
  final ParallelStageExecutor parallelExecutor;

  /// Gate evaluator.
  final GateEvaluator gateEvaluator;

  /// Checkpoint manager.
  final CheckpointManager checkpointManager;

  /// Event listener.
  final ExecutionEventListener? eventListener;

  /// Aggregated ports for handler composition.
  final OpsPorts? ports;

  ExecutionEngine({
    required this.config,
    required HandlerRegistry handlers,
    CheckpointManager? checkpointManager,
    GateEvaluator? gateEvaluator,
    this.eventListener,
    this.ports,
  })  : stageExecutor = StageExecutor(handlers: handlers, ports: ports),
        parallelExecutor = ParallelStageExecutor(
          stageExecutor: StageExecutor(handlers: handlers, ports: ports),
          maxConcurrency: config.maxConcurrentExecutions,
          eventListener: eventListener,
        ),
        gateEvaluator = gateEvaluator ?? GateEvaluator(),
        checkpointManager = checkpointManager ?? InMemoryCheckpointManager();

  /// Execute a pipeline.
  Future<PipelineResult<T>> executePipeline<T>(
    PipelineDefinition pipeline,
    dynamic input,
    ExecutionContext context,
  ) async {
    final startTime = DateTime.now();
    final stageResults = <StageResult>[];
    final gateResults = <GateResult>[];

    eventListener?.onPipelineStarted(pipeline.id, context.runId);

    try {
      // Store input in context
      context.setState('input', input);

      // Determine start point (resume or beginning)
      final startIndex = _determineStartIndex(pipeline.stages, context);

      // Execute stages
      for (var i = startIndex; i < pipeline.stages.length; i++) {
        final stage = pipeline.stages[i];

        // Execute stage
        eventListener?.onStageStarted(stage.id, context.runId);

        final stageResult = await stageExecutor.executeWithRetry(
          stage,
          _buildStageInput(stage, context),
          context,
        );
        stageResults.add(stageResult);

        // Record output
        if (stageResult.status == StageStatus.completed) {
          context.recordStageOutput(
            stage.id,
            StageOutput(data: stageResult.output, status: stageResult.status),
          );
          _applyOutputMapping(stage, stageResult.output, context);

          eventListener?.onStageCompleted(
            stage.id,
            context.runId,
            stageResult.duration ?? Duration.zero,
          );
        } else if (stageResult.status == StageStatus.failed) {
          eventListener?.onStageFailed(
            stage.id,
            context.runId,
            stageResult.error ?? 'Unknown error',
          );

          throw PipelineException(
            'Stage ${stage.id} failed: ${stageResult.error}',
            stageId: stage.id,
          );
        } else if (stageResult.status == StageStatus.skipped) {
          eventListener?.onStageSkipped(
            stage.id,
            context.runId,
            stageResult.error ?? 'Condition not met',
          );
        }

        // Check gates after this stage
        for (final gate
            in pipeline.gates.where((g) => g.afterStage == stage.id)) {
          final gateResult = await gateEvaluator.evaluate(gate, context);
          gateResults.add(gateResult);

          eventListener?.onGateEvaluated(gate.id, gateResult);

          if (!gateResult.passed) {
            switch (gate.onFailure) {
              case GateFailure.block:
                throw GateException('Gate ${gate.id} failed', gateResult);
              case GateFailure.warn:
                eventListener?.onGateWarning(gate.id, gateResult);
              case GateFailure.log:
                eventListener?.onGateLogged(gate.id, gateResult);
            }
          }
        }

        // Periodic checkpoint
        await _maybeCheckpoint(context, stage.id, pipeline.id);
      }

      final duration = DateTime.now().difference(startTime);
      final output = context.getState<T>('_output');
      final metrics = _buildMetrics(stageResults, duration);

      eventListener?.onPipelineCompleted(pipeline.id, context.runId, metrics);

      return PipelineResult.success(
        output: output as T,
        stages: stageResults,
        gates: gateResults,
        metrics: metrics,
      );
    } catch (e, stack) {
      final duration = DateTime.now().difference(startTime);

      eventListener?.onPipelineFailed(pipeline.id, context.runId, e);

      return PipelineResult.failure(
        error: PipelineError.fromException(e, stack),
        stages: stageResults,
        gates: gateResults,
        metrics: _buildMetrics(stageResults, duration),
      );
    }
  }

  /// Execute a pipeline with parallel stage execution.
  ///
  /// Uses dependency-aware parallel execution with concurrency control.
  /// Stages without dependencies run concurrently up to [maxConcurrentExecutions].
  Future<PipelineResult<T>> executePipelineParallel<T>(
    PipelineDefinition pipeline,
    dynamic input,
    ExecutionContext context,
  ) async {
    final startTime = DateTime.now();

    eventListener?.onPipelineStarted(pipeline.id, context.runId);

    try {
      context.setState('input', input);

      // Execute stages in parallel
      final parallelStageResults = await parallelExecutor.executeParallel(
        pipeline.stages,
        context,
        inputBuilder: (stage, ctx) => _buildStageInput(stage, ctx),
      );

      // Determine success from results
      final hasFailures = parallelStageResults.any(
        (r) => r.status == StageStatus.failed,
      );

      // Evaluate gates after parallel execution
      final gateResults = <GateResult>[];
      for (final gate in pipeline.gates) {
        final gateResult = await gateEvaluator.evaluate(gate, context);
        gateResults.add(gateResult);

        eventListener?.onGateEvaluated(gate.id, gateResult);

        if (!gateResult.passed) {
          switch (gate.onFailure) {
            case GateFailure.block:
              throw GateException('Gate ${gate.id} failed', gateResult);
            case GateFailure.warn:
              eventListener?.onGateWarning(gate.id, gateResult);
            case GateFailure.log:
              eventListener?.onGateLogged(gate.id, gateResult);
          }
        }
      }

      final duration = DateTime.now().difference(startTime);
      final output = context.getState<T>('_output');
      final metrics = _buildMetrics(parallelStageResults, duration);

      if (!hasFailures) {
        eventListener?.onPipelineCompleted(pipeline.id, context.runId, metrics);

        return PipelineResult.success(
          output: output as T,
          stages: parallelStageResults,
          gates: gateResults,
          metrics: metrics,
        );
      } else {
        final failedStage = parallelStageResults.firstWhere(
          (r) => r.status == StageStatus.failed,
        );

        eventListener?.onPipelineFailed(
          pipeline.id,
          context.runId,
          'Parallel execution failed at stage ${failedStage.stageId}',
        );

        return PipelineResult.failure(
          error: PipelineError(
            code: 'PARALLEL_EXECUTION_FAILED',
            message: 'Parallel execution failed',
            stageId: failedStage.stageId,
          ),
          stages: parallelStageResults,
          gates: gateResults,
          metrics: metrics,
        );
      }
    } catch (e, stack) {
      final duration = DateTime.now().difference(startTime);

      eventListener?.onPipelineFailed(pipeline.id, context.runId, e);

      return PipelineResult.failure(
        error: PipelineError.fromException(e, stack),
        stages: [],
        gates: [],
        metrics: _buildMetrics([], duration),
      );
    }
  }

  /// Execute a workflow.
  Future<WorkflowResult<T>> executeWorkflow<T>(
    WorkflowDefinition workflow,
    dynamic input,
    ExecutionContext context,
  ) async {
    final startTime = DateTime.now();
    final stageResults = <StageResult>[];
    final gateResults = <GateResult>[];
    final artifacts = <Artifact>[];

    eventListener?.onWorkflowStarted(workflow.id, context.runId);

    try {
      context.setState('input', input);

      for (final stage in workflow.stages) {
        final stageResult = await _executeWorkflowStage(
          workflow,
          stage,
          context,
          artifacts,
        );
        stageResults.add(stageResult);

        if (stageResult.status == StageStatus.failed) {
          throw WorkflowException(
            'Stage ${stage.id} failed',
            stageId: stage.id,
          );
        }

        // Check gates
        for (final gate
            in workflow.gates.where((g) => g.afterStage == stage.id)) {
          final gateResult = await gateEvaluator.evaluate(gate, context);
          gateResults.add(gateResult);

          eventListener?.onGateEvaluated(gate.id, gateResult);

          if (!gateResult.passed) {
            switch (gate.onFailure) {
              case GateFailure.block:
                throw GateException('Gate ${gate.id} blocked', gateResult);
              case GateFailure.warn:
                eventListener?.onGateWarning(gate.id, gateResult);
              case GateFailure.log:
                eventListener?.onGateLogged(gate.id, gateResult);
            }
          }
        }

        await _maybeCheckpoint(context, stage.id, workflow.id);
      }

      final duration = DateTime.now().difference(startTime);
      final output = context.getState<T>('_output');
      final metrics = _buildWorkflowMetrics(stageResults, duration);

      eventListener?.onWorkflowCompleted(workflow.id, context.runId, metrics);

      return WorkflowResult.success(
        output: output as T,
        stages: stageResults,
        gates: gateResults,
        artifacts: artifacts,
        metrics: metrics,
      );
    } catch (e, stack) {
      final duration = DateTime.now().difference(startTime);

      eventListener?.onWorkflowFailed(workflow.id, context.runId, e);

      return WorkflowResult.failure(
        error: WorkflowError.fromException(e, stack),
        stages: stageResults,
        gates: gateResults,
        artifacts: artifacts,
        metrics: _buildWorkflowMetrics(stageResults, duration),
      );
    }
  }

  /// Resume execution from checkpoint.
  Future<PipelineResult<T>> resumeFromCheckpoint<T>(
    PipelineDefinition pipeline,
    String checkpointId,
  ) async {
    final checkpoint = await checkpointManager.load(checkpointId);
    if (checkpoint == null) {
      throw CheckpointException('Checkpoint not found: $checkpointId');
    }

    if (!checkpoint.isResumable) {
      throw CheckpointException('Checkpoint not resumable: $checkpointId');
    }

    await checkpointManager.markResumed(checkpointId);

    final context = ExecutionContext.fromCheckpoint(
      checkpoint,
      config: config.executionDefaults,
    );

    return executePipeline(pipeline, null, context);
  }

  Future<StageResult> _executeWorkflowStage(
    WorkflowDefinition workflow,
    WorkflowStage stage,
    ExecutionContext context,
    List<Artifact> artifacts,
  ) async {
    switch (stage.type) {
      case WorkflowStageType.task:
        return stageExecutor.executeWithRetry(
          stage,
          _buildStageInput(stage, context),
          context,
        );

      case WorkflowStageType.gate:
        // Gate stages are handled separately
        return StageResult.completed(stage.id, null);

      case WorkflowStageType.review:
        return _executeReviewStage(stage, context);

      case WorkflowStageType.approval:
        return _executeApprovalStage(stage, context);
    }
  }

  /// Execute a review stage using ApprovalPort.
  ///
  /// If auto-approve is enabled, skips the review.
  /// If ApprovalPort is not available, returns pending status.
  Future<StageResult> _executeReviewStage(
    WorkflowStage stage,
    ExecutionContext context,
  ) async {
    if (context.config.autoApprove) {
      return StageResult.skipped(stage.id, 'Auto-approved');
    }

    final approval = ports?.approval;
    if (approval == null) {
      return StageResult.pending(stage.id, 'Review required (no ApprovalPort)');
    }

    // Request review via ApprovalPort (anyOne policy for reviews)
    final reviewers =
        (stage.config['reviewers'] as List<dynamic>?)?.cast<String>() ??
            const <String>[];

    final result = await approval.requestApproval(ApprovalRequest(
      requestId: '${context.runId}/${stage.id}',
      requestType: 'review',
      requesterId: context.userId ?? 'system',
      description: 'Review required for ${stage.name}',
      approverIds: reviewers,
      policy: ApprovalPolicy.anyOne,
      priority: ApprovalPriority.normal,
      timeout: stage.timeout ?? const Duration(days: 7),
    ));

    // Save checkpoint while waiting for review
    await _maybeCheckpoint(context, stage.id, 'review_pending');

    // Watch for approval result
    final stream = approval.watchApproval(result.approvalId);
    await for (final event in stream) {
      if (event.currentStatus == ApprovalStatus.approved) {
        return StageResult.completed(
            stage.id, {'approvalId': result.approvalId});
      }
      if (event.currentStatus == ApprovalStatus.rejected) {
        return StageResult.failed(stage.id, 'Review rejected');
      }
    }

    return StageResult.failed(stage.id, 'Review timeout');
  }

  /// Execute an approval stage using ApprovalPort.
  ///
  /// If auto-approve is enabled, skips the approval.
  /// If ApprovalPort is not available, returns pending status.
  Future<StageResult> _executeApprovalStage(
    WorkflowStage stage,
    ExecutionContext context,
  ) async {
    if (context.config.autoApprove) {
      return StageResult.skipped(stage.id, 'Auto-approved');
    }

    final approval = ports?.approval;
    if (approval == null) {
      return StageResult.pending(
          stage.id, 'Approval required (no ApprovalPort)');
    }

    // Determine approval policy from stage config
    final policyName = stage.config['policy'] as String? ?? 'allRequired';
    final policy = ApprovalPolicy.values.firstWhere(
      (p) => p.name == policyName,
      orElse: () => ApprovalPolicy.allRequired,
    );

    final approvers =
        (stage.config['approvers'] as List<dynamic>?)?.cast<String>() ??
            const <String>[];

    final result = await approval.requestApproval(ApprovalRequest(
      requestId: '${context.runId}/${stage.id}',
      requestType: 'approval',
      requesterId: context.userId ?? 'system',
      description: 'Approval required for ${stage.name}',
      approverIds: approvers,
      policy: policy,
      priority: ApprovalPriority.high,
      timeout: stage.timeout ?? const Duration(days: 1),
    ));

    // Send notification if NotificationPort is available
    final notification = ports?.notification;
    if (notification != null) {
      await notification.notify(Notification(
        notificationId: '${context.runId}/${stage.id}/approval-required',
        recipientId: 'team',
        type: NotificationType.action,
        title: 'Approval Required',
        body: 'Workflow ${context.runId} requires approval at ${stage.name}',
      ));
    }

    // Save checkpoint while waiting for approval
    await _maybeCheckpoint(context, stage.id, 'approval_pending');

    // Watch for approval result
    final stream = approval.watchApproval(result.approvalId);
    await for (final event in stream) {
      if (event.currentStatus == ApprovalStatus.approved) {
        return StageResult.completed(
            stage.id, {'approvalId': result.approvalId});
      }
      if (event.currentStatus == ApprovalStatus.rejected) {
        return StageResult.failed(stage.id, 'Approval rejected');
      }
    }

    return StageResult.failed(stage.id, 'Approval timeout');
  }

  int _determineStartIndex(List<Stage> stages, ExecutionContext context) {
    if (context.resumeFromStage == null) return 0;

    final index = stages.indexWhere((s) => s.id == context.resumeFromStage);
    // Resume from the checkpointed stage itself (it was not completed)
    return index >= 0 ? index : 0;
  }

  dynamic _buildStageInput(Stage stage, ExecutionContext context) {
    if (stage.inputMapping.isEmpty) {
      return context.getState('input');
    }

    final input = <String, dynamic>{};
    for (final entry in stage.inputMapping.entries) {
      final value = context.getState(entry.value);
      if (value != null) {
        input[entry.key] = value;
      }
    }
    return input;
  }

  void _applyOutputMapping(
    Stage stage,
    dynamic output,
    ExecutionContext context,
  ) {
    if (output == null) return;

    if (stage.outputMapping.isEmpty) {
      context.setState(stage.id, output);
      context.setState('_output', output);
    } else if (output is Map<String, dynamic>) {
      for (final entry in stage.outputMapping.entries) {
        final value = output[entry.key];
        if (value != null) {
          context.setState(entry.value, value);
        }
      }
    }
  }

  Future<void> _maybeCheckpoint(
    ExecutionContext context,
    String stageId,
    String pipelineId,
  ) async {
    if (!context.config.checkpointEnabled) return;

    final lastCheckpoint = context.currentCheckpoint;
    final interval = context.config.checkpointInterval;

    if (lastCheckpoint != null &&
        DateTime.now().difference(lastCheckpoint.createdAt) < interval) {
      return;
    }

    context.checkpoint('auto_after_$stageId', null);
    final checkpoint = context.currentCheckpoint;
    if (checkpoint != null) {
      await checkpointManager.save(checkpoint);
      eventListener?.onCheckpoint(context.runId, checkpoint);
    }
  }

  PipelineMetrics _buildMetrics(List<StageResult> stages, Duration total) {
    final stageDurations = <String, Duration>{};
    var processed = 0;
    var failed = 0;

    for (final result in stages) {
      if (result.duration != null) {
        stageDurations[result.stageId] = result.duration!;
      }
      if (result.status == StageStatus.completed) {
        processed++;
      } else if (result.status == StageStatus.failed) {
        failed++;
      }
    }

    return PipelineMetrics(
      totalDuration: total,
      stageDurations: stageDurations,
      itemsProcessed: processed,
      itemsFailed: failed,
    );
  }

  WorkflowMetrics _buildWorkflowMetrics(
      List<StageResult> stages, Duration total) {
    final stageDurations = <String, Duration>{};

    for (final result in stages) {
      if (result.duration != null) {
        stageDurations[result.stageId] = result.duration!;
      }
    }

    return WorkflowMetrics(
      totalDuration: total,
      stageDurations: stageDurations,
    );
  }
}

/// Execution engine configuration.
class ExecutionEngineConfig {
  /// Default execution configuration.
  final ExecutionConfig executionDefaults;

  /// Maximum concurrent executions.
  final int maxConcurrentExecutions;

  const ExecutionEngineConfig({
    this.executionDefaults = const ExecutionConfig(),
    this.maxConcurrentExecutions = 4,
  });
}

/// Pipeline definition.
class PipelineDefinition {
  /// Pipeline identifier.
  final String id;

  /// Pipeline name.
  final String name;

  /// Pipeline version.
  final String version;

  /// Pipeline description.
  final String? description;

  /// Pipeline stages.
  final List<Stage> stages;

  /// Quality gates.
  final List<Gate> gates;

  /// Pipeline configuration.
  final Map<String, dynamic> config;

  const PipelineDefinition({
    required this.id,
    required this.name,
    this.version = '1.0.0',
    this.description,
    required this.stages,
    this.gates = const [],
    this.config = const {},
  });
}

/// Workflow definition.
class WorkflowDefinition {
  /// Workflow identifier.
  final String id;

  /// Workflow name.
  final String name;

  /// Workflow version.
  final String version;

  /// Workflow description.
  final String? description;

  /// Workflow stages.
  final List<WorkflowStage> stages;

  /// Quality gates.
  final List<Gate> gates;

  /// Workflow configuration.
  final Map<String, dynamic> config;

  const WorkflowDefinition({
    required this.id,
    required this.name,
    this.version = '1.0.0',
    this.description,
    required this.stages,
    this.gates = const [],
    this.config = const {},
  });
}

/// Execution event listener with individual callback methods.
abstract class ExecutionEventListener {
  /// Called when a pipeline starts.
  void onPipelineStarted(String pipelineId, String runId);

  /// Called when a pipeline completes successfully.
  void onPipelineCompleted(
      String pipelineId, String runId, PipelineMetrics metrics);

  /// Called when a pipeline fails.
  void onPipelineFailed(String pipelineId, String runId, Object error);

  /// Called when a stage starts.
  void onStageStarted(String stageId, String runId);

  /// Called when a stage completes successfully.
  void onStageCompleted(String stageId, String runId, Duration duration);

  /// Called when a stage fails.
  void onStageFailed(String stageId, String runId, Object error);

  /// Called when a stage is skipped.
  void onStageSkipped(String stageId, String runId, String reason);

  /// Called when a workflow starts.
  void onWorkflowStarted(String workflowId, String runId);

  /// Called when a workflow completes successfully.
  void onWorkflowCompleted(
      String workflowId, String runId, WorkflowMetrics metrics);

  /// Called when a workflow fails.
  void onWorkflowFailed(String workflowId, String runId, Object error);

  /// Called when a gate is evaluated.
  void onGateEvaluated(String gateId, GateResult result);

  /// Called when a gate emits a warning (warn failure mode).
  void onGateWarning(String gateId, GateResult result);

  /// Called when a gate logs its failure (log failure mode).
  void onGateLogged(String gateId, GateResult result);

  /// Called when a checkpoint is created.
  void onCheckpoint(String runId, Checkpoint checkpoint);
}

/// Pipeline exception.
class PipelineException implements Exception {
  final String message;
  final String? stageId;

  PipelineException(this.message, {this.stageId});

  @override
  String toString() => 'PipelineException: $message';
}

/// Workflow exception.
class WorkflowException implements Exception {
  final String message;
  final String? stageId;

  WorkflowException(this.message, {this.stageId});

  @override
  String toString() => 'WorkflowException: $message';
}

/// Gate exception.
class GateException implements Exception {
  final String message;
  final GateResult result;

  GateException(this.message, this.result);

  @override
  String toString() => 'GateException: $message';
}
