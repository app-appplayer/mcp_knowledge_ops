/// DeadLetterQueue Tests
///
/// Tests for DeadLetterQueue: enqueue, pending count, list pending,
/// and process actions (retry, discard, requeue).
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

void main() {
  group('DeadLetterQueue', () {
    late MockKvStorage kvStorage;
    late MockEventPort eventPort;
    late ExecutionLogger logger;
    late DeadLetterQueue dlq;

    setUp(() {
      kvStorage = MockKvStorage();
      eventPort = MockEventPort();
      final result = testLogger();
      logger = result.$1;

      dlq = DeadLetterQueue(
        kvStorage: kvStorage,
        eventPort: eventPort,
        logger: logger,
      );
    });

    test('enqueue() stores event and increments count', () async {
      final event = testOpsEvent(eventId: 'evt-dlq-1');

      await dlq.enqueue(
        event,
        'testHandler',
        StateError('Handler failed'),
        StackTrace.current,
        1,
      );

      final count = await dlq.getPendingCount();
      expect(count, equals(1));
    });

    test('enqueue() multiple events increments count correctly', () async {
      for (var i = 0; i < 3; i++) {
        final event = testOpsEvent(eventId: 'evt-dlq-$i');
        await dlq.enqueue(
          event,
          'testHandler',
          StateError('fail-$i'),
          StackTrace.current,
          1,
        );
      }

      final count = await dlq.getPendingCount();
      expect(count, equals(3));
    });

    test('getPendingCount() returns 0 for empty queue', () async {
      final count = await dlq.getPendingCount();
      expect(count, equals(0));
    });

    test('listPending() returns enqueued event IDs', () async {
      final event1 = testOpsEvent(eventId: 'evt-list-1');
      final event2 = testOpsEvent(eventId: 'evt-list-2');

      await dlq.enqueue(
        event1,
        'handler',
        StateError('fail'),
        StackTrace.current,
        1,
      );
      await dlq.enqueue(
        event2,
        'handler',
        StateError('fail'),
        StackTrace.current,
        1,
      );

      final pending = await dlq.listPending();
      expect(pending, hasLength(2));
      expect(pending, contains('evt-list-1'));
      expect(pending, contains('evt-list-2'));
    });

    test('listPending() respects limit', () async {
      for (var i = 0; i < 5; i++) {
        final event = testOpsEvent(eventId: 'evt-limit-$i');
        await dlq.enqueue(
          event,
          'handler',
          StateError('fail'),
          StackTrace.current,
          1,
        );
      }

      final pending = await dlq.listPending(limit: 3);
      expect(pending, hasLength(3));
    });

    test('process() with discard removes entry from queue', () async {
      final event = testOpsEvent(eventId: 'evt-discard');
      await dlq.enqueue(
        event,
        'handler',
        StateError('fail'),
        StackTrace.current,
        1,
      );

      final result = await dlq.process(
        'evt-discard',
        action: DlqAction.discard,
        reason: 'Not recoverable',
      );

      expect(result.success, isTrue);
      expect(result.message, contains('discarded'));
      expect(result.message, contains('evt-discard'));
    });

    test('process() with retry re-publishes event via EventPort', () async {
      final event = testOpsEvent(eventId: 'evt-retry');
      await dlq.enqueue(
        event,
        'handler',
        StateError('fail'),
        StackTrace.current,
        1,
      );

      final result = await dlq.process(
        'evt-retry',
        action: DlqAction.retry,
      );

      expect(result.success, isTrue);
      expect(result.message, contains('retried'));
      // Verify EventPort was called to re-publish
      expect(eventPort.calls, contains('publish'));
    });

    test('process() with requeue resets attempt count', () async {
      final event = testOpsEvent(eventId: 'evt-requeue');
      await dlq.enqueue(
        event,
        'handler',
        StateError('fail'),
        StackTrace.current,
        5,
      );

      final result = await dlq.process(
        'evt-requeue',
        action: DlqAction.requeue,
      );

      expect(result.success, isTrue);
      expect(result.message, contains('requeued'));
    });

    test('process() returns notFound for non-existent event', () async {
      final result = await dlq.process(
        'nonexistent',
        action: DlqAction.retry,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('not found'));
    });
  });

  group('DlqAction', () {
    test('has expected values', () {
      expect(DlqAction.values, hasLength(3));
      expect(DlqAction.values, contains(DlqAction.retry));
      expect(DlqAction.values, contains(DlqAction.discard));
      expect(DlqAction.values, contains(DlqAction.requeue));
    });
  });

  group('DlqProcessResult', () {
    test('notFound factory', () {
      final result = DlqProcessResult.notFound('evt-x');
      expect(result.success, isFalse);
      expect(result.message, contains('evt-x'));
    });

    test('retried factory', () {
      final result = DlqProcessResult.retried('evt-x');
      expect(result.success, isTrue);
      expect(result.message, contains('retried'));
    });

    test('discarded factory', () {
      final result = DlqProcessResult.discarded('evt-x', 'reason');
      expect(result.success, isTrue);
      expect(result.message, contains('discarded'));
      expect(result.message, contains('reason'));
    });

    test('requeued factory', () {
      final result = DlqProcessResult.requeued('evt-x');
      expect(result.success, isTrue);
      expect(result.message, contains('requeued'));
    });

    test('toString includes success and message', () {
      const result = DlqProcessResult(success: true, message: 'ok');
      expect(result.toString(), contains('true'));
      expect(result.toString(), contains('ok'));
    });
  });
}
