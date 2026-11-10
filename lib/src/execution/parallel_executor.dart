/// Parallel Executor - Executes stages with dependency-aware parallelism.
///
/// Provides concurrent execution of independent stages using semaphore-based
/// concurrency control while respecting stage dependencies.
library;

import 'dart:async';
import 'dart:collection';

import '../models/execution_context.dart';
import '../models/stage.dart';
import 'stage_executor.dart';
import 'execution_engine.dart' show ExecutionEventListener;

/// Executes stages in parallel with concurrency control.
///
/// Key features:
/// - Dependency-aware execution ordering
/// - Semaphore-based concurrency limiting
/// - Parallel execution of independent stages
/// - Proper error propagation and cancellation
class ParallelStageExecutor {
  /// Stage executor for individual stage execution.
  final StageExecutor stageExecutor;

  /// Maximum concurrent stage executions.
  final int maxConcurrency;

  /// Event listener for execution events.
  final ExecutionEventListener? eventListener;

  /// Concurrency semaphore.
  late final Semaphore _semaphore;

  ParallelStageExecutor({
    required this.stageExecutor,
    this.maxConcurrency = 4,
    this.eventListener,
  }) {
    _semaphore = Semaphore(maxConcurrency);
  }

  /// Execute stages in parallel respecting dependencies.
  ///
  /// Builds a dependency graph and executes stages in topological order,
  /// running independent stages concurrently up to [maxConcurrency].
  ///
  /// Returns a flat list of [StageResult] for all stages.
  Future<List<StageResult>> executeParallel(
    List<Stage> stages,
    ExecutionContext context, {
    dynamic Function(Stage, ExecutionContext)? inputBuilder,
  }) async {
    final results = <String, StageResult>{};

    // Build dependency graph
    final graph = DependencyGraph(stages);

    // Validate graph (check for cycles)
    final cycleCheck = graph.detectCycles();
    if (cycleCheck != null) {
      throw ParallelExecutionException(
        'Circular dependency detected: ${cycleCheck.join(' -> ')}',
      );
    }

    // Get execution order (topological sort)
    final executionLevels = graph.getExecutionLevels();

    // Execute level by level
    for (final level in executionLevels) {
      final levelResults = await _executeLevel(
        level,
        stages,
        context,
        results,
        inputBuilder,
      );

      // Merge results
      for (final result in levelResults) {
        results[result.stageId] = result;
      }

      // Check for blocking failures
      final blockingFailures = levelResults.where(
        (r) => r.status == StageStatus.failed && _isBlockingFailure(r, stages),
      );

      if (blockingFailures.isNotEmpty) {
        // Cancel remaining stages
        final remaining = executionLevels
            .skip(executionLevels.indexOf(level) + 1)
            .expand((l) => l);

        for (final stageId in remaining) {
          results[stageId] = StageResult.skipped(
            stageId,
            'Cancelled due to upstream failure',
          );
        }
        break;
      }
    }

    return results.values.toList();
  }

  /// Execute a single level of stages in parallel.
  Future<List<StageResult>> _executeLevel(
    List<String> stageIds,
    List<Stage> allStages,
    ExecutionContext context,
    Map<String, StageResult> previousResults,
    dynamic Function(Stage, ExecutionContext)? inputBuilder,
  ) async {
    final stages =
        stageIds.map((id) => allStages.firstWhere((s) => s.id == id)).toList();

    // Execute all stages in this level concurrently with semaphore control
    final futures = stages.map((stage) async {
      // Check if dependencies succeeded
      if (!_checkDependencies(stage, previousResults)) {
        return StageResult.skipped(
          stage.id,
          'Dependency not satisfied',
        );
      }

      // Acquire semaphore permit
      await _semaphore.acquire();

      try {
        eventListener?.onStageStarted(stage.id, context.runId);

        final input = inputBuilder != null
            ? inputBuilder(stage, context)
            : context.getState('input');

        final result = await stageExecutor.executeWithRetry(
          stage,
          input,
          context,
        );

        // Record output to context
        if (result.status == StageStatus.completed) {
          context.recordStageOutput(
            stage.id,
            StageOutput(data: result.output, status: result.status),
          );

          eventListener?.onStageCompleted(
            stage.id,
            context.runId,
            result.duration ?? Duration.zero,
          );
        } else if (result.status == StageStatus.failed) {
          eventListener?.onStageFailed(
            stage.id,
            context.runId,
            result.error ?? 'Unknown error',
          );
        }

        return result;
      } finally {
        _semaphore.release();
      }
    });

    return Future.wait(futures);
  }

  /// Check if all dependencies of a stage have completed successfully.
  bool _checkDependencies(
    Stage stage,
    Map<String, StageResult> previousResults,
  ) {
    final dependencies = stage.dependsOn;
    if (dependencies == null || dependencies.isEmpty) {
      return true;
    }

    for (final depId in dependencies) {
      final depResult = previousResults[depId];
      if (depResult == null) return false;
      if (depResult.status != StageStatus.completed &&
          depResult.status != StageStatus.skipped) {
        return false;
      }
    }

    return true;
  }

