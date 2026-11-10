/// Behavior step model — the unit of a "behavior definition" (the unified
/// successor to flow / runbook / pipeline steps).
///
/// A step is purely declarative:
/// - `do`    — the action to run (a tool or skill invocation).
/// - `when`  — a guard expression over `state` (optional).
/// - `then`  — maps the guard result (stringified) to an outcome name.
/// - `dependsOn` / `onFailure` — ordering and failure routing.
///
/// The set of outcome names is open (see `OutcomeRegistry`); the step never
/// encodes control behavior directly, only which outcome a guard result
/// maps to.
library;

/// An action a step performs — a tool or skill invocation. The engine itself
/// does not run it; a host-supplied dispatcher does.
class BehaviorAction {
  /// Invocation kind: `tool` or `skill`.
  final String kind;

  /// Tool name or skill id.
  final String ref;

  /// Arguments / inputs for the invocation.
  final Map<String, dynamic> args;

  /// The step this action belongs to. The engine fills it on every dispatch
  /// so the dispatcher can tell which step it is running; null on an action
  /// built by hand. Runtime context, so it is not part of the JSON form.
  final String? stepId;

  const BehaviorAction({
    required this.kind,
    required this.ref,
    this.args = const {},
    this.stepId,
  });

  factory BehaviorAction.fromJson(Map<String, dynamic> json) {
    // Accept `{tool, args}` or `{skill, inputs}` shorthand, or explicit
    // `{kind, ref, args}`.
    if (json['kind'] != null && json['ref'] != null) {
      return BehaviorAction(
        kind: json['kind'] as String,
        ref: json['ref'] as String,
        args: _map(json['args']),
      );
    }
    if (json['tool'] != null) {
      return BehaviorAction(
        kind: 'tool',
        ref: json['tool'] as String,
        args: _map(json['args']),
      );
    }
    if (json['skill'] != null) {
      return BehaviorAction(
        kind: 'skill',
        ref: json['skill'] as String,
        args: _map(json['inputs'] ?? json['args']),
      );
    }
    throw const FormatException(
        'BehaviorAction requires one of: {kind,ref} | {tool} | {skill}');
  }

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'ref': ref,
        if (args.isNotEmpty) 'args': args,
      };

  static Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : const {};
}

/// A single behavior step.
class BehaviorStep {
  /// Unique id within the definition.
  final String id;

  /// The action to run when this step's outcome is `proceed`. Optional — a
  /// pure gate step (guard only) may omit it.
  final BehaviorAction? action;

  /// Guard expression over `state`. Absent → always `proceed`.
  final String? when;

  /// Maps the stringified guard result to an outcome name. A `''` (empty)
  /// key is the default route. When absent, routing falls back to the
  /// engine default (truthy → proceed, falsy → skip) — preserving legacy
  /// `condition`-as-skip-guard semantics.
  final Map<String, String> then;

  /// Step ids this step depends on (must complete first).
  final List<String> dependsOn;

  /// Step id to jump to when the action throws. Absent → the run fails.
  final String? onFailure;

  const BehaviorStep({
    required this.id,
    this.action,
    this.when,
    this.then = const {},
    this.dependsOn = const [],
    this.onFailure,
  });

  factory BehaviorStep.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const FormatException('BehaviorStep requires a non-empty id');
    }
    return BehaviorStep(
      id: id,
      action: json['do'] != null
          ? BehaviorAction.fromJson(
              Map<String, dynamic>.from(json['do'] as Map))
          : null,
      when: json['when'] as String?,
      then: (json['then'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ??
          const {},
      dependsOn:
          (json['dependsOn'] as List?)?.map((e) => '$e').toList() ?? const [],
      onFailure: json['onFailure'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (action != null) 'do': action!.toJson(),
        if (when != null) 'when': when,
        if (then.isNotEmpty) 'then': then,
        if (dependsOn.isNotEmpty) 'dependsOn': dependsOn,
        if (onFailure != null) 'onFailure': onFailure,
      };
}
