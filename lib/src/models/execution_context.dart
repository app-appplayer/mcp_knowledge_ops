/// Execution Context - Context passed through execution stages.
///
/// Provides identity, configuration, state management, and observability
/// for pipeline and workflow execution.
library;

import 'stage.dart';
import '../id_generator.dart';

/// Context passed through execution stages.
class ExecutionContext {
  // ─────────────────────────────────────────────────────────────────
  // Identity
  // ─────────────────────────────────────────────────────────────────

  /// Unique execution run ID.
  final String runId;

  /// Distributed trace ID (for cross-service tracing).
  final String traceId;

  /// Parent span ID (for nested execution).
  final String? parentSpanId;

  /// Workspace context.
  final String workspaceId;

  /// User who triggered execution.
  final String? userId;

  /// Execution timestamp.
  final DateTime asOf;

  // ─────────────────────────────────────────────────────────────────
  // Configuration
  // ─────────────────────────────────────────────────────────────────

  /// Execution configuration.
  final ExecutionConfig config;

  /// Variables from trigger or manual input.
  final Map<String, dynamic> variables;

  // ─────────────────────────────────────────────────────────────────
  // State
  // ─────────────────────────────────────────────────────────────────

  /// Accumulated state across stages.
  final Map<String, dynamic> _state;

  /// Completed stage outputs.
  final Map<String, StageOutput> _stageOutputs;

  /// Current checkpoint.
  Checkpoint? _currentCheckpoint;

  /// Resume point (if resuming from checkpoint).
  final String? resumeFromStage;

  ExecutionContext({
    required this.runId,
    required this.traceId,
    this.parentSpanId,
    required this.workspaceId,
    this.userId,
    required this.asOf,
    required this.config,
    Map<String, dynamic>? variables,
    Map<String, dynamic>? state,
    Map<String, StageOutput>? stageOutputs,
    this.resumeFromStage,
  })  : variables = variables ?? {},
        _state = state ?? {},
        _stageOutputs = stageOutputs ?? {};

  /// Get accumulated state.
  Map<String, dynamic> get state => Map.unmodifiable(_state);

  /// Get accumulated state value.
  T? getState<T>(String key) => _state[key] as T?;

  /// Set accumulated state value.
  void setState(String key, dynamic value) {
    _state[key] = value;
  }

  /// Update multiple state values.
  void updateState(Map<String, dynamic> updates) {
    _state.addAll(updates);
  }

  /// Get output from a previous stage.
  StageOutput? getStageOutput(String stageId) => _stageOutputs[stageId];

  /// Record stage output.
  void recordStageOutput(String stageId, StageOutput output) {
    _stageOutputs[stageId] = output;
    // Also merge to state for expression evaluation
    _state['stages'] ??= <String, dynamic>{};
    (_state['stages'] as Map<String, dynamic>)[stageId] = {
      'output': output.data,
      'status': output.status.name,
    };
  }

  /// Get current checkpoint.
  Checkpoint? get currentCheckpoint => _currentCheckpoint;

  /// Create checkpoint.
  void checkpoint(String name, Map<String, dynamic>? additionalData) {
    _currentCheckpoint = Checkpoint(
      id: _generateCheckpointId(),
      runId: runId,
      name: name,
      state: {..._state, ...?additionalData},
      stageOutputs: Map.from(_stageOutputs),
      createdAt: DateTime.now(),
    );
  }

  /// Create child context for nested execution.
  ExecutionContext child({
    String? stageName,
    Map<String, dynamic>? additionalState,
  }) {
    return ExecutionContext(
      runId: '$runId/${stageName ?? 'child'}',
      traceId: traceId,
      parentSpanId: parentSpanId,
      workspaceId: workspaceId,
      userId: userId,
      asOf: asOf,
      config: config,
      variables: variables,
      state: {..._state, ...?additionalState},
      stageOutputs: _stageOutputs,
      resumeFromStage: null,
    );
  }

  /// Create context from checkpoint.
  static ExecutionContext fromCheckpoint(
    Checkpoint checkpoint, {
    required ExecutionConfig config,
  }) {
    return ExecutionContext(
      runId: checkpoint.runId,
      traceId: _generateTraceId(),
      workspaceId: checkpoint.state['workspaceId'] as String? ?? '',
      userId: checkpoint.state['userId'] as String?,
      asOf: DateTime.now(),
      config: config,
      variables: checkpoint.state['variables'] as Map<String, dynamic>? ?? {},
      state: Map.from(checkpoint.state),
      stageOutputs: Map.from(checkpoint.stageOutputs),
      resumeFromStage: checkpoint.lastCompletedStage,
    );
  }

