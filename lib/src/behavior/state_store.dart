/// State store — the durability boundary for the behavior engine.
///
/// `state` (a `Map<String, dynamic>`) is the single source of truth for a
/// run: every decision and resume reads from it. A run is persisted as a
/// [BehaviorRunState]. The store choice is the *only* difference between an
/// ephemeral execution (flow profile) and a durable one (runbook profile) —
/// in-memory vs. a backing store that survives restarts.
library;

import 'dart:convert';

/// Status of a behavior run.
enum BehaviorRunStatus {
  /// Currently executing (transient).
  running,

  /// Suspended on a step whose outcome was `wait`; awaiting state change.
  suspended,

  /// Finished successfully (ran to end or `stop`).
  completed,

  /// Failed (action threw with no `onFailure`, or `fail` outcome).
  failed,
}

/// Persisted snapshot of a run.
class BehaviorRunState {
  final String runId;

  /// Mutable working state — the source of truth.
  final Map<String, dynamic> state;

  /// Id of the step the run is positioned at (the next to evaluate, or the
  /// suspended one).
  final String? cursorStepId;

  final BehaviorRunStatus status;

  /// Step ids already completed (so resume does not re-run them).
  final List<String> completed;

  const BehaviorRunState({
    required this.runId,
    required this.state,
    required this.cursorStepId,
    required this.status,
    this.completed = const [],
  });

  BehaviorRunState copyWith({
    Map<String, dynamic>? state,
    String? cursorStepId,
    BehaviorRunStatus? status,
    List<String>? completed,
  }) {
    return BehaviorRunState(
      runId: runId,
      state: state ?? this.state,
      cursorStepId: cursorStepId ?? this.cursorStepId,
      status: status ?? this.status,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() => {
        'runId': runId,
        'state': state,
        if (cursorStepId != null) 'cursorStepId': cursorStepId,
        'status': status.name,
        if (completed.isNotEmpty) 'completed': completed,
      };

  factory BehaviorRunState.fromJson(Map<String, dynamic> json) {
    return BehaviorRunState(
      runId: json['runId'] as String,
      state: Map<String, dynamic>.from(json['state'] as Map? ?? const {}),
      cursorStepId: json['cursorStepId'] as String?,
      status: BehaviorRunStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => BehaviorRunStatus.running,
      ),
      completed:
          (json['completed'] as List?)?.map((e) => '$e').toList() ?? const [],
    );
  }
}

/// Persistence boundary for runs.
abstract class StateStore {
  Future<void> save(BehaviorRunState run);
  Future<BehaviorRunState?> load(String runId);
  Future<void> delete(String runId);
}

/// Durable store — the runbook profile. Persists each run as JSON through an
/// injected key/value backend, so a suspended run survives process restarts.
/// The backend is supplied as three functions to keep this module free of
/// any specific storage-port dependency; hosts adapt their real KV port.
class KvStateStore implements StateStore {
  final Future<void> Function(String key, String value) writeKv;
  final Future<String?> Function(String key) readKv;
  final Future<void> Function(String key) removeKv;

  /// Key namespace for run records.
  final String prefix;

  const KvStateStore({
    required this.writeKv,
    required this.readKv,
    required this.removeKv,
    this.prefix = 'behavior/run/',
  });

  String _key(String runId) => '$prefix$runId';

  @override
  Future<void> save(BehaviorRunState run) =>
      writeKv(_key(run.runId), jsonEncode(run.toJson()));

  @override
  Future<BehaviorRunState?> load(String runId) async {
    final raw = await readKv(_key(runId));
    if (raw == null) return null;
    return BehaviorRunState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> delete(String runId) => removeKv(_key(runId));
}

/// In-memory store — the ephemeral profile. A suspended run survives only
/// for the process lifetime.
class EphemeralStateStore implements StateStore {
  final Map<String, BehaviorRunState> _runs = {};

  @override
  Future<void> save(BehaviorRunState run) async {
    _runs[run.runId] = run;
  }

  @override
  Future<BehaviorRunState?> load(String runId) async => _runs[runId];

  @override
  Future<void> delete(String runId) async {
    _runs.remove(runId);
  }
}
