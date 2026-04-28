/// HandlerRegistry Tests - Tests for handler registration and lookup.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // HandlerRegistry
  // ═══════════════════════════════════════════════════════════════

  group('HandlerRegistry', () {
    late HandlerRegistry registry;

    setUp(() {
      registry = HandlerRegistry();
    });

    test('register and retrieve handler', () {
      final handler = FunctionHandler(
        name: 'test-handler',
        handler: (input, ctx) async => 'result',
      );
      registry.register('test-handler', handler);

      final retrieved = registry.get('test-handler');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('test-handler'));
    });

    test('get returns null for unregistered handler', () {
      expect(registry.get('nonexistent'), isNull);
    });

    test('has returns true for registered handler', () {
      final handler = FunctionHandler(
        name: 'existing',
        handler: (input, ctx) async => null,
      );
      registry.register('existing', handler);
      expect(registry.has('existing'), isTrue);
    });

    test('has returns false for unregistered handler', () {
      expect(registry.has('nonexistent'), isFalse);
    });

    test('unregister removes handler', () {
      final handler = FunctionHandler(
        name: 'to-remove',
        handler: (input, ctx) async => null,
      );
      registry.register('to-remove', handler);
      expect(registry.has('to-remove'), isTrue);

      registry.unregister('to-remove');
      expect(registry.has('to-remove'), isFalse);
      expect(registry.get('to-remove'), isNull);
    });

    test('unregister for nonexistent handler does not throw', () {
      expect(() => registry.unregister('nonexistent'), returnsNormally);
    });

    test('listHandlers returns all registered handlers', () {
      registry.register(
        'handler-a',
        FunctionHandler(name: 'handler-a', handler: (i, c) async => null),
      );
      registry.register(
        'handler-b',
        FunctionHandler(name: 'handler-b', handler: (i, c) async => null),
      );
      registry.register(
        'handler-c',
        FunctionHandler(name: 'handler-c', handler: (i, c) async => null),
      );

      final handlers = registry.listHandlers();
      expect(handlers.length, equals(3));
      expect(handlers.map((h) => h.name).toList(),
          containsAll(['handler-a', 'handler-b', 'handler-c']));
    });

    test('listHandlers returns empty list when no handlers registered', () {
      expect(registry.listHandlers(), isEmpty);
    });

    test('listHandlers includes handler metadata', () {
      final handler = FunctionHandler(
        name: 'meta-handler',
        handler: (i, c) async => null,
      );
      registry.register('meta-handler', handler);

      final handlers = registry.listHandlers();
      expect(handlers.length, equals(1));
      final info = handlers.first;
      expect(info.name, equals('meta-handler'));
      expect(info.id, equals('meta-handler'));
      expect(info.version, equals('1.0.0'));
    });

    test('clear removes all handlers', () {
      registry.register(
        'h1',
        FunctionHandler(name: 'h1', handler: (i, c) async => null),
      );
      registry.register(
        'h2',
        FunctionHandler(name: 'h2', handler: (i, c) async => null),
      );

      registry.clear();
      expect(registry.listHandlers(), isEmpty);
      expect(registry.has('h1'), isFalse);
      expect(registry.has('h2'), isFalse);
    });

    test('registerAll adds multiple handlers', () {
      final handlers = {
        'bulk-1': FunctionHandler(
            name: 'bulk-1', handler: (i, c) async => null),
        'bulk-2': FunctionHandler(
            name: 'bulk-2', handler: (i, c) async => null),
        'bulk-3': FunctionHandler(
            name: 'bulk-3', handler: (i, c) async => null),
      };

      registry.registerAll(handlers);
      expect(registry.has('bulk-1'), isTrue);
      expect(registry.has('bulk-2'), isTrue);
      expect(registry.has('bulk-3'), isTrue);
      expect(registry.listHandlers().length, equals(3));
    });

    test('findByPattern with wildcard matching', () {
      registry.register(
        'pipeline.ingest',
        FunctionHandler(
            name: 'pipeline.ingest', handler: (i, c) async => null),
      );
      registry.register(
        'pipeline.transform',
        FunctionHandler(
            name: 'pipeline.transform', handler: (i, c) async => null),
      );
      registry.register(
        'workflow.build',
        FunctionHandler(
            name: 'workflow.build', handler: (i, c) async => null),
      );

      final pipelineHandlers = registry.findByPattern('pipeline.*');
      expect(pipelineHandlers.length, equals(2));
      expect(
        pipelineHandlers.map((h) => h.name).toList(),
        containsAll(['pipeline.ingest', 'pipeline.transform']),
      );
    });

    test('findByPattern returns empty for no matches', () {
      registry.register(
        'handler-a',
        FunctionHandler(name: 'handler-a', handler: (i, c) async => null),
      );

      final results = registry.findByPattern('nonexistent.*');
      expect(results, isEmpty);
    });

    test('findByPattern matches exact name', () {
      registry.register(
        'exact',
        FunctionHandler(name: 'exact', handler: (i, c) async => null),
      );

      final results = registry.findByPattern('exact');
      expect(results.length, equals(1));
      expect(results.first.name, equals('exact'));
    });

    test('validate returns empty list when all handlers present', () {
      registry.register(
        'required-1',
        FunctionHandler(
            name: 'required-1', handler: (i, c) async => null),
      );
      registry.register(
        'required-2',
        FunctionHandler(
            name: 'required-2', handler: (i, c) async => null),
      );

      final missing = registry.validate(['required-1', 'required-2']);
      expect(missing, isEmpty);
    });

    test('validate returns missing handler names', () {
      registry.register(
        'present',
        FunctionHandler(name: 'present', handler: (i, c) async => null),
      );

      final missing = registry.validate(['present', 'absent-1', 'absent-2']);
      expect(missing.length, equals(2));
      expect(missing, containsAll(['absent-1', 'absent-2']));
    });

    test('validate with empty required list returns empty', () {
      expect(registry.validate([]), isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // FunctionHandler
  // ═══════════════════════════════════════════════════════════════

  group('FunctionHandler', () {
    test('executes function and returns result', () async {
      final handler = FunctionHandler(
        name: 'adder',
        handler: (input, ctx) async {
          final n = input as int;
          return n + 1;
        },
      );

      final context = HandlerContext(
        runId: 'run-1',
        stageId: 'stage-1',
        traceId: 'trace-1',
        asOf: DateTime(2024, 1, 1),
      );

      final result = await handler.execute(5, context);
      expect(result, equals(6));
    });

    test('name property returns registered name', () {
      final handler = FunctionHandler(
        name: 'my-handler',
        handler: (input, ctx) async => null,
      );
      expect(handler.name, equals('my-handler'));
    });

    test('default id equals name', () {
      final handler = FunctionHandler(
        name: 'test-id',
        handler: (input, ctx) async => null,
      );
      expect(handler.id, equals('test-id'));
    });

    test('default version is 1.0.0', () {
      final handler = FunctionHandler(
        name: 'versioned',
        handler: (input, ctx) async => null,
      );
      expect(handler.version, equals('1.0.0'));
    });

    test('handler receives context with ports', () async {
      final testPorts = TestOpsPorts();
      OpsPorts? receivedPorts;

      final handler = FunctionHandler(
        name: 'port-checker',
        handler: (input, ctx) async {
          receivedPorts = ctx.ports;
          return null;
        },
      );

      final context = HandlerContext(
        runId: 'run-1',
        stageId: 'stage-1',
        traceId: 'trace-1',
        asOf: DateTime(2024, 1, 1),
        ports: testPorts.toOpsPorts(),
      );

      await handler.execute(null, context);
      expect(receivedPorts, isNotNull);
    });

    test('handler receives config from context', () async {
      Map<String, dynamic>? receivedConfig;

      final handler = FunctionHandler(
        name: 'config-handler',
        handler: (input, ctx) async {
          receivedConfig = ctx.config;
          return null;
        },
      );

      final context = HandlerContext(
        runId: 'run-1',
        stageId: 'stage-1',
        traceId: 'trace-1',
        asOf: DateTime(2024, 1, 1),
        config: {'key': 'value', 'count': 42},
      );

      await handler.execute(null, context);
      expect(receivedConfig, isNotNull);
      expect(receivedConfig!['key'], equals('value'));
      expect(receivedConfig!['count'], equals(42));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // HandlerContext
  // ═══════════════════════════════════════════════════════════════

  group('HandlerContext', () {
    test('creates with required parameters', () {
      final ctx = HandlerContext(
        runId: 'run-1',
        stageId: 'stage-1',
        traceId: 'trace-1',
        asOf: DateTime(2024, 1, 1),
      );

      expect(ctx.runId, equals('run-1'));
      expect(ctx.stageId, equals('stage-1'));
      expect(ctx.traceId, equals('trace-1'));
      expect(ctx.pipelineId, isNull);
      expect(ctx.config, isEmpty);
      expect(ctx.ports, isNull);
      expect(ctx.emit, isNull);
      expect(ctx.checkpoint, isNull);
      expect(ctx.executionContext, isNull);
    });

    test('getConfig retrieves typed config value', () {
      final ctx = HandlerContext(
        runId: 'run-1',
        stageId: 'stage-1',
        traceId: 'trace-1',
        asOf: DateTime(2024, 1, 1),
        config: {'timeout': 30, 'verbose': true},
      );

      expect(ctx.getConfig<int>('timeout'), equals(30));
      expect(ctx.getConfig<bool>('verbose'), isTrue);
      expect(ctx.getConfig<String>('nonexistent'), isNull);
    });
  });
}
