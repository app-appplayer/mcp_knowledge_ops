/// Tests for PipelineHandler, PipelineHandlerRegistry, FunctionHandler, and ValidationResult.
import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';
import 'package:mcp_knowledge_ops/src/pipeline/pipeline_handler.dart' as ph;

void main() {
  group('FunctionHandler', () {
    test('executes function correctly', () async {
      final handler = ph.FunctionHandler<Map<String, dynamic>, String>(
        id: 'test.handler',
        name: 'Test Handler',
        fn: (input, context) async => 'result: ${input['value']}',
      );

      final context = HandlerContext(
        runId: 'run-1',
        stageId: 'stage-1',
        traceId: 'trace-1',
        asOf: DateTime(2024, 1, 1),
      );

      final result = await handler.execute({'value': 42}, context);
      expect(result, equals('result: 42'));
    });

    test('has correct id, name, version', () {
      final handler = ph.FunctionHandler<String, String>(
        id: 'my.handler',
        name: 'My Handler',
        version: '2.0.0',
        requires: ['factGraph'],
        fn: (input, context) async => input,
      );

      expect(handler.id, equals('my.handler'));
      expect(handler.name, equals('My Handler'));
      expect(handler.version, equals('2.0.0'));
      expect(handler.requires, contains('factGraph'));
    });

    test('validateInput returns null by default', () {
      final handler = ph.FunctionHandler<String, String>(
        id: 'test',
        name: 'Test',
        fn: (input, context) async => input,
      );

      expect(handler.validateInput('anything'), isNull);
    });
  });

  group('PipelineHandlerRegistry', () {
    late PipelineHandlerRegistry registry;
    late ph.FunctionHandler<String, String> handler;

    setUp(() {
      registry = PipelineHandlerRegistry();
      handler = ph.FunctionHandler<String, String>(
        id: 'test.echo',
        name: 'Echo Handler',
        fn: (input, context) async => input,
      );
    });

    test('register and get handler', () {
      registry.register(handler);

      final retrieved = registry.get('test.echo');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('test.echo'));
    });

    test('has() returns true for registered handler', () {
      registry.register(handler);

      expect(registry.has('test.echo'), isTrue);
      expect(registry.has('nonexistent'), isFalse);
    });

    test('has() returns false after unregister', () {
      registry.register(handler);
      registry.unregister('test.echo');

      expect(registry.has('test.echo'), isFalse);
    });

    test('findByPattern() matches handler IDs', () {
      registry.register(handler);
      registry.register(ph.FunctionHandler<String, String>(
        id: 'test.transform',
        name: 'Transform',
        fn: (input, context) async => input,
      ));
      registry.register(ph.FunctionHandler<String, String>(
        id: 'other.handler',
        name: 'Other',
        fn: (input, context) async => input,
      ));

      final matches = registry.findByPattern('test.*');
      expect(matches, hasLength(2));
    });

    test('list() returns all handlers', () {
      registry.register(handler);
      registry.register(ph.FunctionHandler<String, String>(
        id: 'another.handler',
        name: 'Another',
        fn: (input, context) async => input,
      ));

      final list = registry.list();
      expect(list, hasLength(2));
    });

    test('list() with namespace filter', () {
      registry.register(handler);
      registry.register(ph.FunctionHandler<String, String>(
        id: 'other.handler',
        name: 'Other',
        fn: (input, context) async => input,
      ));

      final filtered = registry.list(
        filter: const ph.HandlerFilter(namespace: 'test'),
      );
      expect(filtered, hasLength(1));
      expect(filtered.first.id, equals('test.echo'));
    });

    test('validate() returns valid for existing handler', () {
      registry.register(handler);

      final result = registry.validate('test.echo');
      expect(result.valid, isTrue);
    });

    test('validate() returns invalid for missing handler', () {
      final result = registry.validate('nonexistent');
      expect(result.valid, isFalse);
      expect(result.errors, isNotEmpty);
    });

    test('clear() removes all handlers', () {
      registry.register(handler);
      registry.clear();

      expect(registry.has('test.echo'), isFalse);
      expect(registry.list(), isEmpty);
    });
  });

  group('ValidationResult', () {
    test('valid() factory creates valid result', () {
      final result = ValidationResult.valid();
      expect(result.valid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('invalid() factory creates invalid result with errors', () {
      final result = ValidationResult.invalid(['Error 1', 'Error 2']);
      expect(result.valid, isFalse);
      expect(result.errors, hasLength(2));
      expect(result.errors, contains('Error 1'));
    });

    test('constructor with warnings', () {
      const result = ValidationResult(
        valid: true,
        warnings: ['Deprecation warning'],
      );
      expect(result.valid, isTrue);
      expect(result.warnings, hasLength(1));
    });
  });
}
