/// Recovery Manager - Orchestrates execution recovery strategies.
///
/// Provides checkpoint-based resume, rollback-and-retry, skip-and-continue,
/// and manual intervention workflows for failed pipeline executions.
library;

import '../execution/checkpoint_manager.dart';
import '../models/execution_context.dart';
import '../observability/logger.dart';

import 'ops_exception.dart';
import 'rollback_handler.dart';

// ---------------------------------------------------------------------------
// Strategy and status enums
// ---------------------------------------------------------------------------

/// Strategy for recovering a failed execution.
enum RecoveryStrategy {
  /// Resume execution from the last successful checkpoint.
  resumeFromCheckpoint,

  /// Rollback completed stages and retry from the beginning.
  rollbackAndRetry,

  /// Skip the failed stage and continue with remaining stages.
  skipAndContinue,

  /// Flag execution for manual intervention; do not auto-recover.
  manualIntervention,
}

/// Status of a recovery attempt.
enum RecoveryStatus {
  /// Execution was resumed from a checkpoint.
  resumed,

  /// Stages were rolled back and execution is ready for retry.
  readyForRetry,

  /// Recovery failed and the execution cannot be resumed.
  failed,

  /// Execution is awaiting manual intervention.
  awaitingManual,
}

// ---------------------------------------------------------------------------
// Result
// ---------------------------------------------------------------------------

/// Result of a recovery attempt.
class RecoveryResult {
  /// Run ID of the recovered execution.
  final String runId;

  /// Recovery outcome status.
  final RecoveryStatus status;

  /// Stage from which execution should resume (if applicable).
  final String? resumeFromStage;

  /// Restored state to use when resuming (if applicable).
  final Map<String, dynamic>? state;

  /// Human-readable message describing the recovery outcome.
  final String? message;

  const RecoveryResult({
    required this.runId,
    required this.status,
    this.resumeFromStage,
    this.state,
    this.message,
  });

  /// Whether recovery succeeded (resumed or ready for retry).
  bool get isSuccessful =>
      status == RecoveryStatus.resumed ||
      status == RecoveryStatus.readyForRetry;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'runId': runId,
        'status': status.name,
        if (resumeFromStage != null) 'resumeFromStage': resumeFromStage,
        if (state != null) 'state': state,
        if (message != null) 'message': message,
      };
}

// ---------------------------------------------------------------------------
// Recovery manager
// ---------------------------------------------------------------------------

/// Orchestrates recovery of failed pipeline executions.
///
/// Supports multiple recovery strategies: checkpoint-based resume,
/// rollback-and-retry, skip-and-continue, and manual intervention.
class RecoveryManager {
  final CheckpointManager _checkpointManager;
  final RollbackHandler _rollbackHandler;
  final ExecutionLogger _logger;

  /// Creates a [RecoveryManager].
  ///
  /// Requires a [CheckpointManager] for checkpoint operations, a
  /// [RollbackHandler] for rollback operations, and an [ExecutionLogger]
  /// for structured logging.
  RecoveryManager({
    required CheckpointManager checkpointManager,
    required RollbackHandler rollbackHandler,
    required ExecutionLogger logger,
  })  : _checkpointManager = checkpointManager,
        _rollbackHandler = rollbackHandler,
        _logger = logger;

  /// Attempt recovery of a failed execution run.
  ///
  /// Applies the given [strategy] to the execution identified by [runId],
  /// using [context] for configuration and state access.
  ///
  /// Returns a [RecoveryResult] describing the outcome.
  Future<RecoveryResult> recover(
    String runId,
    RecoveryStrategy strategy,
    ExecutionContext context,
  ) async {
    _logger.info('Starting recovery', {
      'runId': runId,
      'strategy': strategy.name,
    });

    try {
      switch (strategy) {
        case RecoveryStrategy.resumeFromCheckpoint:
          return await _resumeFromCheckpoint(runId, context);
        case RecoveryStrategy.rollbackAndRetry:
          return await _rollbackAndRetry(runId, context);
        case RecoveryStrategy.skipAndContinue:
          return await _skipAndContinue(runId, context);
        case RecoveryStrategy.manualIntervention:
          return _requestManualIntervention(runId, context);
      }
    } on OpsException {
      rethrow;
    } catch (e, stack) {
      _logger.error('Recovery failed with unexpected error', error: e, context: {'stackTrace': stack.toString()});

      return RecoveryResult(
        runId: runId,
        status: RecoveryStatus.failed,
        message: 'Recovery failed: $e',
      );
    }
  }

