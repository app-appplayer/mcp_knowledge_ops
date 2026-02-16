/// Pipeline - Base pipeline infrastructure for data processing.
///
/// Provides core pipeline definitions, stages, and execution context.
library;

/// Base pipeline interface for data processing flows.
abstract class Pipeline<TInput, TOutput> {
  /// Pipeline identifier.
  String get id;

  /// Pipeline name.
  String get name;

  /// Pipeline version.
  String get version;

  /// Pipeline description.
  String? get description;

  /// Pipeline stages.
  List<PipelineStage> get stages;

  /// Pipeline configuration.
  PipelineConfig get config;

  /// Execute the pipeline.
  Future<PipelineResult<TOutput>> run(TInput input, PipelineContext context);
}

/// A stage within a pipeline.
class PipelineStage {
  /// Stage identifier.
  final String id;

  /// Stage name.
  final String name;

  /// Execution order.
  final int order;

  /// Handler reference.
  final String handler;

  /// Input mapping.
  final Map<String, String> inputMapping;

  /// Output mapping.
  final Map<String, String> outputMapping;

  /// Skip condition expression.
  final String? condition;

  /// Retry configuration.
  final RetryConfig? retryConfig;

  /// Stage timeout.
  final Duration? timeout;

  /// Stage description.
  final String? description;

  const PipelineStage({
    required this.id,
    required this.name,
    required this.order,
    required this.handler,
    this.inputMapping = const {},
    this.outputMapping = const {},
    this.condition,
    this.retryConfig,
    this.timeout,
    this.description,
  });

  factory PipelineStage.fromJson(Map<String, dynamic> json) {
    return PipelineStage(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      handler: json['handler'] as String? ?? '',
      inputMapping:
          (json['inputMapping'] as Map<String, dynamic>?)?.cast<String, String>() ?? {},
      outputMapping:
          (json['outputMapping'] as Map<String, dynamic>?)?.cast<String, String>() ?? {},
      condition: json['condition'] as String?,
      retryConfig: json['retryConfig'] != null
          ? RetryConfig.fromJson(json['retryConfig'] as Map<String, dynamic>)
          : null,
      timeout: json['timeout'] != null
          ? _parseDuration(json['timeout'])
          : null,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'order': order,
        'handler': handler,
        if (inputMapping.isNotEmpty) 'inputMapping': inputMapping,
        if (outputMapping.isNotEmpty) 'outputMapping': outputMapping,
        if (condition != null) 'condition': condition,
        if (retryConfig != null) 'retryConfig': retryConfig!.toJson(),
        if (timeout != null) 'timeout': timeout!.inMilliseconds,
        if (description != null) 'description': description,
      };
}

/// Pipeline configuration.
class PipelineConfig {
  /// Maximum concurrent executions.
  final int maxConcurrency;

  /// Pipeline timeout.
  final Duration? timeout;

  /// Retry policy.
  final RetryPolicy? retryPolicy;

  /// Error handling strategy.
  final OnErrorStrategy onError;

  /// Whether checkpointing is enabled.
  final bool checkpointEnabled;

  /// Additional configuration.
  final Map<String, dynamic> extra;

  const PipelineConfig({
    this.maxConcurrency = 1,
    this.timeout,
    this.retryPolicy,
    this.onError = OnErrorStrategy.fail,
    this.checkpointEnabled = false,
    this.extra = const {},
  });

