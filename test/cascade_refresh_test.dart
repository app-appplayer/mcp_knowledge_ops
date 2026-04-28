/// Tests for CascadeRefreshExecutor, topological sort, and refresh models.
import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  group('CascadeRefreshExecutor', () {
    late CascadeRefreshExecutor executor;

    setUp(() {
      executor = CascadeRefreshExecutor();
    });

    group('topologicalSort', () {
      test('orders dependencies correctly for linear chain', () {
        // A -> B -> C (C depends on B, B depends on A)
        final result = executor.topologicalSort({
          'C': ['B'],
          'B': ['A'],
          'A': [],
        });

        final indexA = result.indexOf('A');
        final indexB = result.indexOf('B');
        final indexC = result.indexOf('C');

        expect(indexA, lessThan(indexB));
        expect(indexB, lessThan(indexC));
      });

      test('handles diamond dependency', () {
        // A -> B, A -> C, B -> D, C -> D
        final result = executor.topologicalSort({
          'D': ['B', 'C'],
          'B': ['A'],
          'C': ['A'],
          'A': [],
        });

        final indexA = result.indexOf('A');
        final indexB = result.indexOf('B');
        final indexC = result.indexOf('C');
        final indexD = result.indexOf('D');

        expect(indexA, lessThan(indexB));
        expect(indexA, lessThan(indexC));
        expect(indexB, lessThan(indexD));
        expect(indexC, lessThan(indexD));
      });

      test('handles nodes with no dependencies', () {
        final result = executor.topologicalSort({
          'A': [],
          'B': [],
          'C': [],
        });

        expect(result, hasLength(3));
        expect(result, containsAll(['A', 'B', 'C']));
      });

      test('throws StateError on cycle', () {
        expect(
          () => executor.topologicalSort({
            'A': ['B'],
            'B': ['A'],
          }),
          throwsStateError,
        );
      });
    });

    group('execute', () {
      test('processes nodes in dependency order', () async {
        final request = CascadeRefreshRequest(
          dependencies: {
            'B': ['A'],
            'A': [],
          },
        );

        final result = await executor.execute(request);

        expect(result.results, hasLength(2));
        expect(result.results['A']!.success, isTrue);
        expect(result.results['B']!.success, isTrue);
      });

      test('processes all nodes in complex graph', () async {
        final request = CascadeRefreshRequest(
          dependencies: {
            'D': ['B', 'C'],
            'B': ['A'],
            'C': ['A'],
            'A': [],
          },
        );

        final result = await executor.execute(request);

        expect(result.results, hasLength(4));
        expect(result.refreshedCount, equals(4));
        expect(result.failedCount, equals(0));
      });
    });
  });

  group('CascadeRefreshRequest', () {
    test('const constructor with required dependencies', () {
      const request = CascadeRefreshRequest(
        dependencies: {
          'A': [],
          'B': ['A'],
        },
      );

      expect(request.dependencies, hasLength(2));
      expect(request.options, isNull);
    });

    test('with options', () {
      const request = CascadeRefreshRequest(
        dependencies: {'A': []},
        options: {'parallel': true, 'stopOnError': false},
      );

      expect(request.options, isNotNull);
      expect(request.options!['parallel'], isTrue);
    });
  });

  group('CascadeRefreshResult', () {
    test('refreshedCount counts successful results', () {
      const result = CascadeRefreshResult(
        results: {
          'A': RefreshResult(nodeId: 'A', success: true),
          'B': RefreshResult(nodeId: 'B', success: true),
          'C': RefreshResult(nodeId: 'C', success: false, error: 'failed'),
        },
      );

      expect(result.refreshedCount, equals(2));
      expect(result.failedCount, equals(1));
    });

    test('empty results have zero counts', () {
      const result = CascadeRefreshResult(results: {});

      expect(result.refreshedCount, equals(0));
      expect(result.failedCount, equals(0));
    });
  });

  group('RefreshResult', () {
    test('successful result', () {
      const result = RefreshResult(nodeId: 'node-1', success: true);

      expect(result.nodeId, equals('node-1'));
      expect(result.success, isTrue);
      expect(result.error, isNull);
    });

    test('failed result with error', () {
      const result = RefreshResult(
        nodeId: 'node-2',
        success: false,
        error: 'timeout',
      );

      expect(result.success, isFalse);
      expect(result.error, equals('timeout'));
    });
  });
}