  /// Resume execution from the most recent valid checkpoint.
  Future<RecoveryResult> _resumeFromCheckpoint(
    String runId,
    ExecutionContext context,
  ) async {
    _logger.info('Attempting resume from checkpoint', {
      'runId': runId,
    });

    final checkpoint = await _checkpointManager.loadLatest(runId);

    if (checkpoint == null) {
      _logger.warn('No valid checkpoint found for resume', {
        'runId': runId,
      });

      throw PermanentOpsException(
        'No valid checkpoint found for run: $runId',
        code: 'OPS-EXEC-009',
        details: {'runId': runId},
      );
    }

    if (checkpoint.isExpired) {
      _logger.warn('Latest checkpoint is expired', {
        'runId': runId,
        'checkpointId': checkpoint.id,
        'expiresAt': checkpoint.expiresAt?.toIso8601String(),
      });

      throw PermanentOpsException(
        'Latest checkpoint for run $runId has expired',
        code: 'OPS-EXEC-009',
        details: {
          'runId': runId,
          'checkpointId': checkpoint.id,
        },
      );
    }

    if (!checkpoint.isResumable) {
      _logger.warn('Checkpoint is not in a resumable state', {
        'runId': runId,
        'checkpointId': checkpoint.id,
        'executionState': checkpoint.executionState.name,
      });

      throw PermanentOpsException(
        'Checkpoint ${checkpoint.id} is not resumable '
            '(state: ${checkpoint.executionState.name})',
        code: 'OPS-EXEC-009',
        details: {
          'runId': runId,
          'checkpointId': checkpoint.id,
          'executionState': checkpoint.executionState.name,
        },
      );
    }

    // Mark checkpoint as resumed
    await _checkpointManager.markResumed(checkpoint.id);

    _logger.info('Resuming from checkpoint', {
      'runId': runId,
      'checkpointId': checkpoint.id,
      'lastCompletedStage': checkpoint.lastCompletedStage,
    });

    return RecoveryResult(
      runId: runId,
      status: RecoveryStatus.resumed,
      resumeFromStage: checkpoint.lastCompletedStage,
      state: Map<String, dynamic>.from(checkpoint.state),
      message: 'Resumed from checkpoint ${checkpoint.id}'
          '${checkpoint.lastCompletedStage != null ? ' after stage ${checkpoint.lastCompletedStage}' : ''}',
    );
  }

