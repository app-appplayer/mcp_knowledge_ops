/// Tests for HandlerRegistrationService, ExpressionHandlerAdapter, and McpToolHandlerAdapter.
import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  group('HandlerRegistrationService', () {
    late HandlerRegistrationService service;

    setUp(() {
      service = HandlerRegistrationService();
    });

    test('register, get, and list handlers', () {
      final adapter = ExpressionHandlerAdapter(
        expression: 'data.count > 5',
        name: 'countCheck',
      );

      service.register('countCheck', adapter);

      expect(service.has('countCheck'), isTrue);
      expect(service.getHandler('countCheck'), isNotNull);
      expect(service.listHandlers(), contains('countCheck'));
    });

    test('unregister removes handler', () {
      final adapter = ExpressionHandlerAdapter(
        expression: 'data.value',
        name: 'valueExtract',
      );

      service.register('valueExtract', adapter);
      service.unregister('valueExtract');

      expect(service.has('valueExtract'), isFalse);
      expect(service.getHandler('valueExtract'), isNull);
    });

    test('clear removes all handlers', () {
      service.register(
        'a',
        ExpressionHandlerAdapter(expression: 'x', name: 'a'),
      );
      service.register(
        'b',
        ExpressionHandlerAdapter(expression: 'y', name: 'b'),
      );

      service.clear();

      expect(service.listHandlers(), isEmpty);
    });

    test('getHandler returns null for unregistered name', () {
      expect(service.getHandler('nonexistent'), isNull);
    });
  });

  group('ExpressionHandlerAdapter', () {
    test('evaluates dot-path expression with input', () async {
      final adapter = ExpressionHandlerAdapter(
        expression: 'data.value',
      );

      final context = HandlerContext(
        runId: 'run-1',
        stageId: 'stage-1',
        traceId: 'trace-1',
        asOf: DateTime(2024, 1, 1),
      );

      final result = await adapter.execute({
        'data': {'value': 42},
      }, context);

      expect(result['result'], equals(42));
      expect(result['expression'], equals('data.value'));
    });

    test('evaluates comparison expression', () async {
      final adapter = ExpressionHandlerAdapter(
        expression: 'count > 5',
      );

      final context = HandlerContext(
        runId: 'run-1',
        stageId: 'stage-1',
        traceId: 'trace-1',
        asOf: DateTime(2024, 1, 1),
      );

      final result = await adapter.execute({
        'count': 10,
      }, context);

      expect(result['result'], isTrue);
    });

    test('evaluates null-coalescing expression', () async {
      final adapter = ExpressionHandlerAdapter(
        expression: 'missing ?? default_value',
      );

      final context = HandlerContext(
        runId: 'run-1',
        stageId: 'stage-1',
        traceId: 'trace-1',
        asOf: DateTime(2024, 1, 1),
      );

      final result = await adapter.execute({}, context);

      expect(result['result'], equals('default_value'));
    });

    test('default name is expression_handler', () {
      final adapter = ExpressionHandlerAdapter(expression: 'x');
      expect(adapter.name, equals('expression_handler'));
    });
  });

  group('McpToolHandlerAdapter', () {
    test('requires contains mcp (REDESIGN-PLAN Phase 7)', () {
      final adapter = McpToolHandlerAdapter(
        toolName: 'fg.query',
      );

      expect(adapter.requires, contains('mcp'));
    });

    test('default name follows mcp.<tool> pattern', () {
      final adapter = McpToolHandlerAdapter(
        toolName: 'fg.query',
      );

      expect(adapter.name, equals('mcp.fg.query'));
    });

    test('custom name overrides default', () {
      final adapter = McpToolHandlerAdapter(
        toolName: 'fg.query',
        name: 'custom_name',
      );

      expect(adapter.name, equals('custom_name'));
    });

    test('toolName and defaultParams are accessible', () {
      final adapter = McpToolHandlerAdapter(
        toolName: 'kv.get',
        defaultParams: {'prefix': 'test'},
      );

      expect(adapter.toolName, equals('kv.get'));
      expect(adapter.defaultParams, equals({'prefix': 'test'}));
    });
  });

  group('LlmHandlerAdapter', () {
    test('has expected name and fields', () {
      final adapter = LlmHandlerAdapter(
        prompt: 'Summarize: {{text}}',
        model: 'gpt-4',
        config: {'temperature': 0.5},
      );

      expect(adapter.name, equals('llm.complete'));
      expect(adapter.prompt, equals('Summarize: {{text}}'));
      expect(adapter.model, equals('gpt-4'));
      expect(adapter.config, equals({'temperature': 0.5}));
    });

    test('requires contains llm', () {
      final adapter = LlmHandlerAdapter(prompt: 'test');
      expect(adapter.requires, contains('llm'));
    });
  });
}
