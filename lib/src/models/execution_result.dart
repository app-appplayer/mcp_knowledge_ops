/// Execution Result - Results for pipeline and workflow execution.
///
/// Defines result structures for pipelines, workflows, and runbooks.
library;

import 'stage.dart';
import 'gate.dart';

/// Pipeline execution result.
class PipelineResult<T> {
  /// Whether execution succeeded.
  final bool success;

  /// Output value.
  final T? output;

  /// Error if failed.
  final PipelineError? error;

  /// Stage results.
  final List<StageResult> stages;

  /// Gate results.
  final List<GateResult> gates;

  /// Execution metrics.
  final PipelineMetrics metrics;

  const PipelineResult({
    required this.success,
    this.output,
    this.error,
    required this.stages,
    required this.gates,
    required this.metrics,
  });

  /// Create a success result.
  factory PipelineResult.success({
    required T output,
    required List<StageResult> stages,
    List<GateResult> gates = const [],
    required PipelineMetrics metrics,
  }) {
    return PipelineResult(
      success: true,
      output: output,
      stages: stages,
      gates: gates,
      metrics: metrics,
    );
  }

  /// Create a failure result.
  factory PipelineResult.failure({
    required PipelineError error,
    required List<StageResult> stages,
    List<GateResult> gates = const [],
    required PipelineMetrics metrics,
  }) {
    return PipelineResult(
      success: false,
      error: error,
      stages: stages,
      gates: gates,
      metrics: metrics,
    );
  }
}

/// Pipeline execution error.
class PipelineError {
  /// Error code.
  final String code;

  /// Error message.
  final String message;

  /// Stage where error occurred.
  final String? stageId;

  /// Original cause.
  final Object? cause;

  /// Stack trace.
  final StackTrace? stackTrace;

  const PipelineError({
    required this.code,
    required this.message,
    this.stageId,
    this.cause,
    this.stackTrace,
  });

  /// Create from exception.
  factory PipelineError.fromException(Object error, StackTrace stack) {
    return PipelineError(
      code: 'EXECUTION_ERROR',
      message: error.toString(),
      cause: error,
      stackTrace: stack,
    );
  }

  @override
  String toString() => 'PipelineError($code): $message';
}

/// Pipeline execution metrics.
class PipelineMetrics {
  /// Total execution duration.
  final Duration totalDuration;

  /// Duration per stage.
  final Map<String, Duration> stageDurations;

  /// Number of items processed.
  final int itemsProcessed;

  /// Number of items failed.
  final int itemsFailed;

  /// Custom metrics.
  final Map<String, dynamic> custom;

  const PipelineMetrics({
    required this.totalDuration,
    this.stageDurations = const {},
    this.itemsProcessed = 0,
    this.itemsFailed = 0,
    this.custom = const {},
  });

  /// Create empty metrics.
  factory PipelineMetrics.empty() {
    return const PipelineMetrics(
      totalDuration: Duration.zero,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'totalDuration': totalDuration.inMilliseconds,
        'stageDurations': stageDurations.map(
          (k, v) => MapEntry(k, v.inMilliseconds),
        ),
        'itemsProcessed': itemsProcessed,
        'itemsFailed': itemsFailed,
        if (custom.isNotEmpty) 'custom': custom,
      };
}

/// Workflow execution result.
class WorkflowResult<T> {
  /// Whether execution succeeded.
  final bool success;

  /// Output value.
  final T? output;

  /// Error if failed.
  final WorkflowError? error;

  /// Stage results.
  final List<StageResult> stages;

  /// Gate results.
  final List<GateResult> gates;

  /// Produced artifacts.
  final List<Artifact> artifacts;

  /// Execution metrics.
  final WorkflowMetrics metrics;

  const WorkflowResult({
    required this.success,
    this.output,
    this.error,
    required this.stages,
    required this.gates,
    required this.artifacts,
    required this.metrics,
  });

  /// Create a success result.
  factory WorkflowResult.success({
    required T output,
    required List<StageResult> stages,
    List<GateResult> gates = const [],
    List<Artifact> artifacts = const [],
    required WorkflowMetrics metrics,
  }) {
    return WorkflowResult(
      success: true,
      output: output,
      stages: stages,
      gates: gates,
      artifacts: artifacts,
      metrics: metrics,
    );
  }

  /// Create a failure result.
  factory WorkflowResult.failure({
    required WorkflowError error,
    required List<StageResult> stages,
    List<GateResult> gates = const [],
    List<Artifact> artifacts = const [],
    required WorkflowMetrics metrics,
  }) {
    return WorkflowResult(
      success: false,
      error: error,
      stages: stages,
      gates: gates,
      artifacts: artifacts,
      metrics: metrics,
    );
  }
}

/// Workflow execution error.
class WorkflowError {
  /// Error code.
  final String code;