  factory PipelineConfig.fromJson(Map<String, dynamic> json) {
    return PipelineConfig(
      maxConcurrency: json['maxConcurrency'] as int? ?? 1,
      timeout: json['timeout'] != null ? _parseDuration(json['timeout']) : null,
      retryPolicy: json['retryPolicy'] != null
          ? RetryPolicy.fromJson(json['retryPolicy'] as Map<String, dynamic>)
          : null,
      onError: OnErrorStrategy.fromString(json['onError'] as String? ?? 'fail'),
      checkpointEnabled: json['checkpointEnabled'] as bool? ?? false,
      extra: json['extra'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'maxConcurrency': maxConcurrency,
        if (timeout != null) 'timeout': timeout!.inMilliseconds,
        if (retryPolicy != null) 'retryPolicy': retryPolicy!.toJson(),
        'onError': onError.name,
        'checkpointEnabled': checkpointEnabled,
        if (extra.isNotEmpty) 'extra': extra,
      };
}

/// Error handling strategy.
enum OnErrorStrategy {
  /// Fail the pipeline.
  fail,

  /// Skip the failed stage.
  skip,

  /// Retry the failed stage.
  retry;

  static OnErrorStrategy fromString(String value) {
    return OnErrorStrategy.values.firstWhere(
      (e) => e.name == value,
      orElse: () => OnErrorStrategy.fail,
    );
  }
}

/// Pipeline execution context.
class PipelineContext {
  /// Run identifier.
  final String runId;

  /// Trace identifier.
  final String? traceId;

  /// Workspace identifier.
  final String workspaceId;

  /// User identifier.
  final String? userId;

  /// Point in time for the execution.
  final DateTime asOf;

  /// Pipeline configuration.
  final PipelineConfig config;

  /// Accumulated state across stages.
  final Map<String, dynamic> state;

  PipelineContext({
    required this.runId,
    this.traceId,
    required this.workspaceId,
    this.userId,
    DateTime? asOf,
    required this.config,
    Map<String, dynamic>? state,
  })  : asOf = asOf ?? DateTime.now(),
        state = state ?? {};

  /// Update state.
  void updateState(String key, dynamic value) {
    state[key] = value;
  }

  /// Get state value.
  T? getState<T>(String key) {
    final value = state[key];
    if (value is T) return value;
    return null;
  }

  /// Create a copy with updated state.
  PipelineContext copyWith({
    String? runId,
    String? traceId,
    String? workspaceId,
    String? userId,
    DateTime? asOf,
    PipelineConfig? config,
    Map<String, dynamic>? state,
  }) {
    return PipelineContext(
      runId: runId ?? this.runId,
      traceId: traceId ?? this.traceId,
      workspaceId: workspaceId ?? this.workspaceId,
      userId: userId ?? this.userId,
      asOf: asOf ?? this.asOf,
      config: config ?? this.config,
      state: state ?? Map.from(this.state),
    );
  }
}

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

  /// Execution metrics.
  final PipelineMetrics metrics;

  const PipelineResult({
    required this.success,
    this.output,
    this.error,
    required this.stages,
    required this.metrics,
  });

  factory PipelineResult.success({
    required T output,
    required List<StageResult> stages,
    required PipelineMetrics metrics,
  }) {
    return PipelineResult(
      success: true,
      output: output,
      stages: stages,
      metrics: metrics,
    );
  }

  factory PipelineResult.failure({
    required PipelineError error,
    required List<StageResult> stages,
    required PipelineMetrics metrics,
  }) {
    return PipelineResult(
      success: false,
      error: error,
      stages: stages,
      metrics: metrics,
    );
  }
}

/// Pipeline error.
class PipelineError {
  /// Error code.
  final String code;

  /// Error message.
  final String message;

  /// Stage where error occurred.
  final String? stageId;

  /// Underlying exception.
  final Object? cause;

  const PipelineError({
    required this.code,
    required this.message,
    this.stageId,
    this.cause,
  });

  @override
  String toString() => 'PipelineError($code): $message';
}

/// Stage execution result.
class StageResult {
  /// Stage identifier.
  final String stageId;

  /// Execution status.
  final StageStatus status;

  /// When execution started.
  final DateTime startedAt;

  /// When execution completed.
  final DateTime? completedAt;

  /// Stage output.
  final dynamic output;

  /// Error message if failed.
  final String? error;

  const StageResult({
    required this.stageId,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.output,
    this.error,
  });

  /// Execution duration.
  Duration? get duration =>
      completedAt != null ? completedAt!.difference(startedAt) : null;

  Map<String, dynamic> toJson() => {
        'stageId': stageId,
        'status': status.name,
        'startedAt': startedAt.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (output != null) 'output': output,
        if (error != null) 'error': error,
      };
}

/// Stage execution status.
enum StageStatus {
  /// Stage completed successfully.
  completed,

  /// Stage was skipped.
  skipped,

  /// Stage failed.
  failed,
}

/// Pipeline execution metrics.
class PipelineMetrics {
  /// Total execution duration.
  final Duration totalDuration;

