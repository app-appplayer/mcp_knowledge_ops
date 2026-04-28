import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  group('RunbookMcpTools', () {
    test('listRunbooksSchema() returns valid schema with name and input', () {
      final schema = RunbookMcpTools.listRunbooksSchema();

      expect(schema, isA<Map<String, dynamic>>());
      expect(schema['name'], equals('runbook.list'));
      expect(schema.containsKey('input'), isTrue);
    });

    test('executeRunbookSchema() returns valid schema', () {
      final schema = RunbookMcpTools.executeRunbookSchema();

      expect(schema, isA<Map<String, dynamic>>());
      expect(schema['name'], equals('runbook.execute'));
      expect(schema.containsKey('input'), isTrue);
    });

    test('allSchemas() returns all 6 schemas', () {
      final schemas = RunbookMcpTools.allSchemas();

      expect(schemas.length, equals(6));
    });

    test('each schema has required name and input keys', () {
      final schemas = RunbookMcpTools.allSchemas();

      for (final schema in schemas) {
        expect(schema.containsKey('name'), isTrue,
            reason: 'Schema missing "name" key');
        expect(schema.containsKey('input'), isTrue,
            reason: 'Schema missing "input" key');
        expect(schema['name'], isA<String>());
      }
    });
  });
}
