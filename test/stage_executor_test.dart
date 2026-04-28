import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

void main() {
  group('StageExecutor', () {
    late HandlerRegistry registry;
    late StageExecutor executor;
    late ExecutionContext context;

    setUp(() {
      registry = HandlerRegistry();
      executor = StageExecutor(handlers: registry);
      context = testExecutionContext();
    });

    test('execute with registered handler returns completed StageResult',
        () async {
      registry.register(
        'echo',
        FunctionHandler(
          name: 'echo',
          handler: (input, ctx) async => 'processed: $input',
        ),
      );

      final stage = Stage(
        id: 'stage-1',
        name: 'Echo Stage',
        handler: 'echo',
      );

      final result = await executor.execute(stage, 'hello', context);

      expect(result.status, equals(StageStatus.completed));
      expect(result.stageId, equals('stage-1'));
      expect(result.output, equals('processed: hello'));
    });

    test('execute with unregistered handler returns failed StageResult',
        () async {
      final stage = Stage(
        id: 'stage-2',
        name: 'Missing Stage',
        handler: 'nonexistent',
      );

      final result = await executor.execute(stage, null, context);

      expect(result.status, equals(StageStatus.failed));
      expect(result.stageId, equals('stage-2'));
      expect(result.error, isNotNull);
    });

    test('execute with handler that throws returns failed StageResult',
        () async {
      registry.register(
        'failing',
        FunctionHandler(
          name: 'failing',
          handler: (input, ctx) async => throw Exception('handler error'),
        ),
      );

      final stage = Stage(
        id: 'stage-3',
        name: 'Failing Stage',
        handler: 'failing',
      );

      final result = await executor.execute(stage, null, context);

      expect(result.status, equals(StageStatus.failed));
      expect(result.stageId, equals('stage-3'));
      expect(result.error, isNotNull);
    });

    test('stage with OnFailure.skip on error returns skipped StageResult',
        () async {
      registry.register(
        'erroring',
        FunctionHandler(
          name: 'erroring',
          handler: (input, ctx) async => throw Exception('skip me'),
        ),
      );

      final stage = Stage(
        id: 'stage-4',
        name: 'Skip on Fail Stage',
        handler: 'erroring',
        onFailure: OnFailure.skip,
      );

      final result = await executor.execute(stage, null, context);

      expect(result.status, equals(StageStatus.skipped));
      expect(result.stageId, equals('stage-4'));
    });
  });
}
