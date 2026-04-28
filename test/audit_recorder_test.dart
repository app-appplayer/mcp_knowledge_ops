/// Audit Recorder Tests - Tests for InMemoryAuditRecorder, AuditEvent,
/// AuditFilter, and related audit classes.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // InMemoryAuditRecorder
  // ═══════════════════════════════════════════════════════════════

  group('InMemoryAuditRecorder', () {
    late InMemoryAuditRecorder recorder;

    setUp(() {
      recorder = InMemoryAuditRecorder();
    });

    AuditEvent createTestEvent({
      String action = 'pipeline.start',
      AuditOutcome outcome = AuditOutcome.success,
      String actorId = 'user-1',
      String resourceType = 'pipeline',
      String resourceId = 'pipe-1',
      String workspaceId = 'ws-1',
    }) {
      return AuditEvent.create(
        actor: AuditActor(type: ActorType.user, id: actorId, name: 'Test User'),
        action: action,
        resource: AuditResource(type: resourceType, id: resourceId),
        outcome: outcome,
        context: AuditContext(workspaceId: workspaceId),
      );
    }

    test('record() stores event', () async {
      final event = createTestEvent();
      await recorder.record(event);

      expect(recorder.events.length, equals(1));
      expect(recorder.length, equals(1));
    });

    test('record() stores multiple events', () async {
      await recorder.record(createTestEvent(action: 'pipeline.start'));
      await recorder.record(createTestEvent(action: 'pipeline.complete'));
      await recorder.record(createTestEvent(action: 'pipeline.fail'));

      expect(recorder.length, equals(3));
    });

    test('query() with empty filter returns all events', () async {
      await recorder.record(createTestEvent(action: 'a'));
      await recorder.record(createTestEvent(action: 'b'));
      await recorder.record(createTestEvent(action: 'c'));

      final results = await recorder.query(const AuditFilter());
      expect(results.length, equals(3));
    });

    test('query() filters by actions', () async {
      await recorder.record(createTestEvent(action: 'pipeline.start'));
      await recorder.record(createTestEvent(action: 'pipeline.complete'));
      await recorder.record(createTestEvent(action: 'workflow.start'));

      final results = await recorder.query(
        const AuditFilter(actions: ['pipeline.start']),
      );
      expect(results.length, equals(1));
      expect(results.first.action, equals('pipeline.start'));
    });

    test('query() filters by actors', () async {
      await recorder.record(createTestEvent(actorId: 'user-1'));
      await recorder.record(createTestEvent(actorId: 'user-2'));
      await recorder.record(createTestEvent(actorId: 'user-1'));

      final results = await recorder.query(
        const AuditFilter(actors: ['user-2']),
      );
      expect(results.length, equals(1));
    });

    test('query() filters by resource types', () async {
      await recorder.record(
          createTestEvent(resourceType: 'pipeline'));
      await recorder.record(
          createTestEvent(resourceType: 'workflow'));

      final results = await recorder.query(
        const AuditFilter(resourceTypes: ['workflow']),
      );
      expect(results.length, equals(1));
    });

    test('query() filters by outcomes', () async {
      await recorder.record(
          createTestEvent(outcome: AuditOutcome.success));
      await recorder.record(
          createTestEvent(outcome: AuditOutcome.failure));
      await recorder.record(
          createTestEvent(outcome: AuditOutcome.denied));

      final results = await recorder.query(
        const AuditFilter(outcomes: [AuditOutcome.failure]),
      );
      expect(results.length, equals(1));
      expect(results.first.outcome, equals(AuditOutcome.failure));
    });

    test('query() filters by workspace ID', () async {
      await recorder.record(createTestEvent(workspaceId: 'ws-1'));
      await recorder.record(createTestEvent(workspaceId: 'ws-2'));

      final results = await recorder.query(
        const AuditFilter(workspaceId: 'ws-1'),
      );
      expect(results.length, equals(1));
    });

    test('query() filters by time range', () async {
      final event1 = AuditEvent(
        id: 'evt-1',
        timestamp: DateTime(2024, 1, 1),
        actor: const AuditActor(type: ActorType.user, id: 'u-1'),
        action: 'action-1',
        resource: const AuditResource(type: 'pipeline', id: 'p-1'),
        outcome: AuditOutcome.success,
        context: const AuditContext(workspaceId: 'ws-1'),
      );
      final event2 = AuditEvent(
        id: 'evt-2',
        timestamp: DateTime(2024, 6, 15),
        actor: const AuditActor(type: ActorType.user, id: 'u-1'),
        action: 'action-2',
        resource: const AuditResource(type: 'pipeline', id: 'p-2'),
        outcome: AuditOutcome.success,
        context: const AuditContext(workspaceId: 'ws-1'),
      );
      final event3 = AuditEvent(
        id: 'evt-3',
        timestamp: DateTime(2024, 12, 31),
        actor: const AuditActor(type: ActorType.user, id: 'u-1'),
        action: 'action-3',
        resource: const AuditResource(type: 'pipeline', id: 'p-3'),
        outcome: AuditOutcome.success,
        context: const AuditContext(workspaceId: 'ws-1'),
      );

      await recorder.record(event1);
      await recorder.record(event2);
      await recorder.record(event3);

      final results = await recorder.query(AuditFilter(
        startTime: DateTime(2024, 3, 1),
        endTime: DateTime(2024, 9, 1),
      ));

      expect(results.length, equals(1));
      expect(results.first.id, equals('evt-2'));
    });

    test('export() as JSON produces valid JSON bytes', () async {
      await recorder.record(createTestEvent());

      final bytes =
          await recorder.export(const AuditFilter(), ExportFormat.json);

      final jsonStr = utf8.decode(bytes);
      final parsed = jsonDecode(jsonStr);
      expect(parsed, isA<List>());
      expect((parsed as List).length, equals(1));
    });

    test('export() as CSV produces valid CSV', () async {
      await recorder.record(createTestEvent());

      final bytes =
          await recorder.export(const AuditFilter(), ExportFormat.csv);

      final csvStr = utf8.decode(bytes);
      final lines = csvStr.trim().split('\n');
      // Header + 1 data row
      expect(lines.length, equals(2));
      expect(lines.first, contains('id'));
      expect(lines.first, contains('timestamp'));
      expect(lines.first, contains('action'));
    });

    test('clear() removes all events', () async {
      await recorder.record(createTestEvent());
      await recorder.record(createTestEvent());
      expect(recorder.length, equals(2));

      recorder.clear();
      expect(recorder.length, equals(0));
      expect(recorder.events, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // AuditEvent
  // ═══════════════════════════════════════════════════════════════

  group('AuditEvent', () {
    test('create() generates id and timestamp', () {
      final event = AuditEvent.create(
        actor: const AuditActor(type: ActorType.user, id: 'u-1'),
        action: 'pipeline.start',
        resource: const AuditResource(type: 'pipeline', id: 'p-1'),
        outcome: AuditOutcome.success,
        context: const AuditContext(workspaceId: 'ws-1'),
      );

      expect(event.id, isNotEmpty);
      expect(event.id, startsWith('audit_'));
      expect(event.timestamp, isNotNull);
    });

    test('create() with optional details', () {
      final event = AuditEvent.create(
        actor: const AuditActor(type: ActorType.system, id: 'system'),
        action: 'config.update',
        resource: const AuditResource(type: 'config', id: 'cfg-1'),
        outcome: AuditOutcome.success,
        context: const AuditContext(workspaceId: 'ws-1'),
        details: {'oldValue': 'a', 'newValue': 'b'},
        reason: 'Config migration',
      );

      expect(event.details, isNotNull);
      expect(event.details!['oldValue'], equals('a'));
      expect(event.reason, equals('Config migration'));
    });

    test('toJson() serializes correctly', () {
      final event = AuditEvent(
        id: 'evt-1',
        timestamp: DateTime(2024),
        actor: const AuditActor(type: ActorType.user, id: 'u-1', name: 'Admin'),
        action: 'pipeline.start',
        resource: const AuditResource(type: 'pipeline', id: 'p-1', name: 'Ingest'),
        outcome: AuditOutcome.success,
        context: const AuditContext(workspaceId: 'ws-1', traceId: 'trace-1'),
      );

      final json = event.toJson();
      expect(json['id'], equals('evt-1'));
      expect(json['action'], equals('pipeline.start'));
      expect(json['outcome'], equals('success'));
      expect(json['actor']['type'], equals('user'));
      expect(json['actor']['id'], equals('u-1'));
      expect(json['resource']['type'], equals('pipeline'));
      expect(json['context']['workspaceId'], equals('ws-1'));
    });

    test('fromJson() deserializes correctly', () {
      final original = AuditEvent.create(
        actor: const AuditActor(type: ActorType.service, id: 'svc-1'),
        action: 'data.export',
        resource: const AuditResource(type: 'dataset', id: 'ds-1'),
        outcome: AuditOutcome.success,
        context: const AuditContext(workspaceId: 'ws-1'),
      );

      final json = original.toJson();
      final restored = AuditEvent.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.action, equals(original.action));
      expect(restored.actor.id, equals(original.actor.id));
      expect(restored.resource.type, equals(original.resource.type));
      expect(restored.outcome, equals(original.outcome));
    });

    test('standard action constants are defined', () {
      expect(AuditEvent.pipelineActions, isNotEmpty);
      expect(AuditEvent.pipelineActions, contains('pipeline.start'));

      expect(AuditEvent.workflowActions, isNotEmpty);
      expect(AuditEvent.workflowActions, contains('workflow.start'));

      expect(AuditEvent.scheduleActions, isNotEmpty);
      expect(AuditEvent.scheduleActions, contains('schedule.create'));

      expect(AuditEvent.adminActions, isNotEmpty);
      expect(AuditEvent.adminActions, contains('config.update'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // AuditFilter
  // ═══════════════════════════════════════════════════════════════

  group('AuditFilter', () {
    test('matches() returns true for empty filter', () {
      const filter = AuditFilter();
      final event = AuditEvent.create(
        actor: const AuditActor(type: ActorType.user, id: 'u-1'),
        action: 'test',
        resource: const AuditResource(type: 'test', id: 't-1'),
        outcome: AuditOutcome.success,
        context: const AuditContext(workspaceId: 'ws-1'),
      );

      expect(filter.matches(event), isTrue);
    });

    test('matches() filters by actor', () {
      const filter = AuditFilter(actors: ['user-1']);
      final matching = AuditEvent.create(
        actor: const AuditActor(type: ActorType.user, id: 'user-1'),
        action: 'test',
        resource: const AuditResource(type: 'test', id: 't-1'),
        outcome: AuditOutcome.success,
        context: const AuditContext(workspaceId: 'ws-1'),
      );
      final nonMatching = AuditEvent.create(
        actor: const AuditActor(type: ActorType.user, id: 'user-2'),
        action: 'test',
        resource: const AuditResource(type: 'test', id: 't-1'),
        outcome: AuditOutcome.success,
        context: const AuditContext(workspaceId: 'ws-1'),
      );

      expect(filter.matches(matching), isTrue);
      expect(filter.matches(nonMatching), isFalse);
    });

    test('matches() filters by action', () {
      const filter = AuditFilter(actions: ['pipeline.start', 'pipeline.end']);
      final matching = AuditEvent.create(
        actor: const AuditActor(type: ActorType.user, id: 'u-1'),
        action: 'pipeline.start',
        resource: const AuditResource(type: 'test', id: 't-1'),
        outcome: AuditOutcome.success,
        context: const AuditContext(workspaceId: 'ws-1'),
      );
      final nonMatching = AuditEvent.create(
        actor: const AuditActor(type: ActorType.user, id: 'u-1'),
        action: 'workflow.start',
        resource: const AuditResource(type: 'test', id: 't-1'),
        outcome: AuditOutcome.success,
        context: const AuditContext(workspaceId: 'ws-1'),
      );

      expect(filter.matches(matching), isTrue);
      expect(filter.matches(nonMatching), isFalse);
    });

    test('matches() filters by resource type', () {
      const filter = AuditFilter(resourceTypes: ['pipeline']);
      final matching = AuditEvent.create(
        actor: const AuditActor(type: ActorType.user, id: 'u-1'),
        action: 'test',
        resource: const AuditResource(type: 'pipeline', id: 'p-1'),
        outcome: AuditOutcome.success,
        context: const AuditContext(workspaceId: 'ws-1'),
      );
      final nonMatching = AuditEvent.create(
        actor: const AuditActor(type: ActorType.user, id: 'u-1'),
        action: 'test',
        resource: const AuditResource(type: 'workflow', id: 'w-1'),
        outcome: AuditOutcome.success,
        context: const AuditContext(workspaceId: 'ws-1'),
      );

      expect(filter.matches(matching), isTrue);
      expect(filter.matches(nonMatching), isFalse);
    });

    test('matches() filters by workspace', () {
      const filter = AuditFilter(workspaceId: 'ws-1');
      final matching = AuditEvent.create(
        actor: const AuditActor(type: ActorType.user, id: 'u-1'),
        action: 'test',
        resource: const AuditResource(type: 'test', id: 't-1'),
        outcome: AuditOutcome.success,
        context: const AuditContext(workspaceId: 'ws-1'),
      );
      final nonMatching = AuditEvent.create(
        actor: const AuditActor(type: ActorType.user, id: 'u-1'),
        action: 'test',
        resource: const AuditResource(type: 'test', id: 't-1'),
        outcome: AuditOutcome.success,
        context: const AuditContext(workspaceId: 'ws-2'),
      );

      expect(filter.matches(matching), isTrue);
      expect(filter.matches(nonMatching), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // AuditActor
  // ═══════════════════════════════════════════════════════════════

  group('AuditActor', () {
    test('toJson() serializes correctly', () {
      const actor = AuditActor(
        type: ActorType.user,
        id: 'u-1',
        name: 'Test User',
        ip: '127.0.0.1',
      );

      final json = actor.toJson();
      expect(json['type'], equals('user'));
      expect(json['id'], equals('u-1'));
      expect(json['name'], equals('Test User'));
      expect(json['ip'], equals('127.0.0.1'));
    });

    test('fromJson() round-trips', () {
      const original = AuditActor(
        type: ActorType.service,
        id: 'svc-1',
        name: 'My Service',
      );

      final json = original.toJson();
      final restored = AuditActor.fromJson(json);

      expect(restored.type, equals(ActorType.service));
      expect(restored.id, equals('svc-1'));
      expect(restored.name, equals('My Service'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // AuditResource
  // ═══════════════════════════════════════════════════════════════

  group('AuditResource', () {
    test('toJson() serializes correctly', () {
      const resource = AuditResource(
        type: 'pipeline',
        id: 'p-1',
        name: 'Ingest Pipeline',
        attributes: {'version': '1.0'},
      );

      final json = resource.toJson();
      expect(json['type'], equals('pipeline'));
      expect(json['id'], equals('p-1'));
      expect(json['name'], equals('Ingest Pipeline'));
      expect(json['attributes'], equals({'version': '1.0'}));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Enums
  // ═══════════════════════════════════════════════════════════════

  group('Audit enums', () {
    test('AuditOutcome has all values', () {
      expect(AuditOutcome.values,
          containsAll([AuditOutcome.success, AuditOutcome.failure,
              AuditOutcome.denied]));
    });

    test('ActorType has all values', () {
      expect(ActorType.values,
          containsAll([ActorType.user, ActorType.system,
              ActorType.service, ActorType.schedule]));
    });

    test('ExportFormat has all values', () {
      expect(ExportFormat.values,
          containsAll([ExportFormat.json, ExportFormat.csv,
              ExportFormat.parquet]));
    });
  });
}
