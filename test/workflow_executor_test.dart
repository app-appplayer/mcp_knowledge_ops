import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  group('WorkflowActionHandlerRegistry', () {
    test('register and get handler', () {
      final handlerRegistry = WorkflowActionHandlerRegistry();
      final handler = _TestActionHandler('test-handler');

      handlerRegistry.register(handler);

      expect(handlerRegistry.has('test-handler'), isTrue);
      expect(handlerRegistry.get('test-handler'), isNotNull);
      expect(handlerRegistry.get('test-handler')!.id, equals('test-handler'));
    });
  });

  group('WorkflowExecution', () {
    test('creation with status', () {
      final now = DateTime.now();
      final execution = WorkflowExecution(
        workflow: 'test-workflow',
        status: WorkflowStatus.running,
        startedAt: now,
      );

      expect(execution.workflow, equals('test-workflow'));
      expect(execution.status, equals(WorkflowStatus.running));
      expect(execution.startedAt, equals(now));
      expect(execution.completedAt, isNull);
    });

    test('duration returns difference between start and completed', () {
      final start = DateTime(2024, 1, 1, 10, 0, 0);
      final completed = DateTime(2024, 1, 1, 10, 5, 0);

      final execution = WorkflowExecution(
        workflow: 'test-workflow',
        status: WorkflowStatus.completed,
        startedAt: start,
        completedAt: completed,
      );

      expect(execution.duration, isNotNull);
      expect(execution.duration!.inMinutes, equals(5));
    });

    test('duration returns null when completedAt is null', () {
      final execution = WorkflowExecution(
        workflow: 'test-workflow',
        status: WorkflowStatus.running,
        startedAt: DateTime.now(),
      );

      expect(execution.duration, isNull);
    });
  });

  group('ActionResult', () {
    test('ok() factory creates success result', () {
      final result = ActionResult.ok(updates: {'key': 'value'});

      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.updates, equals({'key': 'value'}));
    });

    test('fail() factory creates failure result', () {
      final result = ActionResult.fail('something went wrong');

      expect(result.success, isFalse);
      expect(result.error, equals('something went wrong'));
    });
  });

  group('WorkflowStatus', () {
    test('enum contains all expected values', () {
      expect(
        WorkflowStatus.values,
        containsAll([
          WorkflowStatus.pending,
          WorkflowStatus.running,
          WorkflowStatus.completed,
          WorkflowStatus.failed,
          WorkflowStatus.paused,
          WorkflowStatus.cancelled,
        ]),
      );
      expect(WorkflowStatus.values.length, equals(6));
    });
  });
}

/// Test implementation of WorkflowActionHandler.
class _TestActionHandler extends WorkflowActionHandler {
  @override
  final String id;

  _TestActionHandler(this.id);

  @override
  Future<ActionResult> execute(ActionExecutionContext context) async {
    return ActionResult.ok();
  }
}
