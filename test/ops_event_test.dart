/// OpsEvent and OpsEventMeta tests.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // OpsEventMeta
  // ═══════════════════════════════════════════════════════════════

  group('OpsEventMeta', () {
    test('creates with required source', () {
      final meta = OpsEventMeta(source: 'test-source');

      expect(meta.source, equals('test-source'));
      expect(meta.traceId, isNull);
      expect(meta.spanId, isNull);
    });

    test('creates with all fields', () {
      final meta = OpsEventMeta(
        source: 'test-source',
        traceId: 'trace-123',
        spanId: 'span-456',
      );

      expect(meta.source, equals('test-source'));
      expect(meta.traceId, equals('trace-123'));
      expect(meta.spanId, equals('span-456'));
    });

    test('toJson/fromJson round-trip with all fields', () {
      final original = OpsEventMeta(
        source: 'my-service',
        traceId: 'trace-abc',
        spanId: 'span-def',
      );

      final json = original.toJson();
      final restored = OpsEventMeta.fromJson(json);

      expect(restored.source, equals(original.source));
      expect(restored.traceId, equals(original.traceId));
      expect(restored.spanId, equals(original.spanId));
    });

    test('toJson omits null fields', () {
      final meta = OpsEventMeta(source: 'minimal');
      final json = meta.toJson();

      expect(json, containsPair('source', 'minimal'));
      expect(json.containsKey('traceId'), isFalse);
      expect(json.containsKey('spanId'), isFalse);
    });

    test('copyWith updates specified fields', () {
      final meta = OpsEventMeta(
        source: 'original',
        traceId: 'trace-1',
        spanId: 'span-1',
      );

      final updated = meta.copyWith(source: 'updated-source');

      expect(updated.source, equals('updated-source'));
      expect(updated.traceId, equals('trace-1'));
      expect(updated.spanId, equals('span-1'));
    });

    test('copyWith preserves unchanged fields', () {
      final meta = OpsEventMeta(
        source: 'src',
        traceId: 'trace-x',
        spanId: 'span-y',
      );

      final copied = meta.copyWith(spanId: 'span-new');

      expect(copied.source, equals('src'));
      expect(copied.traceId, equals('trace-x'));
      expect(copied.spanId, equals('span-new'));
    });

    test('toString includes all fields', () {
      final meta = OpsEventMeta(
        source: 'svc',
        traceId: 't1',
        spanId: 's1',
      );

      final str = meta.toString();
      expect(str, contains('svc'));
      expect(str, contains('t1'));
      expect(str, contains('s1'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // OpsEvent
  // ═══════════════════════════════════════════════════════════════

  group('OpsEvent', () {
    final testMeta = OpsEventMeta(source: 'test');
    final testTimestamp = DateTime(2024, 6, 15, 10, 30);

    test('creates with all required fields', () {
      final event = OpsEvent(
        eventId: 'evt-001',
        eventType: 'ops.test.created',
        correlationId: 'corr-1',
        runId: 'run-1',
        workspaceId: 'ws-1',
        timestamp: testTimestamp,
        payload: {'key': 'value'},
        meta: testMeta,
      );

      expect(event.eventId, equals('evt-001'));
      expect(event.eventType, equals('ops.test.created'));
      expect(event.version, equals('1.0'));
      expect(event.correlationId, equals('corr-1'));
      expect(event.causationId, isNull);
      expect(event.runId, equals('run-1'));
      expect(event.workspaceId, equals('ws-1'));
      expect(event.timestamp, equals(testTimestamp));
      expect(event.payload, equals({'key': 'value'}));
      expect(event.meta.source, equals('test'));
    });

    test('OpsEvent.create() auto-generates eventId and timestamp', () {
      final before = DateTime.now();
      final event = OpsEvent.create(
        eventType: 'ops.test.auto',
        correlationId: 'corr-auto',
        runId: 'run-auto',
        workspaceId: 'ws-auto',
        payload: {'data': 1},
        meta: testMeta,
      );
      final after = DateTime.now();

      expect(event.eventId, isNotEmpty);
      expect(event.eventId, startsWith('evt_'));
      expect(event.eventType, equals('ops.test.auto'));
      expect(
        event.timestamp.isAfter(before) ||
            event.timestamp.isAtSameMomentAs(before),
        isTrue,
      );
      expect(
        event.timestamp.isBefore(after) ||
            event.timestamp.isAtSameMomentAs(after),
        isTrue,
      );
    });

    test('OpsEvent.create() accepts causationId and version', () {
      final event = OpsEvent.create(
        eventType: 'ops.test.versioned',
        version: '2.0',
        correlationId: 'corr-v',
        causationId: 'cause-v',
        runId: 'run-v',
        workspaceId: 'ws-v',
        payload: {},
        meta: testMeta,
      );

      expect(event.version, equals('2.0'));
      expect(event.causationId, equals('cause-v'));
    });

    test('generateEventId() produces unique IDs', () {
      final ids = <String>{};
      for (var i = 0; i < 100; i++) {
        ids.add(OpsEvent.generateEventId());
      }
      // All generated IDs should be unique
      expect(ids.length, equals(100));
    });

    test('generateEventId() starts with evt_ prefix', () {
      final id = OpsEvent.generateEventId();
      expect(id, startsWith('evt_'));
    });

    test('toJson/fromJson round-trip', () {
      final original = OpsEvent(
        eventId: 'evt-rt-001',
        eventType: 'ops.test.roundtrip',
        version: '2.0',
        correlationId: 'corr-rt',
        causationId: 'cause-rt',
        runId: 'run-rt',
        workspaceId: 'ws-rt',
        timestamp: testTimestamp,
        payload: {
          'nested': {'a': 1},
          'list': [1, 2, 3]
        },
        meta: OpsEventMeta(
          source: 'round-trip',
          traceId: 'trace-rt',
          spanId: 'span-rt',
        ),
      );

      final json = original.toJson();
      final restored = OpsEvent.fromJson(json);

      expect(restored.eventId, equals(original.eventId));
      expect(restored.eventType, equals(original.eventType));
      expect(restored.version, equals(original.version));
      expect(restored.correlationId, equals(original.correlationId));
      expect(restored.causationId, equals(original.causationId));
      expect(restored.runId, equals(original.runId));
      expect(restored.workspaceId, equals(original.workspaceId));
      expect(restored.timestamp, equals(original.timestamp));
      expect(restored.payload, equals(original.payload));
      expect(restored.meta.source, equals(original.meta.source));
      expect(restored.meta.traceId, equals(original.meta.traceId));
      expect(restored.meta.spanId, equals(original.meta.spanId));
    });

    test('toJson omits null causationId', () {
      final event = OpsEvent(
        eventId: 'evt-no-cause',
        eventType: 'ops.test.nocause',
        correlationId: 'corr-nc',
        runId: 'run-nc',
        workspaceId: 'ws-nc',
        timestamp: testTimestamp,
        payload: {},
        meta: testMeta,
      );

      final json = event.toJson();
      expect(json.containsKey('causationId'), isFalse);
    });

    test('toPortEvent/fromPortEvent conversion', () {
      final original = OpsEvent(
        eventId: 'evt-port-001',
        eventType: 'ops.test.port',
        version: '1.0',
        correlationId: 'corr-port',
        causationId: 'cause-port',
        runId: 'run-port',
        workspaceId: 'ws-port',
        timestamp: testTimestamp,
        payload: {'action': 'test'},
        meta: OpsEventMeta(source: 'port-test', traceId: 'trace-p'),
      );

      final portEvent = original.toPortEvent();

      expect(portEvent.type, equals('ops.test.port'));
      expect(portEvent.timestamp, equals(testTimestamp));
      expect(portEvent.source, equals('port-test'));
      expect(portEvent.payload['eventId'], equals('evt-port-001'));
      expect(portEvent.payload['correlationId'], equals('corr-port'));
      expect(portEvent.payload['causationId'], equals('cause-port'));
      expect(portEvent.payload['runId'], equals('run-port'));
      expect(portEvent.payload['workspaceId'], equals('ws-port'));

      // Round-trip back through fromPortEvent
      final restored = OpsEvent.fromPortEvent(portEvent);

      expect(restored.eventId, equals(original.eventId));
      expect(restored.eventType, equals(original.eventType));
      expect(restored.correlationId, equals(original.correlationId));
      expect(restored.causationId, equals(original.causationId));
      expect(restored.runId, equals(original.runId));
      expect(restored.workspaceId, equals(original.workspaceId));
      expect(restored.meta.source, equals(original.meta.source));
    });

    test('fromPortEvent handles missing optional fields', () {
      final portEvent = PortEvent(
        type: 'ops.test.minimal',
        payload: {},
        timestamp: testTimestamp,
      );

      final event = OpsEvent.fromPortEvent(portEvent);

      expect(event.eventType, equals('ops.test.minimal'));
      expect(event.eventId, isNotEmpty);
      expect(event.correlationId, isNotEmpty);
      expect(event.runId, equals(''));
      expect(event.workspaceId, equals(''));
      expect(event.meta.source, equals('unknown'));
    });

    test('copyWith preserves unchanged fields', () {
      final original = OpsEvent(
        eventId: 'evt-cp-001',
        eventType: 'ops.test.copy',
        version: '1.0',
        correlationId: 'corr-cp',
        causationId: 'cause-cp',
        runId: 'run-cp',
        workspaceId: 'ws-cp',
        timestamp: testTimestamp,
        payload: {'original': true},
        meta: testMeta,
      );

      final copied = original.copyWith(eventType: 'ops.test.copied');

      expect(copied.eventType, equals('ops.test.copied'));
      // All other fields unchanged
      expect(copied.eventId, equals(original.eventId));
      expect(copied.version, equals(original.version));
      expect(copied.correlationId, equals(original.correlationId));
      expect(copied.causationId, equals(original.causationId));
      expect(copied.runId, equals(original.runId));
      expect(copied.workspaceId, equals(original.workspaceId));
      expect(copied.timestamp, equals(original.timestamp));
      expect(copied.payload, equals(original.payload));
      expect(copied.meta.source, equals(original.meta.source));
    });

    test('copyWith updates multiple fields', () {
      final original = OpsEvent(
        eventId: 'evt-multi',
        eventType: 'ops.test.multi',
        correlationId: 'corr-m',
        runId: 'run-m',
        workspaceId: 'ws-m',
        timestamp: testTimestamp,
        payload: {},
        meta: testMeta,
      );

      final newMeta = OpsEventMeta(source: 'new-source');
      final copied = original.copyWith(
        payload: {'updated': true},
        meta: newMeta,
        correlationId: 'corr-new',
        runId: 'run-new',
      );

      expect(copied.payload, equals({'updated': true}));
      expect(copied.meta.source, equals('new-source'));
      expect(copied.correlationId, equals('corr-new'));
      expect(copied.runId, equals('run-new'));
      // Unchanged
      expect(copied.eventId, equals('evt-multi'));
      expect(copied.eventType, equals('ops.test.multi'));
      expect(copied.workspaceId, equals('ws-m'));
    });

    test('toString includes key fields', () {
      final event = OpsEvent(
        eventId: 'evt-str-001',
        eventType: 'ops.test.str',
        correlationId: 'corr-str',
        runId: 'run-str',
        workspaceId: 'ws-str',
        timestamp: testTimestamp,
        payload: {},
        meta: testMeta,
      );

      final str = event.toString();
      expect(str, contains('evt-str-001'));
      expect(str, contains('ops.test.str'));
      expect(str, contains('corr-str'));
      expect(str, contains('run-str'));
    });
  });
}