  /// Check if a failure is blocking (prevents downstream execution).
  bool _isBlockingFailure(StageResult result, List<Stage> stages) {
    final stage = stages.firstWhere((s) => s.id == result.stageId);
    return stage.onFailure == OnFailure.fail;
  }
}

/// Exception thrown during parallel execution.
class ParallelExecutionException implements Exception {
  final String message;
  final String? stageId;
  final Object? cause;

  ParallelExecutionException(
    this.message, {
    this.stageId,
    this.cause,
  });

  @override
  String toString() => 'ParallelExecutionException: $message';
}

/// Dependency graph for stages (not part of the package barrel).
class DependencyGraph {
  /// Stage dependencies (stage ID -> list of dependency IDs).
  final Map<String, List<String>> _dependencies = {};

  /// Reverse dependencies (stage ID -> list of dependent IDs).
  final Map<String, List<String>> _dependents = {};

  /// All stage IDs.
  final Set<String> _stageIds = {};

  DependencyGraph(List<Stage> stages) {
    for (final stage in stages) {
      _stageIds.add(stage.id);
      _dependencies[stage.id] = stage.dependsOn ?? [];
      _dependents[stage.id] = [];
    }

    // Build reverse dependencies
    for (final stage in stages) {
      for (final depId in stage.dependsOn ?? []) {
        _dependents[depId]?.add(stage.id);
      }
    }
  }

  /// Detect cycles in the dependency graph.
  ///
  /// Returns the cycle path if found, null otherwise.
  List<String>? detectCycles() {
    final visited = <String>{};
    final recursionStack = <String>{};
    final path = <String>[];

    for (final stageId in _stageIds) {
      final cycle = _detectCyclesDfs(stageId, visited, recursionStack, path);
      if (cycle != null) return cycle;
    }

    return null;
  }

  List<String>? _detectCyclesDfs(
    String stageId,
    Set<String> visited,
    Set<String> recursionStack,
    List<String> path,
  ) {
    if (recursionStack.contains(stageId)) {
      // Found cycle - return path from stageId
      final cycleStart = path.indexOf(stageId);
      return [...path.sublist(cycleStart), stageId];
    }

    if (visited.contains(stageId)) return null;

    visited.add(stageId);
    recursionStack.add(stageId);
    path.add(stageId);

    for (final depId in _dependencies[stageId] ?? []) {
      final cycle = _detectCyclesDfs(depId, visited, recursionStack, path);
      if (cycle != null) return cycle;
    }

    recursionStack.remove(stageId);
    path.removeLast();
    return null;
  }

  /// Get execution levels (topological sort with grouping).
  ///
  /// Returns a list of levels, where each level contains stage IDs
  /// that can be executed in parallel.
  List<List<String>> getExecutionLevels() {
    final levels = <List<String>>[];
    final remaining = Set<String>.from(_stageIds);
    final completed = <String>{};

    while (remaining.isNotEmpty) {
      // Find stages with all dependencies satisfied
      final readyStages = remaining.where((stageId) {
        final deps = _dependencies[stageId] ?? [];
        return deps
            .every((d) => completed.contains(d) || !_stageIds.contains(d));
      }).toList();

      if (readyStages.isEmpty) {
        // This shouldn't happen if there are no cycles
        throw ParallelExecutionException(
          'Unable to resolve dependencies for: ${remaining.join(', ')}',
        );
      }

      levels.add(readyStages);
      remaining.removeAll(readyStages);
      completed.addAll(readyStages);
    }

    return levels;
  }

  /// Get stages that depend on a given stage.
  List<String> getDependents(String stageId) => _dependents[stageId] ?? [];

  /// Get dependencies of a given stage.
  List<String> getDependencies(String stageId) => _dependencies[stageId] ?? [];
}

/// Counting semaphore for concurrency control (not part of the package
/// barrel).
class Semaphore {
  /// Maximum concurrent permits.
  final int maxPermits;

  /// Currently held permits.
  int _permits = 0;

  /// Queue of waiting acquirers.
  final Queue<Completer<void>> _waiting = Queue();

  Semaphore(this.maxPermits);

  /// Number of permits currently in use.
  int get inUse => _permits;

  /// Number of available permits.
  int get available => maxPermits - _permits;

  /// Acquire a permit, waiting if necessary.
  Future<void> acquire() async {
    if (_permits < maxPermits) {
      _permits++;
      return;
    }

    final completer = Completer<void>();
    _waiting.add(completer);
    await completer.future;
    _permits++;
  }

  /// Release a permit.
  void release() {
    _permits--;
    if (_waiting.isNotEmpty) {
      final next = _waiting.removeFirst();
      next.complete();
    }
  }

  /// Try to acquire a permit without waiting.
  ///
  /// Returns true if permit was acquired, false otherwise.
  bool tryAcquire() {
    if (_permits < maxPermits) {
      _permits++;
      return true;
    }
    return false;
  }
}
