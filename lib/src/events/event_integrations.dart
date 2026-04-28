/// Event Integrations - Integration handlers between events and external
/// systems.
///
/// Provides handlers for connecting the event system to the standard
/// fact-graph ports (`FactsPort`) and notification delivery, enabling
/// reactive cross-system coordination.
///
/// Per REDESIGN-PLAN.md Phase 7 (no-legacy) this module uses `FactsPort`
/// instead of the removed `FactGraphPort`.
library;

import '../ports/ops_port.dart';
import 'event_publisher.dart';
import 'ops_event.dart';
import 'event_router.dart';

/// Integration between events and fact-graph operations.
///
/// Listens for fact graph update events and triggers dependent pipeline
/// refreshes or cache invalidations. Accepts an [EventPublisher] and a
/// [FactsPort] dependency for concrete operations.
class FactGraphEventIntegration {
  /// Event publisher for emitting derived events.
  final EventPublisher? _publisher;

  /// FactsPort for querying and updating facts.
  final FactsPort? _facts;

  FactGraphEventIntegration({
    EventPublisher? publisher,
    FactsPort? facts,
  })  : _publisher = publisher,
        _facts = facts;

  /// Execute an operation and wrap it with event publication.
  ///
  /// Publishes a FactGraphUpdatedEvent before and after the operation.
  Future<T> withEvent<T>({
    required String operationName,
    required String entityId,
    required String runId,
    required String workspaceId,
    required Future<T> Function() operation,
  }) async {
    final result = await operation();

    if (_publisher != null) {
      await _publisher!.publish(OpsEvent.create(
        eventType: 'ops.integration.factgraph_updated',
        correlationId: runId,
        runId: runId,
        workspaceId: workspaceId,
        payload: {
          'factId': entityId,
          'operation': operationName,
        },
        meta: const OpsEventMeta(source: 'factgraph_integration'),
      ));
    }

    return result;
  }

  /// Handle a fact graph update event.
  Future<void> onFactGraphUpdated(OpsEvent event) async {
    final facts = _facts;
    if (facts == null) return;

    final factId = event.payload['factId'] as String?;
    if (factId == null) return;

    // Query dependents via FactsPort. Since FactsPort.queryFacts takes a
    // typed FactQuery, we use a filters map for implementation-defined
    // relationship lookups.
    final dependents = await facts.queryFacts(FactQuery(
      workspaceId: event.workspaceId,
      filters: {'type': 'dependents', 'factId': factId},
    ));

    if (dependents.isNotEmpty && _publisher != null) {
      await _publisher!.publish(OpsEvent.create(
        eventType: 'ops.integration.factgraph_updated',
        correlationId: event.correlationId,
        runId: event.runId,
        workspaceId: event.workspaceId,
        payload: {
          'factId': factId,
          'operation': 'cascade_invalidation',
          'dependents': dependents.map((f) => f.id).toList(),
        },
        meta: event.meta,
      ));
    }
  }

  /// Subscribe to relevant fact graph events on the router.
  void registerHandlers(EventRouter eventRouter) {
    eventRouter.register(
      'ops.integration.factgraph_updated',
      onFactGraphUpdated,
    );
  }
}

/// Notification handlers triggered by events.
///
/// Routes events that require user notification to the appropriate
/// notification channel via the [NotificationPort].
class NotificationEventHandlers {
  /// Notification port for delivering notifications.
  final NotificationPort? _notification;

  NotificationEventHandlers({
    NotificationPort? notification,
  }) : _notification = notification;

  /// Handle events that require notifications.
  Future<void> onNotificationRequired(OpsEvent event) async {
    if (_notification == null) return;

    final notification = _buildNotification(event);
    if (notification != null) {
      await _notification!.notify(notification);
    }
  }

  /// Build a notification from an event based on event type.
  Notification? _buildNotification(OpsEvent event) {
    switch (event.eventType) {
      case 'ops.workflow.approval_requested':
        return Notification(
          notificationId: event.eventId,
          recipientId: 'team',
          type: NotificationType.action,
          title: 'Approval Required',
          body: 'Workflow ${event.payload['workflowId']} requires approval',
        );

      case 'ops.execution.failed':
      case 'ops.pipeline.failed':
      case 'ops.workflow.failed':
        return Notification(
          notificationId: event.eventId,
          recipientId: 'ops-team',
          type: NotificationType.error,
          title: 'Execution Failed',
          body: 'Run ${event.runId} failed: '
              '${event.payload['error'] ?? 'Unknown error'}',
        );

      case 'ops.workflow.completed':
        return Notification(
          notificationId: event.eventId,
          recipientId: 'team',
          type: NotificationType.info,
          title: 'Workflow Completed',
          body:
              'Workflow ${event.payload['workflowId']} completed successfully',
        );

      default:
        return null;
    }
  }

  /// Register notification event handlers on the router.
  void registerHandlers(EventRouter eventRouter) {
    eventRouter.register(
      'ops.workflow.approval_requested',
      onNotificationRequired,
    );
    eventRouter.register(
      'ops.execution.failed',
      onNotificationRequired,
    );
    eventRouter.register(
      'ops.pipeline.failed',
      onNotificationRequired,
    );
    eventRouter.register(
      'ops.workflow.failed',
      onNotificationRequired,
    );
    eventRouter.register(
      'ops.workflow.completed',
      onNotificationRequired,
    );
  }
}