  /// Copy with modifications.
  ExecutionContext copyWith({
    String? runId,
    String? traceId,
    String? parentSpanId,
    String? workspaceId,
    String? userId,
    DateTime? asOf,
    ExecutionConfig? config,
    Map<String, dynamic>? variables,
    Map<String, dynamic>? state,
    String? resumeFromStage,
  }) {
    return ExecutionContext(
      runId: runId ?? this.runId,
      traceId: traceId ?? this.traceId,
      parentSpanId: parentSpanId ?? this.parentSpanId,
      workspaceId: workspaceId ?? this.workspaceId,
      userId: userId ?? this.userId,
      asOf: asOf ?? this.asOf,
      config: config ?? this.config,
      variables: variables ?? this.variables,
      state: state ?? _state,
      stageOutputs: _stageOutputs,
      resumeFromStage: resumeFromStage ?? this.resumeFromStage,
    );
  }

  static String _generateCheckpointId() {
    return generateId('cp');
  }

  static String _generateTraceId() {
    return generateId('trace');
  }
}

/// Execution configuration.
class ExecutionConfig {
  /// Default timeout for stages.
  final Duration timeout;

  /// Retry configuration.
  final RetryConfig retry;

  /// Whether checkpointing is enabled.
  final bool checkpointEnabled;

  /// Interval between checkpoints.
  final Duration checkpointInterval;

  /// Whether this is a dry run.
  final bool dryRun;

  /// Maximum concurrent stage executions.
  final int maxConcurrency;

  /// Whether to auto-approve review/approval stages.
  final bool autoApprove;

  /// Extra configuration.
  final Map<String, dynamic> extra;

  const ExecutionConfig({
    this.timeout = const Duration(hours: 1),
    this.retry = const RetryConfig(),
    this.checkpointEnabled = true,
    this.checkpointInterval = const Duration(seconds: 30),
    this.dryRun = false,
    this.maxConcurrency = 1,
    this.autoApprove = false,
    this.extra = const {},
  });

  /// Copy with modifications.
  ExecutionConfig copyWith({
    Duration? timeout,
    RetryConfig? retry,
    bool? checkpointEnabled,
    Duration? checkpointInterval,
    bool? dryRun,
    int? maxConcurrency,
    bool? autoApprove,
    Map<String, dynamic>? extra,
  }) {
    return ExecutionConfig(
      timeout: timeout ?? this.timeout,
      retry: retry ?? this.retry,
      checkpointEnabled: checkpointEnabled ?? this.checkpointEnabled,
      checkpointInterval: checkpointInterval ?? this.checkpointInterval,
      dryRun: dryRun ?? this.dryRun,
      maxConcurrency: maxConcurrency ?? this.maxConcurrency,
      autoApprove: autoApprove ?? this.autoApprove,
      extra: extra ?? this.extra,
    );
  }
}

/// Retry configuration.
class RetryConfig {
  /// Maximum retry attempts.
  final int maxAttempts;

  /// Initial delay between retries.
  final Duration initialDelay;

  /// Maximum delay between retries.
  final Duration maxDelay;

  /// Backoff multiplier.
  final double backoffMultiplier;

  /// Jitter factor (0.0 to 1.0) applied to retry delays.
  final double jitterFactor;

  /// Error codes that are eligible for retry.
  final List<String> retryableErrors;

  /// Exception type names that are eligible for retry.
  final List<String> retryableExceptions;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 60),
    this.backoffMultiplier = 2.0,
    this.jitterFactor = 0.0,
    this.retryableErrors = const [],
    this.retryableExceptions = const [],
  });

  /// Calculate delay for a specific attempt with optional jitter.
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

    // Apply jitter if configured
    if (jitterFactor > 0) {
      final jitter = (delay.inMilliseconds * jitterFactor).round();
      final offset = (DateTime.now().microsecond % (jitter * 2 + 1)) - jitter;
      delay = Duration(
        milliseconds:
            (delay.inMilliseconds + offset).clamp(0, maxDelay.inMilliseconds),
      );
    }

    return delay;
  }

  /// Check if an error code is retryable.
  ///
  /// Returns true if retryableErrors is empty (all errors retryable)
  /// or if the error code is in the retryableErrors list.
  bool isRetryable(String errorCode) {
    if (retryableErrors.isEmpty) return true;
    return retryableErrors.contains(errorCode);
  }

  /// Check if an exception is retryable by type name.
  bool isExceptionRetryable(Object exception) {
    if (retryableExceptions.isEmpty) return true;
    return retryableExceptions.contains(exception.runtimeType.toString());
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'maxAttempts': maxAttempts,
        'initialDelay': initialDelay.inMilliseconds,
        'maxDelay': maxDelay.inMilliseconds,
        'backoffMultiplier': backoffMultiplier,
        if (jitterFactor > 0) 'jitterFactor': jitterFactor,
        'retryableErrors': retryableErrors,
        if (retryableExceptions.isNotEmpty)
          'retryableExceptions': retryableExceptions,
      };

  /// Deserialize from JSON.
  factory RetryConfig.fromJson(Map<String, dynamic> json) => RetryConfig(
        maxAttempts: json['maxAttempts'] as int? ?? 3,
        initialDelay: Duration(
          milliseconds: json['initialDelay'] as int? ?? 1000,
        ),
        maxDelay: Duration(
          milliseconds: json['maxDelay'] as int? ?? 60000,
        ),
        backoffMultiplier:
            (json['backoffMultiplier'] as num?)?.toDouble() ?? 2.0,
        jitterFactor: (json['jitterFactor'] as num?)?.toDouble() ?? 0.0,
        retryableErrors:
            (json['retryableErrors'] as List<dynamic>?)?.cast<String>() ??
                const [],
        retryableExceptions:
            (json['retryableExceptions'] as List<dynamic>?)?.cast<String>() ??
                const [],
      );

  /// Create a copy with modified fields.
  RetryConfig copyWith({
    int? maxAttempts,
    Duration? initialDelay,
    Duration? maxDelay,
    double? backoffMultiplier,
    double? jitterFactor,
    List<String>? retryableErrors,
    List<String>? retryableExceptions,
  }) =>
      RetryConfig(
        maxAttempts: maxAttempts ?? this.maxAttempts,
        initialDelay: initialDelay ?? this.initialDelay,
        maxDelay: maxDelay ?? this.maxDelay,
        backoffMultiplier: backoffMultiplier ?? this.backoffMultiplier,
        jitterFactor: jitterFactor ?? this.jitterFactor,
        retryableErrors: retryableErrors ?? this.retryableErrors,
        retryableExceptions: retryableExceptions ?? this.retryableExceptions,
      );
}