  /// Rollback completed stages and prepare for a fresh retry.
  Future<RecoveryResult> _rollbackAndRetry(
    String runId,
    ExecutionContext context,
  ) async {
    _logger.info('Attempting rollback and retry', {
      'runId': runId,
    });

    // Load latest checkpoint to get stage outputs for rollback
    final checkpoint = await _checkpointManager.loadLatest(runId);

    if (checkpoint == null) {
      _logger.warn('No checkpoint found; rollback without state', {
        'runId': runId,
      });

      // No checkpoint available - attempt rollback from context state
      final stageOutputs = _extractStageOutputsFromContext(context);

      if (stageOutputs.isEmpty) {
        return RecoveryResult(
          runId: runId,
          status: RecoveryStatus.readyForRetry,
          message: 'No stages to rollback; ready for retry',
        );
      }

      final rollbackResult = await _rollbackHandler.rollback(
        context,
        stageOutputs,
        const RollbackConfig(enabled: true, autoRollback: true),
      );

      if (rollbackResult.status == RollbackStatus.error) {
        throw PermanentOpsException(
          'Rollback failed: ${rollbackResult.message}',
          code: 'OPS-EXEC-005',
          details: {'runId': runId},
        );
      }

      // Invalidate all checkpoints for this run
      await _checkpointManager.invalidateForRun(runId);

      return RecoveryResult(
        runId: runId,
        status: RecoveryStatus.readyForRetry,
        message: 'Rollback completed (${rollbackResult.status.name}); '
            'ready for retry',
      );
    }

    // Build stage outputs map from checkpoint
    final stageOutputs = <String, dynamic>{};
    for (final entry in checkpoint.stageOutputs.entries) {
      stageOutputs[entry.key] = entry.value.data;
    }

    final rollbackResult = await _rollbackHandler.rollback(
      context,
      stageOutputs,
      const RollbackConfig(enabled: true, autoRollback: true),
    );

    if (rollbackResult.status == RollbackStatus.error) {
      throw PermanentOpsException(
        'Rollback failed: ${rollbackResult.message}',
        code: 'OPS-EXEC-005',
        details: {
          'runId': runId,
          'checkpointId': checkpoint.id,
        },
      );
    }

    // Invalidate all checkpoints for this run after successful rollback
    await _checkpointManager.invalidateForRun(runId);

    _logger.info('Rollback and retry preparation complete', {
      'runId': runId,
      'rollbackStatus': rollbackResult.status.name,
      'stagesRolledBack': rollbackResult.stageResults.length,
    });

    return RecoveryResult(
      runId: runId,
      status: RecoveryStatus.readyForRetry,
      message: 'Rollback completed (${rollbackResult.status.name}); '
          'ready for retry from the beginning',
    );
  }

  /// Skip the failed stage and continue from the next one.
  Future<RecoveryResult> _skipAndContinue(
    String runId,
    ExecutionContext context,
  ) async {
    _logger.info('Attempting skip and continue', {
      'runId': runId,
    });

    final checkpoint = await _checkpointManager.loadLatest(runId);

    if (checkpoint == null) {
      _logger.warn('No checkpoint found for skip and continue', {
        'runId': runId,
      });

      throw PermanentOpsException(
        'No checkpoint found for run: $runId; '
            'cannot determine which stage to skip',
        code: 'OPS-EXEC-009',
        details: {'runId': runId},
      );
    }

    // The stage after lastCompletedStage is the one that failed;
    // we skip it by resuming from the last completed stage with a
    // marker in state indicating the next stage should be skipped.
    final state = Map<String, dynamic>.from(checkpoint.state);
    state['_skipNextStage'] = true;

    // Mark checkpoint as resumed
    await _checkpointManager.markResumed(checkpoint.id);

    final skippedInfo = checkpoint.lastCompletedStage != null
        ? 'after stage ${checkpoint.lastCompletedStage}'
        : 'from the beginning';

    _logger.info('Skip and continue prepared', {
      'runId': runId,
      'resumeFrom': checkpoint.lastCompletedStage,
    });

    return RecoveryResult(
      runId: runId,
      status: RecoveryStatus.resumed,
      resumeFromStage: checkpoint.lastCompletedStage,
      state: state,
      message: 'Resuming $skippedInfo with failed stage skipped',
    );
  }

  /// Flag the execution for manual intervention.
  RecoveryResult _requestManualIntervention(
    String runId,
    ExecutionContext context,
  ) {
    _logger.info('Flagging for manual intervention', {
      'runId': runId,
    });

    return RecoveryResult(
      runId: runId,
      status: RecoveryStatus.awaitingManual,
      message: 'Execution $runId requires manual intervention',
    );
  }

  /// Extract stage outputs from the execution context state.
  Map<String, dynamic> _extractStageOutputsFromContext(
    ExecutionContext context,
  ) {
    final stages = context.state['stages'];
    if (stages is Map<String, dynamic>) {
      return Map<String, dynamic>.from(stages);
    }
    return {};
  }
}
