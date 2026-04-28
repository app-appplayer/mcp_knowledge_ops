/// EventStore Tests
///
/// Tests for EventPersister and EventStorageKeys: event persistence,
/// stream position tracking, event retrieval, and correlation indexing.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

void main() {
  group('EventStorageKeys', () {
    test('eventLog generates correct key format', () {
      final key = EventStorageKeys.eventLog('stream-1', 5);
      expect(key, equals('event:stream-1:0000000005'));
    });

    test('eventLog pads position to 10 digits', () {
      final key = EventStorageKeys.eventLog('s', 1);
      expect(key, equals('event:s:0000000001'));
    });

    test('streamPosition generates correct key format', () {
      final key = EventStorageKeys.streamPosition('stream-1');
      expect(key, equals('event:position:stream-1'));
    });

    test('correlationIndex generates correct key format', () {
      final key = EventStorageKeys.correlationIndex('corr-abc');
      expect(key, equals('event:correlation:corr-abc'));
    });
  });

  group('EventPersister', () {
    late InMemoryKvStoragePort kvStorage;
    late EventPersister persister;

    setUp(() {
      kvStorage = InMemoryKvStoragePort();
      persister = EventPersister(kvStorage: kvStorage);
    });

    test('persist() stores event and increments position', () async {
      final event = testOpsEvent(
        eventId: 'evt-1',
        eventType: 'test.persist',
      );

      await persister.persist('stream-a', event);

      final position = await persister.getPosition('stream-a');
      expect(position, equals(1));
    });

    test('persist() increments position for each event', () async {
      final event1 = testOpsEvent(eventId: 'evt-1');
      final event2 = testOpsEvent(eventId: 'evt-2');
      final event3 = testOpsEvent(eventId: 'evt-3');

      await persister.persist('stream-a', event1);
      await persister.persist('stream-a', event2);
      await persister.persist('stream-a', event3);

      final position = await persister.getPosition('stream-a');
      expect(position, equals(3));
    });

    test('readEvent() returns stored event data', () async {
      final event = testOpsEvent(
        eventId: 'evt-read',
        eventType: 'test.read',
      );

      await persister.persist('stream-b', event);

      final storedData = await persister.readEvent('stream-b', 1);
      expect(storedData, isNotNull);
      expect(storedData!['eventId'], equals('evt-read'));
      expect(storedData['eventType'], equals('test.read'));
    });

    test('readEvent() returns null for non-existent position', () async {
      final storedData = await persister.readEvent('stream-c', 99);
      expect(storedData, isNull);
    });

    test('getPosition() returns 0 for non-existent stream', () async {
      final position = await persister.getPosition('nonexistent');
      expect(position, equals(0));
    });

    test('readByCorrelation() returns events with matching correlationId',
        () async {
      final event1 = testOpsEvent(
        eventId: 'evt-c1',
        correlationId: 'corr-shared',
        eventType: 'test.corr.1',
      );
      final event2 = testOpsEvent(
        eventId: 'evt-c2',
        correlationId: 'corr-shared',
        eventType: 'test.corr.2',
      );
      final event3 = testOpsEvent(
        eventId: 'evt-c3',
        correlationId: 'corr-other',
        eventType: 'test.corr.3',
      );

      await persister.persist('stream-d', event1);
      await persister.persist('stream-d', event2);
      await persister.persist('stream-d', event3);

      final correlated =
          await persister.readByCorrelation('corr-shared');
      expect(correlated, hasLength(2));
      expect(
        correlated.map((e) => e['eventId']).toList(),
        containsAll(['evt-c1', 'evt-c2']),
      );
    });

    test('readByCorrelation() returns empty for unknown correlationId',
        () async {
      final events =
          await persister.readByCorrelation('nonexistent-corr');
      expect(events, isEmpty);
    });

    test('events persist across separate streams independently', () async {
      final eventA = testOpsEvent(eventId: 'evt-a');
      final eventB = testOpsEvent(eventId: 'evt-b');

      await persister.persist('stream-x', eventA);
      await persister.persist('stream-y', eventB);

      expect(await persister.getPosition('stream-x'), equals(1));
      expect(await persister.getPosition('stream-y'), equals(1));

      final dataA = await persister.readEvent('stream-x', 1);
      final dataB = await persister.readEvent('stream-y', 1);
      expect(dataA!['eventId'], equals('evt-a'));
      expect(dataB!['eventId'], equals('evt-b'));
    });
  });

  group('EventStreams', () {
    test('pipeline stream ID format', () {
      expect(EventStreams.pipeline('p1'), equals('pipeline-p1'));
    });

    test('workflow stream ID format', () {
      expect(EventStreams.workflow('w1'), equals('workflow-w1'));
    });

    test('execution stream ID format', () {
      expect(EventStreams.execution('e1'), equals('execution-e1'));
    });
  });
}