/// Checkpoint for resumable execution.
class Checkpoint {
  /// Unique checkpoint ID.
  final String id;

  /// Associated execution run ID.
  final String runId;

  /// Human-readable checkpoint name.
  final String name;

  /// Accumulated state at checkpoint time.
  final Map<String, dynamic> state;

  /// Completed stage outputs.
  final Map<String, StageOutput> stageOutputs;

  /// Last completed stage ID (resume point).
  final String? lastCompletedStage;

  /// Current execution state.
  final ExecutionState executionState;

  /// Checkpoint creation timestamp.
  final DateTime createdAt;

  /// Checkpoint expiration.
  final DateTime? expiresAt;

  /// Schema version for forward compatibility.
  final String schemaVersion;

  /// Additional checkpoint-specific data.
  final Map<String, dynamic>? metadata;

  const Checkpoint({
    required this.id,
    required this.runId,
    required this.name,
    required this.state,
    required this.stageOutputs,
    this.lastCompletedStage,
    this.executionState = ExecutionState.paused,
    required this.createdAt,
    this.expiresAt,
    this.schemaVersion = '1.0.0',
    this.metadata,
  });

  /// Check if checkpoint is expired.
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Check if checkpoint is resumable.
  bool get isResumable =>
      !isExpired &&
      (executionState == ExecutionState.paused ||
          executionState == ExecutionState.waitingReview ||
          executionState == ExecutionState.waitingApproval);

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'runId': runId,
        'name': name,
        'state': state,
        'stageOutputs': stageOutputs.map(
          (k, v) => MapEntry(k, v.toJson()),
        ),
        'lastCompletedStage': lastCompletedStage,
        'executionState': executionState.name,
        'createdAt': createdAt.toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        'schemaVersion': schemaVersion,
        if (metadata != null) 'metadata': metadata,
      };

  /// Deserialize from JSON.
  factory Checkpoint.fromJson(Map<String, dynamic> json) {
    return Checkpoint(
      id: json['id'] as String,
      runId: json['runId'] as String,
      name: json['name'] as String,
      state: json['state'] as Map<String, dynamic>,
      stageOutputs: (json['stageOutputs'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, StageOutput.fromJson(v as Map<String, dynamic>)),
      ),
      lastCompletedStage: json['lastCompletedStage'] as String?,
      executionState: ExecutionState.values.firstWhere(
        (e) => e.name == json['executionState'],
        orElse: () => ExecutionState.paused,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      schemaVersion: json['schemaVersion'] as String? ?? '1.0.0',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Execution state machine states.
enum ExecutionState {
  /// Pending execution.
  pending,

  /// Validating input.
  validating,

  /// Running stages.
  running,

  /// Waiting for review.
  waitingReview,

  /// Waiting for approval.
  waitingApproval,

  /// Paused (can be resumed).
  paused,

  /// Completed successfully.
  completed,

  /// Failed.
  failed,

  /// Cancelled.
  cancelled,

  /// Rolled back.
  rolledBack,
}

/// Checkpoint status for tracking.
enum CheckpointStatus {
  /// Checkpoint is active and resumable.
  active,

  /// Checkpoint was used to resume execution.
  resumed,

  /// Checkpoint expired and is no longer valid.
  expired,

  /// Checkpoint was superseded by a newer checkpoint.
  superseded,

  /// Checkpoint was manually invalidated.
  invalidated,
}
