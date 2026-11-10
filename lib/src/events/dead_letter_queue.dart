/// DeadLetterQueue - Stores and manages failed events for recovery.
///
/// Events that fail handler processing are stored in KvStoragePort.
/// Retry re-publishes via EventPort. DLQ index and count are maintained
/// in KvStoragePort for querying.
library;

import '../ports/ops_port.dart';
import '../observability/logger.dart';
import 'ops_event.dart';

/// Action to take when processing a dead letter entry.
enum DlqAction {
  /// Retry the failed event (re-publish via EventPort).
  retry,

  /// Permanently discard the failed event.
  discard,

  /// Re-queue the event for later processing.
  requeue,
}

/// Result of processing a dead letter entry.
class DlqProcessResult {
  /// Whether the processing action succeeded.
  final bool success;

  /// Descriptive message about the outcome.
  final String message;

  const DlqProcessResult({
    required this.success,
    required this.message,
  });

  /// Entry not found in DLQ.
  factory DlqProcessResult.notFound(String eventId) {
    return DlqProcessResult(
      success: false,
      message: 'Entry not found in dead letter queue: $eventId',
    );
  }

  /// Event retried successfully.
  factory DlqProcessResult.retried(String eventId) {
    return DlqProcessResult(
      success: true,
      message: 'Event retried: $eventId',
    );
  }

  /// Event discarded.
  factory DlqProcessResult.discarded(String eventId, String? reason) {
    return DlqProcessResult(
      success: true,
      message: 'Event discarded: $eventId${reason != null ? ' ($reason)' : ''}',
    );
  }

  /// Event requeued.
  factory DlqProcessResult.requeued(String eventId) {
    return DlqProcessResult(
      success: true,
      message: 'Event requeued: $eventId',
    );
  }

  @override
  String toString() => 'DlqProcessResult(success: $success, message: $message)';
}

/// Dead letter queue for managing failed events.
///
/// Uses [KvStoragePort] for persistent DLQ storage and [EventPort]
/// for re-publishing retried events.
class DeadLetterQueue {
  /// Key-value storage for DLQ entries.
  final KvStoragePort _kvStorage;

  /// Event port for re-publishing retried events.
  final EventPort _eventPort;

  /// Optional notification port for DLQ alerts.
  final NotificationPort? _notification;

  /// Logger for DLQ operations.
  final ExecutionLogger _logger;

  DeadLetterQueue({
    required KvStoragePort kvStorage,
    required EventPort eventPort,
    NotificationPort? notification,
    required ExecutionLogger logger,
  })  : _kvStorage = kvStorage,
        _eventPort = eventPort,
        _notification = notification,
        _logger = logger.child('dead_letter_queue');

  /// Key conventions for DLQ storage.
  static String dlqKey(String eventId) => 'dlq:$eventId';

  /// Key for DLQ entry count.
  static const dlqCountKey = 'dlq:count';

  /// Key for DLQ entry index (list of event IDs).
  static const dlqIndexKey = 'dlq:index';

  /// Enqueue a failed event into the dead letter queue.
  ///
  /// Creates a DLQ entry in KvStoragePort capturing the event, the handler
  /// that failed, the error details, and the number of attempts made.
  Future<void> enqueue(
    OpsEvent event,
    String handlerName,
    Object error,
    StackTrace stack,
    int attemptCount,
  ) async {
    final dlqEntry = {
      'originalEvent': event.toJson(),
      'handlerName': handlerName,
      'error': error.toString(),
      'stack': stack.toString(),
      'attemptCount': attemptCount,
      'enqueuedAt': DateTime.now().toIso8601String(),
      'status': 'pending',
    };

    // Store in KvStoragePort
    await _kvStorage.set(dlqKey(event.eventId), dlqEntry);

    // Update DLQ index
    final index = (await _kvStorage.get(dlqIndexKey) as List<dynamic>?) ?? [];
    index.add(event.eventId);
    await _kvStorage.set(dlqIndexKey, index);

    // Update count
    final count = (await _kvStorage.get(dlqCountKey) as int?) ?? 0;
    await _kvStorage.set(dlqCountKey, count + 1);

    _logger.error('Event sent to DLQ', context: {
      'eventId': event.eventId,
      'handler': handlerName,
      'error': error.toString(),
    });

    // Alert if DLQ is growing
    if ((count + 1) % 100 == 0 && _notification != null) {
      _logger.warn('DLQ has ${count + 1} unprocessed events');
      await _notification!.notify(Notification(
        notificationId: 'dlq-alert-${count + 1}',
        recipientId: 'ops-team',
        type: NotificationType.error,
        title: 'Dead Letter Queue Alert',
        body: 'DLQ has ${count + 1} unprocessed events. '
            'Latest: ${event.eventId} (${event.eventType}) '
            'failed in handler $handlerName.',
      ));
    }
  }

  /// Process a DLQ entry with the specified action.
  ///
  /// - [DlqAction.retry]: Read from KvStoragePort, re-publish via EventPort.
  /// - [DlqAction.discard]: Remove entry from KvStoragePort.
  /// - [DlqAction.requeue]: Reset attempt count for later processing.
  Future<DlqProcessResult> process(
    String eventId, {
    required DlqAction action,
    String? reason,
  }) async {
    switch (action) {
      case DlqAction.retry:
        // Read from KvStoragePort, re-publish via EventPort
        final entry =
            await _kvStorage.get(dlqKey(eventId)) as Map<String, dynamic>?;
        if (entry == null) return DlqProcessResult.notFound(eventId);
        final event =
            OpsEvent.fromJson(entry['originalEvent'] as Map<String, dynamic>);
        await _eventPort.publish(event.toPortEvent());
        await _kvStorage.remove(dlqKey(eventId));
        return DlqProcessResult.retried(eventId);

      case DlqAction.discard:
        await _kvStorage.remove(dlqKey(eventId));
        return DlqProcessResult.discarded(eventId, reason);

      case DlqAction.requeue:
        return await _requeueEvent(eventId);
    }
  }

  /// Re-queue an event for later processing.
  Future<DlqProcessResult> _requeueEvent(String eventId) async {
    final entry =
        await _kvStorage.get(dlqKey(eventId)) as Map<String, dynamic>?;
    if (entry == null) return DlqProcessResult.notFound(eventId);

    // Reset attempt count and update timestamp
    entry['attemptCount'] = 0;
    entry['requeuedAt'] = DateTime.now().toIso8601String();
    entry['status'] = 'requeued';
    await _kvStorage.set(dlqKey(eventId), entry);

    return DlqProcessResult.requeued(eventId);
  }

  /// Get the count of pending DLQ entries.
  Future<int> getPendingCount() async {
    return (await _kvStorage.get(dlqCountKey) as int?) ?? 0;
  }

  /// List pending DLQ entry IDs.
  Future<List<String>> listPending({int limit = 100}) async {
    final index = (await _kvStorage.get(dlqIndexKey) as List<dynamic>?) ?? [];
    final ids = index.cast<String>();
    if (ids.length <= limit) return ids;
    return ids.sublist(0, limit);
  }
}
