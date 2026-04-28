import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

void main() {
  group('ParallelStageExecutor', () {
    late HandlerRegistry registry;
    late StageExecutor stageExecutor;
    late ParallelStageExecutor parallelExecutor;
    late ExecutionContext context;

    setUp(() {
      registry = HandlerRegistry();
      registry.register(
        'process',
        FunctionHandler(
          name: 'process',
          handler: (input, ctx) async => 'result_${ctx.stageId}',
        ),
      );

      stageExecutor = StageExecutor(handlers: registry);
      parallelExecutor = ParallelStageExecutor(
        stageExecutor: stageExecutor,
        maxConcurrency: 4,
      );
      context = testExecutionContext();
    });

    test('execute multiple stages in parallel', () async {
      final stages = [
        Stage(id: 's1', name: 'Stage 1', handler: 'process'),
        Stage(id: 's2', name: 'Stage 2', handler: 'process'),
        Stage(id: 's3', name: 'Stage 3', handler: 'process'),
      ];

      final results = await parallelExecutor.executeParallel(stages, context);

      expect(results, isNotEmpty);
      for (final result in results) {
        expect(result.status, equals(StageStatus.completed));
      }
    });

    test('results match input stages count', () async {
      final stages = [
        Stage(id: 'a1', name: 'A1', handler: 'process'),
        Stage(id: 'a2', name: 'A2', handler: 'process'),
        Stage(id: 'a3', name: 'A3', handler: 'process'),
        Stage(id: 'a4', name: 'A4', handler: 'process'),
      ];

      final results = await parallelExecutor.executeParallel(stages, context);

      expect(results.length, equals(stages.length));
    });

    test('maxConcurrency limits concurrent execution', () async {
      var maxConcurrent = 0;
      var currentConcurrent = 0;

      registry.register(
        'tracked',
        FunctionHandler(
          name: 'tracked',
          handler: (input, ctx) async {
            currentConcurrent++;
            if (currentConcurrent > maxConcurrent) {
              maxConcurrent = currentConcurrent;
            }
            // Small delay to allow overlap detection
            await Future<void>.delayed(const Duration(milliseconds: 10));
            currentConcurrent--;
            return 'done';
          },
        ),
      );

      final limitedExecutor = ParallelStageExecutor(
        stageExecutor: StageExecutor(handlers: registry),
        maxConcurrency: 2,
      );

      final stages = [
        Stage(id: 'c1', name: 'C1', handler: 'tracked'),
        Stage(id: 'c2', name: 'C2', handler: 'tracked'),
        Stage(id: 'c3', name: 'C3', handler: 'tracked'),
        Stage(id: 'c4', name: 'C4', handler: 'tracked'),
      ];

      final results =
          await limitedExecutor.executeParallel(stages, context);

      expect(results.length, equals(4));
      expect(maxConcurrent, lessThanOrEqualTo(2));
    });
  });
}
