/// Outcomes — the open registry that turns a step's routed outcome name into
/// a control action.
///
/// The engine has only a small, fixed set of *physical* control primitives a
/// stepper can perform (advance, jump, suspend, halt) — you cannot have
/// infinitely many physical operations. What IS open is the *named* layer:
/// any number of outcome names (`proceed`, `skip`, `wait`, `stop`, `retry`,
/// `escalate`, …) register a handler that composes the primitives. New
/// behavior = register a handler; the engine core never grows a switch.
library;

import 'behavior_step.dart';

/// Physical control primitives the engine can execute.
enum ControlPrimitive {
  /// Move to the next step in order.
  next,

  /// Jump to a specific step id.
  goto,

  /// Suspend the run, persisting state, to be resumed later.
  suspend,

  /// Terminate the run successfully.
  halt,

  /// Fail the run.
  fail,
}

/// The signal a handler returns to drive the engine loop.
class ControlSignal {
  final ControlPrimitive primitive;

  /// Whether the step's `do` action should run before advancing. Only
  /// meaningful for `next` / `goto`.
  final bool runAction;

  /// Target step id for `goto`.
  final String? gotoId;

  /// Optional message (e.g. fail reason).
  final String? message;

  const ControlSignal(
    this.primitive, {
    this.runAction = false,
    this.gotoId,
    this.message,
  });

  static const ControlSignal proceed =
      ControlSignal(ControlPrimitive.next, runAction: true);
  static const ControlSignal skip = ControlSignal(ControlPrimitive.next);
  static const ControlSignal wait = ControlSignal(ControlPrimitive.suspend);
  static const ControlSignal stop = ControlSignal(ControlPrimitive.halt);
}

/// Context passed to an outcome handler.
class OutcomeContext {
  final BehaviorStep step;
  final Map<String, dynamic> state;

  /// The raw outcome token routed to this handler — lets a parameterized
  /// handler read its argument (e.g. `goto:review`).
  final String token;

  const OutcomeContext(this.step, this.state, this.token);
}

/// A handler: maps an outcome occurrence to a control signal.
typedef OutcomeHandler = ControlSignal Function(OutcomeContext ctx);

/// Open registry of outcome handlers. Resolution supports a `name:arg`
/// form so a single handler can be parameterized (e.g. `goto:<id>`).
class OutcomeRegistry {
  final Map<String, OutcomeHandler> _handlers = {};

  OutcomeRegistry();

  /// A registry preloaded with the standard outcomes.
  factory OutcomeRegistry.standard() {
    final r = OutcomeRegistry();
    r.register('proceed', (_) => ControlSignal.proceed);
    r.register('skip', (_) => ControlSignal.skip);
    r.register('wait', (_) => ControlSignal.wait);
    r.register('stop', (_) => ControlSignal.stop);
    r.register(
      'goto',
      (ctx) => ControlSignal(
        ControlPrimitive.goto,
        gotoId: _arg(ctx.token),
      ),
    );
    r.register(
      'fail',
      (ctx) => ControlSignal(ControlPrimitive.fail, message: _arg(ctx.token)),
    );
    return r;
  }

  void register(String name, OutcomeHandler handler) {
    _handlers[name] = handler;
  }

  bool has(String name) => _handlers.containsKey(_name(name));

  /// Resolve a routed outcome [token] (`name` or `name:arg`) to a signal.
  ControlSignal resolve(String token, BehaviorStep step, Map<String, dynamic> state) {
    final handler = _handlers[_name(token)];
    if (handler == null) {
      throw StateError('Unknown outcome: "$token" (step ${step.id})');
    }
    return handler(OutcomeContext(step, state, token));
  }

  static String _name(String token) {
    final i = token.indexOf(':');
    return i < 0 ? token : token.substring(0, i);
  }

  static String? _arg(String token) {
    final i = token.indexOf(':');
    return i < 0 ? null : token.substring(i + 1);
  }
}
