/// A registered, runnable behavior definition — an engine bound to a fixed
/// step list. Hosts register these in `OpsRuntime.behaviorRegistry` (the
/// behavior-category counterpart to the workflow / runbook registries).
library;

import 'behavior_engine.dart';
import 'behavior_step.dart';
import 'state_store.dart';

/// Binds a [BehaviorEngine] to a definition's steps so it can be run or
/// resumed by id.
class BehaviorRunnable {
  final BehaviorEngine engine;
  final List<BehaviorStep> steps;

  const BehaviorRunnable(this.engine, this.steps);

  /// Start a fresh run.
  Future<EngineResult> run(String runId, Map<String, dynamic> input) =>
      engine.run(runId, steps, input);

  /// Resume a suspended run, optionally merging [statePatch] into its state
  /// first (e.g. `{approved: true}` to unblock an approval guard).
  Future<EngineResult> resume(String runId, {Map<String, dynamic>? statePatch}) =>
      engine.resume(runId, steps, statePatch: statePatch);

  /// The store backing this runnable — ephemeral or durable.
  StateStore get store => engine.store;
}
