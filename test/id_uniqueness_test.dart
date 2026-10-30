/// Ids made in quick succession must differ: a repeated id makes a store
/// replace the earlier record without an error.
library;

import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';
import 'package:mcp_knowledge_ops/src/id_generator.dart';
import 'package:test/test.dart';

void main() {
  test('generateId gives distinct ids in a tight loop', () {
    final ids = {for (var i = 0; i < 5000; i++) generateId('x')};
    expect(ids, hasLength(5000));
  });

  test('generateId keeps the prefix and separator', () {
    expect(generateId('audit'), matches(RegExp(r'^audit_\d+_\d+$')));
    expect(generateId('wf', separator: '-'), matches(RegExp(r'^wf-\d+-\d+$')));
  });

  test('audit events created back to back have distinct ids', () {
    final ids = {
      for (var i = 0; i < 200; i++)
        AuditEvent.create(
          actor: const AuditActor(type: ActorType.user, id: 'u'),
          action: 'a',
          resource: const AuditResource(type: 'pipeline', id: 'p'),
          outcome: AuditOutcome.success,
          context: const AuditContext(workspaceId: 'ws'),
        ).id,
    };
    expect(ids, hasLength(200));
  });
}