  /// Duration per stage.
  final Map<String, Duration> stageDurations;

  /// Items processed.
  final int itemsProcessed;

  /// Items failed.
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

/// Retry configuration.
class RetryConfig {
  /// Maximum retry attempts.
  final int maxAttempts;

  /// Initial delay before retry.
  final Duration initialDelay;

  /// Maximum delay between retries.
  final Duration maxDelay;

  /// Backoff multiplier.
  final double backoffMultiplier;

  /// Error codes to retry.
  final List<String> retryableErrors;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 60),
    this.backoffMultiplier = 2.0,
    this.retryableErrors = const [],
  });

  factory RetryConfig.fromJson(Map<String, dynamic> json) {
    return RetryConfig(
      maxAttempts: json['maxAttempts'] as int? ?? 3,
      initialDelay: json['initialDelay'] != null
          ? _parseDuration(json['initialDelay'])
          : const Duration(seconds: 1),
      maxDelay: json['maxDelay'] != null
          ? _parseDuration(json['maxDelay'])
          : const Duration(seconds: 60),
      backoffMultiplier: (json['backoffMultiplier'] as num?)?.toDouble() ?? 2.0,
      retryableErrors: (json['retryableErrors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'maxAttempts': maxAttempts,
        'initialDelay': initialDelay.inMilliseconds,
        'maxDelay': maxDelay.inMilliseconds,
        'backoffMultiplier': backoffMultiplier,
        if (retryableErrors.isNotEmpty) 'retryableErrors': retryableErrors,
      };

  /// Calculate delay for a given attempt.
  Duration delayForAttempt(int attempt) {
    var delay = initialDelay;
    for (var i = 1; i < attempt; i++) {
      final newDelay = Duration(
        milliseconds: (delay.inMilliseconds * backoffMultiplier).round(),
      );
      if (newDelay > maxDelay) {
        delay = maxDelay;
        break;
      }
      delay = newDelay;
    }
    return delay;
  }
}

/// Retry policy with per-stage overrides.
class RetryPolicy {
  /// Default retry configuration.
  final RetryConfig defaultConfig;

  /// Per-stage overrides.
  final Map<String, RetryConfig> perStage;

  const RetryPolicy({
    required this.defaultConfig,
    this.perStage = const {},
  });

  factory RetryPolicy.fromJson(Map<String, dynamic> json) {
    return RetryPolicy(
      defaultConfig:
          RetryConfig.fromJson(json['default'] as Map<String, dynamic>? ?? {}),
      perStage: (json['perStage'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, RetryConfig.fromJson(v as Map<String, dynamic>)),
          ) ??
          {},
    );
  }

  Map<String, dynamic> toJson() => {
        'default': defaultConfig.toJson(),
        if (perStage.isNotEmpty)
          'perStage': perStage.map((k, v) => MapEntry(k, v.toJson())),
      };

  /// Get retry config for a stage.
  RetryConfig getConfigForStage(String stageId) {
    return perStage[stageId] ?? defaultConfig;
  }
}

/// Parse duration from various formats.
Duration _parseDuration(dynamic value) {
  if (value is Duration) return value;
  if (value is int) return Duration(milliseconds: value);
  if (value is String) {
    final match = RegExp(r'^(\d+)([smhdw])$').firstMatch(value);
    if (match != null) {
      final amount = int.parse(match.group(1)!);
      switch (match.group(2)) {
        case 's':
          return Duration(seconds: amount);
        case 'm':
          return Duration(minutes: amount);
        case 'h':
          return Duration(hours: amount);
        case 'd':
          return Duration(days: amount);
        case 'w':
          return Duration(days: amount * 7);
      }
    }
    // Try parsing as milliseconds
    final ms = int.tryParse(value);
    if (ms != null) return Duration(milliseconds: ms);
  }
  if (value is Map) {
    return Duration(
      milliseconds: (value['milliseconds'] as int?) ?? 0,
      seconds: (value['seconds'] as int?) ?? 0,
      minutes: (value['minutes'] as int?) ?? 0,
      hours: (value['hours'] as int?) ?? 0,
      days: (value['days'] as int?) ?? 0,
    );
  }
  return Duration.zero;
}
