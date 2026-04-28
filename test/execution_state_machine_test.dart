/// ExecutionStateMachine Tests - Tests for execution state machine transitions.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // ExecutionStateMachine
  // ═══════════════════════════════════════════════════════════════

  group('ExecutionStateMachine', () {
    late ExecutionStateMachine sm;

    setUp(() {
      sm = ExecutionStateMachine();
    });

    test('initial state is pending', () {
      expect(sm.currentState, equals(ExecutionState.pending));
    });

    test('initial state can be overridden', () {
      final custom = ExecutionStateMachine(ExecutionState.running);
      expect(custom.currentState, equals(ExecutionState.running));
    });

    test('history is empty initially', () {
      expect(sm.history, isEmpty);
    });

    // ─────────────────────────────────────────────────────────────
    // Valid transitions from pending
    // ─────────────────────────────────────────────────────────────

    test('valid transition: pending -> validating', () {
      sm.transitionTo(ExecutionState.validating);
      expect(sm.currentState, equals(ExecutionState.validating));
    });

    test('valid transition: pending -> cancelled', () {
      sm.transitionTo(ExecutionState.cancelled);
      expect(sm.currentState, equals(ExecutionState.cancelled));
    });

    // ─────────────────────────────────────────────────────────────
    // Valid transitions from validating
    // ─────────────────────────────────────────────────────────────

    test('valid transition: validating -> running', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      expect(sm.currentState, equals(ExecutionState.running));
    });

    test('valid transition: validating -> failed', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.failed);
      expect(sm.currentState, equals(ExecutionState.failed));
    });

    test('valid transition: validating -> cancelled', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.cancelled);
      expect(sm.currentState, equals(ExecutionState.cancelled));
    });

    // ─────────────────────────────────────────────────────────────
    // Valid transitions from running
    // ─────────────────────────────────────────────────────────────

    test('valid transition: running -> paused', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.paused);
      expect(sm.currentState, equals(ExecutionState.paused));
    });

    test('valid transition: running -> completed', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.completed);
      expect(sm.currentState, equals(ExecutionState.completed));
    });

    test('valid transition: running -> failed', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.failed);
      expect(sm.currentState, equals(ExecutionState.failed));
    });

    test('valid transition: running -> cancelled', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.cancelled);
      expect(sm.currentState, equals(ExecutionState.cancelled));
    });

    test('valid transition: running -> waitingReview', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.waitingReview);
      expect(sm.currentState, equals(ExecutionState.waitingReview));
    });

    test('valid transition: running -> waitingApproval', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.waitingApproval);
      expect(sm.currentState, equals(ExecutionState.waitingApproval));
    });

    // ─────────────────────────────────────────────────────────────
    // Valid transitions from paused
    // ─────────────────────────────────────────────────────────────

    test('valid transition: paused -> running', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.paused);
      sm.transitionTo(ExecutionState.running);
      expect(sm.currentState, equals(ExecutionState.running));
    });

    test('valid transition: paused -> cancelled', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.paused);
      sm.transitionTo(ExecutionState.cancelled);
      expect(sm.currentState, equals(ExecutionState.cancelled));
    });

    // ─────────────────────────────────────────────────────────────
    // Valid transitions from waitingReview
    // ─────────────────────────────────────────────────────────────

    test('valid transition: waitingReview -> running', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.waitingReview);
      sm.transitionTo(ExecutionState.running);
      expect(sm.currentState, equals(ExecutionState.running));
    });

    test('valid transition: waitingReview -> cancelled', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.waitingReview);
      sm.transitionTo(ExecutionState.cancelled);
      expect(sm.currentState, equals(ExecutionState.cancelled));
    });

    // ─────────────────────────────────────────────────────────────
    // Valid transitions from waitingApproval
    // ─────────────────────────────────────────────────────────────

    test('valid transition: waitingApproval -> running', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.waitingApproval);
      sm.transitionTo(ExecutionState.running);
      expect(sm.currentState, equals(ExecutionState.running));
    });

    test('valid transition: waitingApproval -> cancelled', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.waitingApproval);
      sm.transitionTo(ExecutionState.cancelled);
      expect(sm.currentState, equals(ExecutionState.cancelled));
    });

    // ─────────────────────────────────────────────────────────────
    // Valid transitions from failed
    // ─────────────────────────────────────────────────────────────

    test('valid transition: failed -> rolledBack', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.failed);
      sm.transitionTo(ExecutionState.rolledBack);
      expect(sm.currentState, equals(ExecutionState.rolledBack));
    });

    // ─────────────────────────────────────────────────────────────
    // Invalid transitions
    // ─────────────────────────────────────────────────────────────

    test('invalid transition: pending -> completed throws StateError', () {
      expect(
        () => sm.transitionTo(ExecutionState.completed),
        throwsStateError,
      );
    });

    test('invalid transition: pending -> running throws StateError', () {
      expect(
        () => sm.transitionTo(ExecutionState.running),
        throwsStateError,
      );
    });

    test('invalid transition: completed -> running throws StateError', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.completed);
      expect(
        () => sm.transitionTo(ExecutionState.running),
        throwsStateError,
      );
    });

    test('invalid transition: cancelled -> running throws StateError', () {
      sm.transitionTo(ExecutionState.cancelled);
      expect(
        () => sm.transitionTo(ExecutionState.running),
        throwsStateError,
      );
    });

    test('invalid transition: rolledBack -> running throws StateError', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.failed);
      sm.transitionTo(ExecutionState.rolledBack);
      expect(
        () => sm.transitionTo(ExecutionState.running),
        throwsStateError,
      );
    });

    // ─────────────────────────────────────────────────────────────
    // canTransitionTo
    // ─────────────────────────────────────────────────────────────

    test('canTransitionTo returns true for valid transition', () {
      expect(sm.canTransitionTo(ExecutionState.validating), isTrue);
      expect(sm.canTransitionTo(ExecutionState.cancelled), isTrue);
    });

    test('canTransitionTo returns false for invalid transition', () {
      expect(sm.canTransitionTo(ExecutionState.running), isFalse);
      expect(sm.canTransitionTo(ExecutionState.completed), isFalse);
    });

    // ─────────────────────────────────────────────────────────────
    // validTransitions
    // ─────────────────────────────────────────────────────────────

    test('validTransitions returns allowed targets from pending', () {
      final targets = sm.validTransitions;
      expect(targets, contains(ExecutionState.validating));
      expect(targets, contains(ExecutionState.cancelled));
      expect(targets.length, equals(2));
    });

    test('validTransitions returns empty list for terminal states', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.completed);
      expect(sm.validTransitions, isEmpty);
    });

    // ─────────────────────────────────────────────────────────────
    // history
    // ─────────────────────────────────────────────────────────────

    test('history records transitions', () {
      sm.transitionTo(ExecutionState.validating, reason: 'Starting validation');
      sm.transitionTo(
        ExecutionState.running,
        metadata: {'stage': 'init'},
      );

      expect(sm.history.length, equals(2));

      final first = sm.history[0];
      expect(first.from, equals(ExecutionState.pending));
      expect(first.to, equals(ExecutionState.validating));
      expect(first.reason, equals('Starting validation'));
      expect(first.metadata, isNull);

      final second = sm.history[1];
      expect(second.from, equals(ExecutionState.validating));
      expect(second.to, equals(ExecutionState.running));
      expect(second.reason, isNull);
      expect(second.metadata, equals({'stage': 'init'}));
    });

    test('history records timestamp for each transition', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);

      for (final transition in sm.history) {
        expect(transition.timestamp, isA<DateTime>());
      }
    });

    test('history is unmodifiable', () {
      sm.transitionTo(ExecutionState.validating);
      final history = sm.history;
      expect(
        () => history.add(StateTransition(
          from: ExecutionState.pending,
          to: ExecutionState.running,
          timestamp: DateTime.now(),
        )),
        throwsUnsupportedError,
      );
    });

    // ─────────────────────────────────────────────────────────────
    // isTerminal
    // ─────────────────────────────────────────────────────────────

    test('isTerminal is false for pending', () {
      expect(sm.isTerminal, isFalse);
    });

    test('isTerminal is true for completed', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.completed);
      expect(sm.isTerminal, isTrue);
    });

    test('isTerminal is true for failed', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.failed);
      expect(sm.isTerminal, isTrue);
    });

    test('isTerminal is true for cancelled', () {
      sm.transitionTo(ExecutionState.cancelled);
      expect(sm.isTerminal, isTrue);
    });

    test('isTerminal is true for rolledBack', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.failed);
      sm.transitionTo(ExecutionState.rolledBack);
      expect(sm.isTerminal, isTrue);
    });

    // ─────────────────────────────────────────────────────────────
    // isActive
    // ─────────────────────────────────────────────────────────────

    test('isActive is false for pending', () {
      expect(sm.isActive, isFalse);
    });

    test('isActive is true for running', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      expect(sm.isActive, isTrue);
    });

    test('isActive is true for validating', () {
      sm.transitionTo(ExecutionState.validating);
      expect(sm.isActive, isTrue);
    });

    test('isActive is true for paused', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.paused);
      expect(sm.isActive, isTrue);
    });

    test('isActive is true for waitingReview', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.waitingReview);
      expect(sm.isActive, isTrue);
    });

    test('isActive is true for waitingApproval', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.waitingApproval);
      expect(sm.isActive, isTrue);
    });

    test('isActive is false for terminal states', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.completed);
      expect(sm.isActive, isFalse);
    });

    // ─────────────────────────────────────────────────────────────
    // reset
    // ─────────────────────────────────────────────────────────────

    test('reset returns to pending', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.reset();
      expect(sm.currentState, equals(ExecutionState.pending));
    });

    test('reset clears history', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      expect(sm.history, isNotEmpty);
      sm.reset();
      expect(sm.history, isEmpty);
    });

    test('transitions work after reset', () {
      sm.transitionTo(ExecutionState.validating);
      sm.transitionTo(ExecutionState.running);
      sm.transitionTo(ExecutionState.completed);
      expect(sm.isTerminal, isTrue);

      sm.reset();
      sm.transitionTo(ExecutionState.validating);
      expect(sm.currentState, equals(ExecutionState.validating));
    });

    // ─────────────────────────────────────────────────────────────
    // StateTransition toString
    // ─────────────────────────────────────────────────────────────

    test('StateTransition toString includes from and to', () {
      sm.transitionTo(ExecutionState.validating);
      final transition = sm.history.first;
      final str = transition.toString();
      expect(str, contains('pending'));
      expect(str, contains('validating'));
    });
  });
}
