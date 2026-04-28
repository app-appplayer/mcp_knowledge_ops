/// Tests for EventReplayer and its result types.
///
/// Covers ReplayEventResult factories (successful, failed, simulated),
/// their getter semantics, and ReplayResult construction.
library;

import 'package:test/test.dart';

import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

void main() {
  group('ReplayEventResult', () {
    test('successful() factory creates success result', () {
      final event = testOpsEvent(
        eventId: 'evt-success',
        eventType: 'ops.pipeline.started',
      );

      final result = ReplayEventResult.successful(event);

      expect(result.eventId, equals('evt-success'));
      expect(result.eventType, equals('ops.pipeline.started'));
      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.isSuccess, isTrue);
      expect(result.isFailed, isFalse);
    });

    test('failed() factory creates failure result with error', () {
      final event = testOpsEvent(
        eventId: 'evt-fail',
        eventType: 'ops.pipeline.failed',
      );

      final result = ReplayEventResult.failed(event, 'Handler threw exception');

      expect(result.eventId, equals('evt-fail'));
      expect(result.eventType, equals('ops.pipeline.failed'));
      expect(result.success, isFalse);
      expect(result.error, equals('Handler threw exception'));
      expect(result.isSuccess, isFalse);
      expect(result.isFailed, isTrue);
    });

    test('simulated() factory creates success result for dry run', () {
      final event = testOpsEvent(
        eventId: 'evt-sim',
        eventType: 'ops.workflow.completed',
      );

      final result = ReplayEventResult.simulated(event);

      expect(result.eventId, equals('evt-sim'));
      expect(result.eventType, equals('ops.workflow.completed'));
      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.isSuccess, isTrue);
      expect(result.isFailed, isFalse);
    });

    test('isSuccess and isFailed are complementary', () {
      const successResult = ReplayEventResult(
        eventId: 'evt-1',
        eventType: 'test',
        success: true,
      );
      const failedResult = ReplayEventResult(
        eventId: 'evt-2',
        eventType: 'test',
        success: false,
        error: 'oops',
      );

      expect(successResult.isSuccess, isTrue);
      expect(successResult.isFailed, isFalse);
      expect(failedResult.isSuccess, isFalse);
      expect(failedResult.isFailed, isTrue);
    });
  });

  group('ReplayResult', () {
    test('creation and field access', () {
      final event1 = testOpsEvent(eventId: 'evt-r1', eventType: 'type.a');
      final event2 = testOpsEvent(eventId: 'evt-r2', eventType: 'type.b');

      final results = [
        ReplayEventResult.successful(event1),
        ReplayEventResult.failed(event2, 'error msg'),
      ];

      final replayResult = ReplayResult(
        executionId: 'exec-1',
        totalEvents: 10,
        replayedEvents: 2,
        skippedEvents: 8,
        results: results,
        duration: const Duration(milliseconds: 500),
      );

      expect(replayResult.executionId, equals('exec-1'));
      expect(replayResult.totalEvents, equals(10));
      expect(replayResult.replayedEvents, equals(2));
      expect(replayResult.skippedEvents, equals(8));
      expect(replayResult.results, hasLength(2));
      expect(replayResult.duration, equals(const Duration(milliseconds: 500)));
    });

    test('empty results', () {
      const replayResult = ReplayResult(
        executionId: 'exec-empty',
        totalEvents: 0,
        replayedEvents: 0,
        skippedEvents: 0,
        results: [],
        duration: Duration.zero,
      );

      expect(replayResult.results, isEmpty);
      expect(replayResult.totalEvents, equals(0));
    });

    test('results contain mixed success and failure', () {
      final event1 = testOpsEvent(eventId: 'evt-m1');
      final event2 = testOpsEvent(eventId: 'evt-m2');
      final event3 = testOpsEvent(eventId: 'evt-m3');

      final results = [
        ReplayEventResult.successful(event1),
        ReplayEventResult.failed(event2, 'err'),
        ReplayEventResult.simulated(event3),
      ];

      final replayResult = ReplayResult(
        executionId: 'exec-mixed',
        totalEvents: 5,
        replayedEvents: 3,
        skippedEvents: 2,
        results: results,
        duration: const Duration(seconds: 1),
      );

      final successes = replayResult.results.where((r) => r.isSuccess).length;
      final failures = replayResult.results.where((r) => r.isFailed).length;

      expect(successes, equals(2));
      expect(failures, equals(1));
    });
  });
}
