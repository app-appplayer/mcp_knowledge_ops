/// Tests for cancellation models: CancellationReason, CompensationAction,
/// CancellationRequest, CompensationConfig.
import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  group('CancellationReason', () {
    test('UserRequested creation', () {
      const reason = UserRequested(
        userId: 'user-1',
        comment: 'No longer needed',
      );

      expect(reason.userId, equals('user-1'));
      expect(reason.comment, equals('No longer needed'));
      expect(reason, isA<CancellationReason>());
    });

    test('UserRequested without comment', () {
      const reason = UserRequested(userId: 'user-1');

      expect(reason.userId, equals('user-1'));
      expect(reason.comment, isNull);
    });

    test('TimeoutExceeded creation', () {
      const reason = TimeoutExceeded(
        elapsed: Duration(minutes: 35),
        limit: Duration(minutes: 30),
      );

      expect(reason.elapsed, equals(const Duration(minutes: 35)));
      expect(reason.limit, equals(const Duration(minutes: 30)));
      expect(reason, isA<CancellationReason>());
    });

    test('DependencyFailed creation', () {
      const reason = DependencyFailed(
        dependencyId: 'dep-1',
        error: 'Connection refused',
      );

      expect(reason.dependencyId, equals('dep-1'));
      expect(reason.error, equals('Connection refused'));
      expect(reason, isA<CancellationReason>());
    });

    test('SystemShutdown creation', () {
      const reason = SystemShutdown(message: 'Planned maintenance');

      expect(reason.message, equals('Planned maintenance'));
      expect(reason, isA<CancellationReason>());
    });

    test('SystemShutdown without message', () {
      const reason = SystemShutdown();

      expect(reason.message, isNull);
    });
  });

  group('CompensationAction', () {
    test('InvokeHandler creation', () {
      const action = InvokeHandler(
        handlerName: 'cleanup.handler',
        params: {'key': 'value'},
      );

      expect(action.handlerName, equals('cleanup.handler'));
      expect(action.params, equals({'key': 'value'}));
      expect(action, isA<CompensationAction>());
    });

    test('InvokeHandler without params', () {
      const action = InvokeHandler(handlerName: 'rollback');

      expect(action.handlerName, equals('rollback'));
      expect(action.params, isNull);
    });

    test('RunScript creation', () {
      const action = RunScript(script: 'echo cleanup');

      expect(action.script, equals('echo cleanup'));
      expect(action, isA<CompensationAction>());
    });

    test('NoOp creation', () {
      const action = NoOp();

      expect(action, isA<CompensationAction>());
    });

    test('sealed class hierarchy', () {
      const actions = <CompensationAction>[
        InvokeHandler(handlerName: 'test'),
        RunScript(script: 'test'),
        NoOp(),
      ];

      expect(actions, hasLength(3));
      expect(actions[0], isA<InvokeHandler>());
      expect(actions[1], isA<RunScript>());
      expect(actions[2], isA<NoOp>());
    });
  });

  group('CancellationRequest', () {
    test('creation with required fields', () {
      final request = CancellationRequest(
        workflowId: 'wf-1',
        executionId: 'exec-1',
        reason: const UserRequested(userId: 'user-1'),
        requestedAt: DateTime(2024, 1, 1),
      );

      expect(request.workflowId, equals('wf-1'));
      expect(request.executionId, equals('exec-1'));
      expect(request.reason, isA<UserRequested>());
      expect(request.requestedBy, isNull);
    });

    test('creation with all fields', () {
      final request = CancellationRequest(
        workflowId: 'wf-1',
        executionId: 'exec-1',
        reason: const TimeoutExceeded(
          elapsed: Duration(hours: 2),
          limit: Duration(hours: 1),
        ),
        requestedBy: 'system',
        requestedAt: DateTime(2024, 6, 15),
      );

      expect(request.requestedBy, equals('system'));
      expect(request.reason, isA<TimeoutExceeded>());
    });
  });

  group('CompensationConfig', () {
    test('defaults are correct', () {
      const config = CompensationConfig();

      expect(config.mode, equals(CompensationMode.backward));
      expect(
        config.failurePolicy,
        equals(CompensationFailurePolicy.continueCompensation),
      );
      expect(config.timeout, isNull);
      expect(config.maxRetries, equals(3));
    });

    test('custom values', () {
      const config = CompensationConfig(
        mode: CompensationMode.selective,
        failurePolicy: CompensationFailurePolicy.stopCompensation,
        timeout: Duration(minutes: 10),
        maxRetries: 5,
      );

      expect(config.mode, equals(CompensationMode.selective));
      expect(
        config.failurePolicy,
        equals(CompensationFailurePolicy.stopCompensation),
      );
      expect(config.timeout, equals(const Duration(minutes: 10)));
      expect(config.maxRetries, equals(5));
    });
  });

  group('CompensationMode', () {
    test('has expected values', () {
      expect(CompensationMode.values, hasLength(3));
      expect(
        CompensationMode.values,
        containsAll([
          CompensationMode.backward,
          CompensationMode.forward,
          CompensationMode.selective,
        ]),
      );
    });
  });

  group('CompensationFailurePolicy', () {
    test('has expected values', () {
      expect(CompensationFailurePolicy.values, hasLength(3));
      expect(
        CompensationFailurePolicy.values,
        containsAll([
          CompensationFailurePolicy.continueCompensation,
          CompensationFailurePolicy.stopCompensation,
          CompensationFailurePolicy.failWorkflow,
        ]),
      );
    });
  });
}
