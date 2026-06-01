/// The behavior engine — the unified "behavior definition" runtime.
///
/// Runs an ordered list of [BehaviorStep] over a `state` map. For each step
/// it evaluates the guard, routes the result to an outcome via `then`,
/// resolves the outcome to a control signal through the open
/// [OutcomeRegistry], and acts. The only physical things it does are:
/// run the action, advance, jump, suspend, halt, fail. Everything domain
/// (gate / approval / quality / wait) is expressed by authors as guards +
/// outcomes + tools that mutate state — never as engine concepts.
///
/// flow vs. runbook vs. pipeline = the same engine; only the [StateStore]
/// (ephemeral vs. durable) differs.
library;

import 'behavior_step.dart';
import 'guard.dart';
import 'outcome.dart';
import 'state_store.dart';

/// Runs a step's action. Host-supplied — the engine never invokes tools or
/// skills directly. Returns an output map merged into `state`, or null.
typedef ActionDispatcher = Future<Map<String, dynamic>?> Function(
  BehaviorAction action,
  Map<String, dynamic> state,
);

/// Result of a run / resume.
class EngineResult {
  final BehaviorRunStatus status;
  final Map<String, dynamic> state;

  /// Set when [status] is `suspended` — the step whose guard routed to a
  /// suspending outcome (e.g. `wait`).
  final String? waitingStepId;

  /// Set when [status] is `failed`.
  final String? error;

  const EngineResult({
    required this.status,
    required this.state,
    this.waitingStepId,
    this.error,
  });

  bool get isComplete => status == BehaviorRunStatus.completed;
  bool get isSuspended => status == BehaviorRunStatus.suspended;
  bool get isFailed => status == BehaviorRunStatus.failed;
}

/// The engine.
class BehaviorEngine {
  final OutcomeRegistry outcomes;
  final StateStore store;
  final ActionDispatcher dispatch;
  final GuardEvaluator guard;

  BehaviorEngine({
    required this.store,
    required this.dispatch,
    OutcomeRegistry? outcomes,
    this.guard = const GuardEvaluator(),
  }) : outcomes = outcomes ?? OutcomeRegistry.standard();

  /// Start a fresh run.
  Future<EngineResult> run(
    String runId,
    List<BehaviorStep> steps,
    Map<String, dynamic> initialState,
  ) async {
    final ordered = _order(steps);
    final first = ordered.isEmpty ? null : ordered.first.id;
    final run = BehaviorRunState(
      runId: runId,
      state: Map<String, dynamic>.from(initialState),
      cursorStepId: first,
      status: BehaviorRunStatus.running,
    );
    return _drive(run, ordered);
  }

  /// Resume a suspended run. [statePatch] is merged into the run's state
  /// first — this is how a waiting guard gets unblocked (e.g. an approver
  /// resumes with `{approved: true}`). Then the suspended step's guard is
  /// re-evaluated against the updated state and execution continues if it no
  /// longer waits.
  Future<EngineResult> resume(
    String runId,
    List<BehaviorStep> steps, {
    Map<String, dynamic>? statePatch,
  }) async {
    final run = await store.load(runId);
    if (run == null) {
      throw StateError('No run to resume: $runId');
    }
    if (run.status != BehaviorRunStatus.suspended) {
      return EngineResult(status: run.status, state: run.state);
    }
    final state = <String, dynamic>{...run.state, ...?statePatch};
    return _drive(
      run.copyWith(state: state, status: BehaviorRunStatus.running),
      _order(steps),
    );
  }

