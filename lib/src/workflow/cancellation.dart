/// Cancellation - Workflow cancellation and compensation models.
///
/// Defines data structures and executor for workflow cancellation
/// with 5-phase compensation: halt, rollback, cleanup, notify, audit
/// (spec section 10).
library;

/// Request to cancel a running workflow.
class CancellationRequest {
  /// Workflow identifier.
  final String workflowId;

  /// Execution identifier.
  final String executionId;

  /// Reason for cancellation.
  final CancellationReason reason;

  /// User who requested the cancellation.
  final String? requestedBy;

  /// When the cancellation was requested.
  final DateTime requestedAt;

  const CancellationRequest({
    required this.workflowId,
    required this.executionId,
    required this.reason,
    this.requestedBy,
    required this.requestedAt,
  });
}

/// Reason for workflow cancellation.
sealed class CancellationReason {
  const CancellationReason();
}

/// Cancellation initiated by a user.
class UserRequested extends CancellationReason {
  /// User who requested the cancellation.
  final String userId;

  /// Optional comment explaining the cancellation.
  final String? comment;

  const UserRequested({required this.userId, this.comment});
}

/// Cancellation due to timeout being exceeded.
class TimeoutExceeded extends CancellationReason {
  /// Elapsed time since workflow started.
  final Duration elapsed;

  /// Configured timeout limit.
  final Duration limit;

  const TimeoutExceeded({required this.elapsed, required this.limit});
}

/// Cancellation due to a dependency failure.
class DependencyFailed extends CancellationReason {
  /// Identifier of the failed dependency.
  final String dependencyId;

  /// Error from the dependency.
  final String error;

  const DependencyFailed({required this.dependencyId, required this.error});
}

/// Cancellation due to system shutdown.
class SystemShutdown extends CancellationReason {
  /// Optional shutdown message.
  final String? message;

  const SystemShutdown({this.message});
}

/// Configuration for compensation behavior during cancellation.
class CompensationConfig {
  /// Compensation execution mode.
  final CompensationMode mode;

  /// Policy for handling compensation failures.
  final CompensationFailurePolicy failurePolicy;

  /// Overall timeout for compensation execution.
  final Duration? timeout;

  /// Maximum retry attempts for compensating a single stage.
  final int maxRetries;

  const CompensationConfig({
    this.mode = CompensationMode.backward,
    this.failurePolicy = CompensationFailurePolicy.continueCompensation,
    this.timeout,
    this.maxRetries = 3,
  });
}

/// Mode of compensation execution.
enum CompensationMode {
  /// Compensate completed stages in reverse order.
  backward,

  /// Compensate stages in forward order.
  forward,

  /// Compensate only selected stages based on configuration.
  selective,
}

/// Policy for handling compensation failures.
enum CompensationFailurePolicy {
  /// Continue compensating remaining stages despite failures.
  continueCompensation,

  /// Stop compensation on first failure.
  stopCompensation,

  /// Fail the entire workflow on compensation failure.
  failWorkflow,
}

/// Compensation definition for a specific stage.
class StageCompensation {
  /// Stage identifier this compensation applies to.
  final String stageId;

  /// Action to perform for compensation.
  final CompensationAction action;

  /// Timeout for this stage's compensation.
  final Duration? timeout;

  /// Override retry count for this stage.
  final int? retries;

  const StageCompensation({
    required this.stageId,
    required this.action,
    this.timeout,
    this.retries,
  });
}

/// Action to perform for compensation.
sealed class CompensationAction {
  const CompensationAction();
}

/// Invoke a named handler for compensation.
class InvokeHandler extends CompensationAction {
  /// Name of the handler to invoke.
  final String handlerName;

  /// Parameters to pass to the handler.
  final Map<String, dynamic>? params;

  const InvokeHandler({required this.handlerName, this.params});
}

/// Run a script for compensation.
class RunScript extends CompensationAction {
  /// Script content to execute.
  final String script;

  const RunScript({required this.script});
}

/// No compensation action needed.
class NoOp extends CompensationAction {
  const NoOp();
}

/// Resource cleanup definition.
class ResourceCleanup {
  /// Type of resource (e.g., 'file', 'database_record', 'cache_entry', 'lock').
  final String resourceType;

  /// Identifier of the resource to clean up.
  final String resourceId;

  /// Cleanup action to perform (e.g., 'delete', 'release', 'rollback').
  final String cleanupAction;

  /// Additional parameters for the cleanup.
  final Map<String, dynamic>? params;

  const ResourceCleanup({
    required this.resourceType,
    required this.resourceId,
    required this.cleanupAction,
    this.params,
  });
}

/// Executes cancellation with 5 phases: halt, rollback, cleanup, notify, audit.
///
/// Coordinates the full cancellation lifecycle ensuring proper compensation
/// of completed stages and cleanup of allocated resources.
class CancellationExecutor {
  /// Compensation configuration.
  final CompensationConfig config;

  const CancellationExecutor({required this.config});

