/// Execution State Machine - Validates state transitions during execution.
///
/// Implements the state machine defined in the execution model design doc
/// section 8, with 10 states and validated transitions. Tracks transition
/// history for observability and debugging.
library;

import '../models/execution_context.dart';

/// Valid state transitions for the execution state machine.
///
/// Enforces the transition rules from the execution model:
/// - pending -> validating, cancelled
/// - validating -> running, failed, cancelled
/// - running -> waitingReview, waitingApproval, paused, completed, failed, cancelled
/// - waitingReview -> running, failed, cancelled
/// - waitingApproval -> running, failed, cancelled
/// - paused -> running, cancelled
/// - failed -> rolledBack
/// - completed, cancelled, rolledBack -> (terminal, no transitions)
class ExecutionStateMachine {
  static const Map<ExecutionState, Set<ExecutionState>> _validTransitions = {
    ExecutionState.pending: {
      ExecutionState.validating,
      ExecutionState.cancelled,
    },
    ExecutionState.validating: {
      ExecutionState.running,
      ExecutionState.failed,
      ExecutionState.cancelled,
    },
    ExecutionState.running: {
      ExecutionState.waitingReview,
      ExecutionState.waitingApproval,
      ExecutionState.paused,
      ExecutionState.completed,
      ExecutionState.failed,
      ExecutionState.cancelled,
    },
    ExecutionState.waitingReview: {
      ExecutionState.running,
      ExecutionState.failed,
      ExecutionState.cancelled,
    },
    ExecutionState.waitingApproval: {
      ExecutionState.running,
      ExecutionState.failed,
      ExecutionState.cancelled,
    },
    ExecutionState.paused: {
      ExecutionState.running,
      ExecutionState.cancelled,
    },
    ExecutionState.failed: {
      ExecutionState.rolledBack,
    },
    ExecutionState.completed: {},
    ExecutionState.cancelled: {},
    ExecutionState.rolledBack: {},
  };

  ExecutionState _currentState;
  final List<StateTransition> _history = [];

  /// Create a state machine starting in the given state.
  ExecutionStateMachine([ExecutionState initialState = ExecutionState.pending])
      : _currentState = initialState;

  /// Get current state.
  ExecutionState get currentState => _currentState;

  /// Get transition history.
  List<StateTransition> get history => List.unmodifiable(_history);

  /// Check if a transition to the target state is valid.
  bool canTransitionTo(ExecutionState target) {
    final validTargets = _validTransitions[_currentState];
    return validTargets != null && validTargets.contains(target);
  }

  /// Get valid transitions from current state.
  List<ExecutionState> get validTransitions {
    return List.unmodifiable(_validTransitions[_currentState]?.toList() ?? []);
  }

  /// Transition to a new state with validation.
  ///
  /// Throws [StateError] if the transition is not valid.
  void transitionTo(
    ExecutionState target, {
    String? reason,
    Map<String, dynamic>? metadata,
  }) {
    if (!canTransitionTo(target)) {
      throw StateError(
        'Invalid state transition: $_currentState -> $target. '
        'Valid transitions from $_currentState: '
        '${validTransitions.join(", ")}',
      );
    }

    final transition = StateTransition(
      from: _currentState,
      to: target,
      timestamp: DateTime.now(),
      reason: reason,
      metadata: metadata,
    );

    _history.add(transition);
    _currentState = target;
  }

  /// Check if in a terminal state (no further transitions possible).
  bool get isTerminal =>
      _currentState == ExecutionState.completed ||
      _currentState == ExecutionState.failed ||
      _currentState == ExecutionState.cancelled ||
      _currentState == ExecutionState.rolledBack;

  /// Check if in a running/active state (not terminal, not pending).
  bool get isActive =>
      _currentState == ExecutionState.running ||
      _currentState == ExecutionState.paused ||
      _currentState == ExecutionState.waitingReview ||
      _currentState == ExecutionState.waitingApproval ||
      _currentState == ExecutionState.validating;

  /// Reset the state machine to initial state.
  void reset() {
    _currentState = ExecutionState.pending;
    _history.clear();
  }
}

/// Record of a state transition.
class StateTransition {
  /// The state before the transition.
  final ExecutionState from;

  /// The state after the transition.
  final ExecutionState to;

  /// When the transition occurred.
  final DateTime timestamp;

  /// Reason for the transition.
  final String? reason;

  /// Additional metadata about the transition.
  final Map<String, dynamic>? metadata;

  const StateTransition({
    required this.from,
    required this.to,
    required this.timestamp,
    this.reason,
    this.metadata,
  });

  @override
  String toString() => 'StateTransition($from -> $to at $timestamp)';
}
