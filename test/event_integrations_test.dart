/// Tests for FactGraphEventIntegration and NotificationEventHandlers.
///
/// Covers creation, handler registration, and basic interaction patterns.
library;

import 'package:test/test.dart';

import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

void main() {
  group('FactGraphEventIntegration', () {
    test('creation with no dependencies', () {
      final integration = FactGraphEventIntegration();

      // Should not throw when created without dependencies
      expect(integration, isA<FactGraphEventIntegration>());
    });

    test('creation with publisher and facts port', () {
      final testPorts = TestOpsPorts();
      final loggerPair = testLogger();
      final publisher = OpsEventPublisher(
        eventPort: testPorts.event,
        logger: loggerPair.$1,
      );
      final facts = MockFactsPort();

      final integration = FactGraphEventIntegration(
        publisher: publisher,
        facts: facts,
      );

      expect(integration, isA<FactGraphEventIntegration>());
    });

    test('registerHandlers adds handler to router', () {
      final loggerPair = testLogger();
      final router = EventRouter(logger: loggerPair.$1);

      final integration = FactGraphEventIntegration();
      integration.registerHandlers(router);

      // The handler should be registered for the factgraph_updated pattern
      expect(
        router.registeredPatterns,
        contains('ops.integration.factgraph_updated'),
      );
      expect(
        router.handlerCount('ops.integration.factgraph_updated'),
        equals(1),
      );
    });

    test('withEvent executes operation and returns result', () async {
      final integration = FactGraphEventIntegration();

      final result = await integration.withEvent<int>(
        operationName: 'test-op',
        entityId: 'entity-1',
        runId: 'run-1',
        workspaceId: 'ws-1',
        operation: () async => 42,
      );

      expect(result, equals(42));
    });

    test('withEvent publishes event when publisher is provided', () async {
      final eventPort = MockEventPort();
      final loggerPair = testLogger();
      final publisher = OpsEventPublisher(
        eventPort: eventPort,
        logger: loggerPair.$1,
      );

      final integration = FactGraphEventIntegration(publisher: publisher);

      await integration.withEvent<String>(
        operationName: 'create',
        entityId: 'fact-1',
        runId: 'run-pub',
        workspaceId: 'ws-pub',
        operation: () async => 'done',
      );

      expect(eventPort.publishedEvents, hasLength(1));
      expect(
        eventPort.publishedEvents.first.type,
        equals('ops.integration.factgraph_updated'),
      );
    });
  });

  group('NotificationEventHandlers', () {
    test('creation with no notification port', () {
      final handlers = NotificationEventHandlers();

      expect(handlers, isA<NotificationEventHandlers>());
    });

    test('creation with notification port', () {
      final mockNotification = MockNotificationPort();
      final handlers = NotificationEventHandlers(
        notification: mockNotification,
      );

      expect(handlers, isA<NotificationEventHandlers>());
    });

    test('registerHandlers adds handlers for all notification event types', () {
      final loggerPair = testLogger();
      final router = EventRouter(logger: loggerPair.$1);

      final handlers = NotificationEventHandlers();
      handlers.registerHandlers(router);

      // Should register handlers for 5 event types
      expect(
        router.registeredPatterns,
        containsAll([
          'ops.workflow.approval_requested',
          'ops.execution.failed',
          'ops.pipeline.failed',
          'ops.workflow.failed',
          'ops.workflow.completed',
        ]),
      );
    });

    test('onNotificationRequired is no-op without notification port', () async {
      final handlers = NotificationEventHandlers();
      final event = testOpsEvent(
        eventType: 'ops.workflow.approval_requested',
        payload: {'workflowId': 'wf-1'},
      );

      // Should not throw when no notification port is set
      await handlers.onNotificationRequired(event);
    });

    test('onNotificationRequired sends notification for known event type',
        () async {
      final mockNotification = MockNotificationPort();
      final handlers = NotificationEventHandlers(
        notification: mockNotification,
      );
      final event = testOpsEvent(
        eventType: 'ops.execution.failed',
        runId: 'run-fail',
        payload: {'error': 'something broke'},
      );

      await handlers.onNotificationRequired(event);

      expect(mockNotification.sentNotifications, hasLength(1));
      expect(
        mockNotification.sentNotifications.first.title,
        equals('Execution Failed'),
      );
    });

    test('onNotificationRequired ignores unknown event types', () async {
      final mockNotification = MockNotificationPort();
      final handlers = NotificationEventHandlers(
        notification: mockNotification,
      );
      final event = testOpsEvent(
        eventType: 'ops.some.unknown.type',
      );

      await handlers.onNotificationRequired(event);

      expect(mockNotification.sentNotifications, isEmpty);
    });
  });
}