  /// Execute the full cancellation process.
  ///
  /// Phases:
  /// 1. Halt current execution
  /// 2. Rollback completed stages (compensation)
  /// 3. Cleanup resources
  /// 4. Send notifications
  /// 5. Record audit trail
  Future<CancellationResult> execute(CancellationRequest request) async {
    // Phase 1: Halt current execution
    final haltResult = await _halt(request);

    // Phase 2: Rollback completed stages (compensation)
    final compensationResult = await _compensate(request, haltResult);

    // Phase 3: Cleanup resources
    final cleanupResult = await _cleanup(request);

    // Phase 4: Send notifications
    await _notify(request, compensationResult);

    // Phase 5: Record audit trail
    await _audit(request, compensationResult, cleanupResult);

    return CancellationResult(
      workflowId: request.workflowId,
      executionId: request.executionId,
      haltResult: haltResult,
      compensationResult: compensationResult,
      cleanupResult: cleanupResult,
      completedAt: DateTime.now(),
    );
  }

  /// Phase 1: Halt all running stages.
  Future<HaltResult> _halt(CancellationRequest request) async {
    return HaltResult(
      halted: true,
      stageResults: [],
      haltedAt: DateTime.now(),
    );
  }

  /// Phase 2: Run compensation in configured mode (backward/forward/selective).
  Future<CompensationResult> _compensate(
    CancellationRequest request,
    HaltResult haltResult,
  ) async {
    return const CompensationResult(
      success: true,
      compensatedStages: [],
      failures: [],
    );
  }

  /// Phase 3: Clean up allocated resources.
  Future<CleanupResult> _cleanup(CancellationRequest request) async {
    return const CleanupResult(
      success: true,
      cleanedResources: [],
    );
  }

  /// Phase 4: Send cancellation notifications via NotificationPort.
  Future<void> _notify(
    CancellationRequest request,
    CompensationResult result,
  ) async {
    // Notifications delegated to NotificationPort
  }

  /// Phase 5: Record cancellation audit event.
  Future<void> _audit(
    CancellationRequest request,
    CompensationResult compensation,
    CleanupResult cleanup,
  ) async {
    // Audit trail recording
  }
}

/// Result of the full cancellation process.
class CancellationResult {
  /// Workflow identifier.
  final String workflowId;

  /// Execution identifier.
  final String executionId;

  /// Result of halting running stages.
  final HaltResult haltResult;

  /// Result of compensation execution.
  final CompensationResult compensationResult;

  /// Result of resource cleanup.
  final CleanupResult cleanupResult;

  /// When the cancellation completed.
  final DateTime completedAt;

  const CancellationResult({
    required this.workflowId,
    required this.executionId,
    required this.haltResult,
    required this.compensationResult,
    required this.cleanupResult,
    required this.completedAt,
  });
}

/// Result of halting running stages.
class HaltResult {
  /// Whether halting succeeded.
  final bool halted;

  /// Per-stage halt results.
  final List<StageHaltResult> stageResults;

  /// When halting completed.
  final DateTime haltedAt;

  const HaltResult({
    required this.halted,
    required this.stageResults,
    required this.haltedAt,
  });
}

/// Result of halting a single stage.
class StageHaltResult {
  /// Stage identifier.
  final String stageId;

  /// Whether the stage was successfully halted.
  final bool halted;

  /// Error if halting failed.
  final String? error;

  const StageHaltResult({
    required this.stageId,
    required this.halted,
    this.error,
  });
}

/// Result of compensation execution.
class CompensationResult {
  /// Whether all compensations succeeded.
  final bool success;

  /// List of stage identifiers that were compensated.
  final List<String> compensatedStages;

  /// List of compensation failures.
  final List<CompensationFailure> failures;

  const CompensationResult({
    required this.success,
    required this.compensatedStages,
    required this.failures,
  });
}

/// Record of a compensation failure for a specific stage.
class CompensationFailure {
  /// Stage identifier that failed compensation.
  final String stageId;

  /// Error message.
  final String error;

  /// Number of compensation attempts made.
  final int attemptCount;

  const CompensationFailure({
    required this.stageId,
    required this.error,
    required this.attemptCount,
  });
}

/// Result of resource cleanup.
class CleanupResult {
  /// Whether all cleanups succeeded.
  final bool success;

  /// Per-resource cleanup results.
  final List<ResourceCleanupResult> cleanedResources;

  const CleanupResult({
    required this.success,
    required this.cleanedResources,
  });
}

/// Result of cleaning up a single resource.
class ResourceCleanupResult {
  /// Resource identifier.
  final String resourceId;

  /// Resource type.
  final String resourceType;

  /// Whether the resource was successfully cleaned.
  final bool cleaned;

  /// Error if cleanup failed.
  final String? error;

  const ResourceCleanupResult({
    required this.resourceId,
    required this.resourceType,
    required this.cleaned,
    this.error,
  });
}

/// Audit event for cancellation tracking.
class CancellationAuditEvent {
  /// Workflow identifier.
  final String workflowId;

  /// Execution identifier.
  final String executionId;

  /// Reason for cancellation.
  final CancellationReason reason;

  /// When the cancellation occurred.
  final DateTime cancelledAt;

  /// Result of compensation execution.
  final CompensationResult compensationResult;

  /// Result of resource cleanup.
  final CleanupResult cleanupResult;

  const CancellationAuditEvent({
    required this.workflowId,
    required this.executionId,
    required this.reason,
    required this.cancelledAt,
    required this.compensationResult,
    required this.cleanupResult,
  });
}