  /// Error message.
  final String message;

  /// Stage where error occurred.
  final String? stageId;

  /// Original cause.
  final Object? cause;

  /// Stack trace.
  final StackTrace? stackTrace;

  const WorkflowError({
    required this.code,
    required this.message,
    this.stageId,
    this.cause,
    this.stackTrace,
  });

  /// Create from exception.
  factory WorkflowError.fromException(Object error, StackTrace stack) {
    return WorkflowError(
      code: 'EXECUTION_ERROR',
      message: error.toString(),
      cause: error,
      stackTrace: stack,
    );
  }

  @override
  String toString() => 'WorkflowError($code): $message';
}

/// Workflow execution metrics.
class WorkflowMetrics {
  /// Total execution duration.
  final Duration totalDuration;

  /// Duration per stage.
  final Map<String, Duration> stageDurations;

  /// Number of reviews.
  final int reviewCount;

  /// Number of approvals.
  final int approvalCount;

  /// Custom metrics.
  final Map<String, dynamic> custom;

  const WorkflowMetrics({
    required this.totalDuration,
    this.stageDurations = const {},
    this.reviewCount = 0,
    this.approvalCount = 0,
    this.custom = const {},
  });

  /// Create empty metrics.
  factory WorkflowMetrics.empty() {
    return const WorkflowMetrics(
      totalDuration: Duration.zero,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'totalDuration': totalDuration.inMilliseconds,
        'stageDurations': stageDurations.map(
          (k, v) => MapEntry(k, v.inMilliseconds),
        ),
        'reviewCount': reviewCount,
        'approvalCount': approvalCount,
        if (custom.isNotEmpty) 'custom': custom,
      };
}


/// Artifact produced by workflow.
class Artifact {
  /// Artifact identifier.
  final String id;

  /// Artifact type: "skill_bundle" | "profile_bundle" | "mcp_bundle" | "report".
  final String type;

  /// Storage path or URI.
  final String path;

  /// Content checksum.
  final String checksum;

  /// Creation timestamp.
  final DateTime createdAt;

  const Artifact({
    required this.id,
    required this.type,
    required this.path,
    required this.checksum,
    required this.createdAt,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'path': path,
        'checksum': checksum,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Runbook execution result.
class RunbookResult {
  /// Whether execution succeeded.
  final bool success;

  /// Step results.
  final List<RunbookStepResult> steps;

  /// Error if failed.
  final RunbookError? error;

  /// Output data.
  final Map<String, dynamic> output;

  /// Human-readable execution summary.
  final String? summary;

  /// Execution metrics.
  final RunbookMetrics metrics;

  const RunbookResult({
    required this.success,
    required this.steps,
    this.error,
    this.output = const {},
    this.summary,
    required this.metrics,
  });
}

/// Runbook step result.
class RunbookStepResult {
  /// Step identifier.
  final String stepId;

  /// Whether step succeeded.
  final bool success;

  /// Output data.
  final dynamic output;

  /// Error if failed.
  final String? error;

  /// Execution duration.
  final Duration duration;

  const RunbookStepResult({
    required this.stepId,
    required this.success,
    this.output,
    this.error,
    required this.duration,
  });
}


/// Runbook execution error.
class RunbookError {
  /// Step where error occurred.
  final String? stepId;

  /// Error code.
  final String code;

  /// Error message.
  final String message;

  /// Whether the error is recoverable.
  final bool recoverable;

  /// Suggested action to resolve the error.
  final String? suggestedAction;

  const RunbookError({
    this.stepId,
    required this.code,
    required this.message,
    this.recoverable = false,
    this.suggestedAction,
  });
}

/// Runbook execution metrics.
class RunbookMetrics {
  /// Total execution duration.
  final Duration totalDuration;

  /// Duration per step.
  final Map<String, Duration> stepDurations;

  /// Time spent on manual steps.
  final Duration manualTime;

  /// Time spent on automated steps.
  final Duration automatedTime;

  /// Time spent waiting.
  final Duration waitTime;

  const RunbookMetrics({
    required this.totalDuration,
    this.stepDurations = const {},
    this.manualTime = Duration.zero,
    this.automatedTime = Duration.zero,
    this.waitTime = Duration.zero,
  });

  /// Create empty metrics.
  factory RunbookMetrics.empty() {
    return const RunbookMetrics(
      totalDuration: Duration.zero,
    );
  }
}
