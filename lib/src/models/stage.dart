/// Stage - Pipeline and workflow stage models.
///
/// Defines stage structure, status, results, and failure handling.
library;

/// Stage definition for pipelines and workflows.
class Stage {
  /// Stage identifier.
  final String id;

  /// Stage name.
  final String name;

  /// Handler to execute.
  final String handler;

  /// Execution order.
  final int order;

  /// Input mapping (state key -> handler input key).
  final Map<String, String> inputMapping;

  /// Output mapping (handler output key -> state key).
  final Map<String, String> outputMapping;

  /// Condition expression for skipping.
  final String? condition;

  /// Stage dependencies.
  final List<String>? dependsOn;

  /// Timeout for this stage.
  final Duration? timeout;

  /// Retry configuration.
  final StageRetryConfig? retryConfig;

  /// Failure handling strategy.
  final OnFailure onFailure;

  /// Stage configuration.
  final Map<String, dynamic> config;

  const Stage({
    required this.id,
    required this.name,
    required this.handler,
    this.order = 0,
    this.inputMapping = const {},
    this.outputMapping = const {},
    this.condition,
    this.dependsOn,
    this.timeout,
    this.retryConfig,
    this.onFailure = OnFailure.fail,
    this.config = const {},
  });

  /// Copy with modifications.
  Stage copyWith({
    String? id,
    String? name,
    String? handler,
    int? order,
    Map<String, String>? inputMapping,
    Map<String, String>? outputMapping,
    String? condition,
    List<String>? dependsOn,
    Duration? timeout,
    StageRetryConfig? retryConfig,
    OnFailure? onFailure,
    Map<String, dynamic>? config,
  }) {
    return Stage(
      id: id ?? this.id,
      name: name ?? this.name,
      handler: handler ?? this.handler,
      order: order ?? this.order,
      inputMapping: inputMapping ?? this.inputMapping,
      outputMapping: outputMapping ?? this.outputMapping,
      condition: condition ?? this.condition,
      dependsOn: dependsOn ?? this.dependsOn,
      timeout: timeout ?? this.timeout,
      retryConfig: retryConfig ?? this.retryConfig,
      onFailure: onFailure ?? this.onFailure,
      config: config ?? this.config,
    );
  }
}

/// Stage retry configuration.
class StageRetryConfig {
  /// Maximum retry attempts.
  final int maxAttempts;

  /// Initial delay between retries.
  final Duration initialDelay;

  /// Maximum delay between retries.
  final Duration maxDelay;

  /// Backoff multiplier.
  final double backoffMultiplier;

  const StageRetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 60),
    this.backoffMultiplier = 2.0,
  });

  /// Calculate delay for a specific attempt, capped by [maxDelay].
  Duration delayForAttempt(int attempt) {
    if (attempt <= 0) return Duration.zero;

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
    return delay;
  }
}

/// Failure handling strategy.
enum OnFailure {
  /// Fail the entire execution.
  fail,

  /// Skip this stage and continue.
  skip,

  /// Retry the failed stage.
  retry,

  /// Require manual override to continue.
  manualOverride,
}

/// Stage execution status.
enum StageStatus {
  /// Pending execution.
  pending,

  /// Currently running.
  running,

  /// Completed successfully.
  completed,

  /// Skipped (condition not met).
  skipped,

  /// Failed.
  failed,

  /// Waiting for manual override.
  waitingOverride,
}

/// Stage execution result.
class StageResult {
  /// Stage identifier.
  final String stageId;

  /// Execution status.
  final StageStatus status;

  /// Output data.
  final dynamic output;

  /// Error message if failed.
  final String? error;

  /// When execution started.
  final DateTime startedAt;

  /// When execution completed.
  final DateTime? completedAt;

  const StageResult({
    required this.stageId,
    required this.status,
    this.output,
    this.error,
    required this.startedAt,
    this.completedAt,
  });

  /// Execution duration.
  Duration? get duration =>
      completedAt != null ? completedAt!.difference(startedAt) : null;

  /// Create a completed result.
  factory StageResult.completed(
    String stageId,
    dynamic output, [
    Duration? duration,
  ]) {
    final now = DateTime.now();
    return StageResult(
      stageId: stageId,
      status: StageStatus.completed,
      output: output,
      startedAt: duration != null ? now.subtract(duration) : now,
      completedAt: now,
    );
  }

  /// Create a skipped result.
  factory StageResult.skipped(String stageId, String reason) {
    final now = DateTime.now();
    return StageResult(
      stageId: stageId,
      status: StageStatus.skipped,
      error: reason,
      startedAt: now,
      completedAt: now,
    );
  }

  /// Create a failed result.
  factory StageResult.failed(String stageId, String error) {
    final now = DateTime.now();
    return StageResult(
      stageId: stageId,
      status: StageStatus.failed,
      error: error,
      startedAt: now,
      completedAt: now,
    );
  }

  /// Create a pending result.
  factory StageResult.pending(String stageId, String message) {
    return StageResult(
      stageId: stageId,
      status: StageStatus.waitingOverride,
      error: message,
      startedAt: DateTime.now(),
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'stageId': stageId,
        'status': status.name,
        if (output != null) 'output': output,
        if (error != null) 'error': error,
        'startedAt': startedAt.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      };

  /// Deserialize from JSON.
  factory StageResult.fromJson(Map<String, dynamic> json) {
    return StageResult(
      stageId: json['stageId'] as String,
      status: StageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => StageStatus.pending,
      ),
      output: json['output'],
      error: json['error'] as String?,
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }
}

/// Stage output for state tracking.
class StageOutput {
  /// Output data.
  final dynamic data;

  /// Execution status.
  final StageStatus status;

  /// Metadata.
  final Map<String, dynamic>? metadata;

  const StageOutput({
    required this.data,
    required this.status,
    this.metadata,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'data': data,
        'status': status.name,
        if (metadata != null) 'metadata': metadata,
      };

  /// Deserialize from JSON.
  factory StageOutput.fromJson(Map<String, dynamic> json) {
    return StageOutput(
      data: json['data'],
      status: StageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => StageStatus.pending,
      ),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Workflow stage with additional type information.
class WorkflowStage extends Stage {
  /// Stage type.
  final WorkflowStageType type;

  /// Stage description.
  final String? description;

  const WorkflowStage({
    required super.id,
    required super.name,
    required super.handler,
    required this.type,
    this.description,
    super.order,
    super.inputMapping,
    super.outputMapping,
    super.condition,
    super.dependsOn,
    super.timeout,
    super.retryConfig,
    super.onFailure,
    super.config,
  });
}

/// Workflow stage types.
enum WorkflowStageType {
  /// Regular task execution.
  task,

  /// Quality gate check.
  gate,

  /// Human review required.
  review,

  /// Approval required.
  approval,
}