  Future<EngineResult> _drive(
    BehaviorRunState start,
    List<BehaviorStep> ordered,
  ) async {
    final index = <String, int>{
      for (var i = 0; i < ordered.length; i++) ordered[i].id: i,
    };
    var state = Map<String, dynamic>.from(start.state);
    final completed = List<String>.from(start.completed);
    var i = start.cursorStepId == null
        ? ordered.length
        : (index[start.cursorStepId] ?? 0);

    while (i < ordered.length) {
      final step = ordered[i];

      final value = step.when == null
          ? true
          : guard.evaluate(step.when!, state);
      final token = _route(step, value);
      final signal = outcomes.resolve(token, step, state);

      switch (signal.primitive) {
        case ControlPrimitive.suspend:
          final suspended = BehaviorRunState(
            runId: start.runId,
            state: state,
            cursorStepId: step.id,
            status: BehaviorRunStatus.suspended,
            completed: completed,
          );
          await store.save(suspended);
          return EngineResult(
            status: BehaviorRunStatus.suspended,
            state: state,
            waitingStepId: step.id,
          );

        case ControlPrimitive.halt:
          return _finish(start, state, completed,
              BehaviorRunStatus.completed);

        case ControlPrimitive.fail:
          return _finish(start, state, completed, BehaviorRunStatus.failed,
              error: signal.message ?? 'failed at ${step.id}');

        case ControlPrimitive.next:
        case ControlPrimitive.goto:
          if (signal.runAction && step.action != null) {
            try {
              final out = await dispatch(step.action!, state);
              if (out != null) {
                state.addAll(out);
                state[step.id] = out;
              }
            } catch (e) {
              if (step.onFailure != null &&
                  index.containsKey(step.onFailure)) {
                completed.add(step.id);
                i = index[step.onFailure]!;
                continue;
              }
              return _finish(start, state, completed,
                  BehaviorRunStatus.failed,
                  error: '${step.id}: $e');
            }
          }
          completed.add(step.id);
          if (signal.primitive == ControlPrimitive.goto) {
            final target = signal.gotoId;
            if (target == null || !index.containsKey(target)) {
              return _finish(start, state, completed,
                  BehaviorRunStatus.failed,
                  error: 'goto target not found: $target (${step.id})');
            }
            i = index[target]!;
          } else {
            i++;
          }
      }
    }

    return _finish(start, state, completed, BehaviorRunStatus.completed);
  }

  Future<EngineResult> _finish(
    BehaviorRunState start,
    Map<String, dynamic> state,
    List<String> completed,
    BehaviorRunStatus status, {
    String? error,
  }) async {
    await store.save(BehaviorRunState(
      runId: start.runId,
      state: state,
      cursorStepId: null,
      status: status,
      completed: completed,
    ));
    return EngineResult(status: status, state: state, error: error);
  }

  /// Route a guard result to an outcome token. Explicit `then[value]` wins,
  /// then `then['']` (default), else the engine fallback: truthy → proceed,
  /// falsy → skip (legacy `condition`-as-skip-guard semantics).
  String _route(BehaviorStep step, dynamic value) {
    final key = '$value';
    if (step.then.containsKey(key)) return step.then[key]!;
    if (step.then.containsKey('')) return step.then['']!;
    return GuardEvaluator.truthy(value) ? 'proceed' : 'skip';
  }

  /// Order steps: topological by `dependsOn` where present, otherwise
  /// declaration order. Unresolvable / cyclic deps fall back to declaration
  /// order so authoring slips still execute.
  List<BehaviorStep> _order(List<BehaviorStep> steps) {
    if (steps.every((s) => s.dependsOn.isEmpty)) return steps;
    final byId = {for (final s in steps) s.id: s};
    final visited = <String>{};
    final out = <BehaviorStep>[];
    void visit(BehaviorStep s, Set<String> path) {
      if (visited.contains(s.id) || path.contains(s.id)) return;
      path.add(s.id);
      for (final dep in s.dependsOn) {
        final d = byId[dep];
        if (d != null) visit(d, path);
      }
      path.remove(s.id);
      if (visited.add(s.id)) out.add(s);
    }

    for (final s in steps) {
      visit(s, <String>{});
    }
    // Append any not reached (declaration order safety net).
    for (final s in steps) {
      if (!visited.contains(s.id)) {
        visited.add(s.id);
        out.add(s);
      }
    }
    return out;
  }
}
