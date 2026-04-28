/// EventPublisher Tests
///
/// Tests for OpsEventPublisher: publish delegation, trace enrichment,
/// batch publishing, and acknowledged delivery with retry.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

/// A MockEventPort that can be configured to fail a fixed number of times
/// before succeeding, for testing retry logic.
class FailingEventPort extends MockEventPort {
  int failuresRemaining;

  FailingEventPort({this.failuresRemaining = 0});

  @override
  Future<void> publish(PortEvent event) async {
    calls.add('publish');
    publishedEvents.add(event);
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('Simulated publish failure');
    }
  }
}

void main() {
  group('OpsEventPublisher', () {
    late MockEventPort eventPort;
    late ExecutionLogger logger;

    setUp(() {
      eventPort = MockEventPort();
      final result = testLogger();
      logger = result.$1;
    });

    test('publish() delegates to EventPort', () async {
      final publisher = OpsEventPublisher(
        eventPort: eventPort,
        logger: logger,
      );

      final event = testOpsEvent(eventType: 'test.publish');
      await publisher.publish(event);

      expect(eventPort.calls, contains('publish'));
      expect(eventPort.publishedEvents, hasLength(1));
      expect(eventPort.publishedEvents.first.type, equals('test.publish'));
    });

    test('publish() enriches event with trace context', () async {
      final publisher = OpsEventPublisher(
        eventPort: eventPort,
        logger: logger,
        traceIdProvider: () => 'trace-abc',
        spanIdProvider: () => 'span-xyz',
      );

      // Create event with no trace context in meta
      final event = testOpsEvent(eventType: 'test.traced');
      await publisher.publish(event);

      expect(eventPort.publishedEvents, hasLength(1));
      final published = eventPort.publishedEvents.first;
      // The PortEvent payload should contain enriched meta with trace info
      final meta = published.payload['meta'] as Map<String, dynamic>;
      expect(meta['traceId'], equals('trace-abc'));
      expect(meta['spanId'], equals('span-xyz'));
    });

    test('publish() does not overwrite existing trace context', () async {
      final publisher = OpsEventPublisher(
        eventPort: eventPort,
        logger: logger,
        traceIdProvider: () => 'new-trace',
        spanIdProvider: () => 'new-span',
      );

      // Create event with existing trace context
      final event = OpsEvent(
        eventId: 'evt-1',
        eventType: 'test.existing',
        correlationId: 'corr-1',
        runId: 'run-1',
        workspaceId: 'ws-1',
        timestamp: DateTime(2024, 1, 1),
        payload: {},
        meta: const OpsEventMeta(
          source: 'test',
          traceId: 'existing-trace',
          spanId: 'existing-span',
        ),
      );

      await publisher.publish(event);

      final published = eventPort.publishedEvents.first;
      final meta = published.payload['meta'] as Map<String, dynamic>;
      expect(meta['traceId'], equals('existing-trace'));
      expect(meta['spanId'], equals('existing-span'));
    });

    test('publishBatch() publishes all events in order', () async {
      final publisher = OpsEventPublisher(
        eventPort: eventPort,
        logger: logger,
      );

      final events = [
        testOpsEvent(eventType: 'batch.event.1'),
        testOpsEvent(eventType: 'batch.event.2'),
        testOpsEvent(eventType: 'batch.event.3'),
      ];

      await publisher.publishBatch(events);

      expect(eventPort.publishedEvents, hasLength(3));
      expect(
        eventPort.publishedEvents.map((e) => e.type).toList(),
        equals(['batch.event.1', 'batch.event.2', 'batch.event.3']),
      );
    });

    test('publishBatch() with empty list does nothing', () async {
      final publisher = OpsEventPublisher(
        eventPort: eventPort,
        logger: logger,
      );

      await publisher.publishBatch([]);

      expect(eventPort.publishedEvents, isEmpty);
      expect(eventPort.calls, isEmpty);
    });

    test('publishWithAck() retries on failure then succeeds', () async {
      final failingPort = FailingEventPort(failuresRemaining: 2);
      final publisher = OpsEventPublisher(
        eventPort: failingPort,
        logger: logger,
      );

      final event = testOpsEvent(eventType: 'test.ack');
      await publisher.publishWithAck(
        event,
        timeout: const Duration(seconds: 5),
        maxRetries: 3,
      );

      // Should have attempted 3 times (2 failures + 1 success)
      expect(
        failingPort.calls.where((c) => c == 'publish').length,
        equals(3),
      );
    });

    test('publishWithAck() throws after exhausting retries', () async {
      final failingPort = FailingEventPort(failuresRemaining: 10);
      final publisher = OpsEventPublisher(
        eventPort: failingPort,
        logger: logger,
      );

      final event = testOpsEvent(eventType: 'test.fail');

      expect(
        () => publisher.publishWithAck(
          event,
          timeout: const Duration(seconds: 5),
          maxRetries: 2,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('publish() applies default source when meta.source is empty',
        () async {
      final publisher = OpsEventPublisher(
        eventPort: eventPort,
        logger: logger,
        defaultSource: 'my_source',
      );

      final event = OpsEvent(
        eventId: 'evt-1',
        eventType: 'test.source',
        correlationId: 'corr-1',
        runId: 'run-1',
        workspaceId: 'ws-1',
        timestamp: DateTime(2024, 1, 1),
        payload: {},
        meta: const OpsEventMeta(source: ''),
      );

      await publisher.publish(event);

      final published = eventPort.publishedEvents.first;
      final meta = published.payload['meta'] as Map<String, dynamic>;
      expect(meta['source'], equals('my_source'));
    });
  });
}
