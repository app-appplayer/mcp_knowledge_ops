/// Event Persistence - KvStoragePort-based event storage for ops.
///
/// Provides event persistence via KvStoragePort with key conventions,
/// stream identifiers, and persistence utilities.
/// EventPort (from mcp_bundle) handles real-time pub/sub.
/// KvStoragePort handles persistence for replay, audit, and DLQ.
library;

import '../ports/ops_port.dart';
import 'ops_event.dart';

/// Key conventions for event persistence in KvStoragePort.
class EventStorageKeys {
  EventStorageKeys._();

  /// Event log: ordered by position within a logical stream.
  static String eventLog(String streamId, int position) =>
      'event:$streamId:${position.toString().padLeft(10, '0')}';

  /// Stream position counter.
  static String streamPosition(String streamId) =>
      'event:position:$streamId';

  /// Correlation index (list of event keys with same correlationId).
  static String correlationIndex(String correlationId) =>
      'event:correlation:$correlationId';
}

/// Logical stream identifiers for event grouping.
///
/// Provides consistent naming conventions for event streams
/// associated with various ops execution concepts.
class EventStreams {
  EventStreams._();

  /// Stream ID for a pipeline execution.
  static String pipeline(String pipelineId) => 'pipeline-$pipelineId';

  /// Stream ID for a workflow execution.
  static String workflow(String workflowId) => 'workflow-$workflowId';

  /// Stream ID for a generic execution run.
  static String execution(String executionId) => 'execution-$executionId';
}

/// Persist events to KvStoragePort after publishing via EventPort.
///
/// This class is responsible for durable event storage. Real-time
/// event delivery is handled by EventPort (pub/sub).
class EventPersister {
  /// Key-value storage for event persistence.
  final KvStoragePort _kvStorage;

  EventPersister({required KvStoragePort kvStorage}) : _kvStorage = kvStorage;

  /// Persist an event to a logical stream.
  ///
  /// Increments the stream position, stores the event keyed by position,
  /// and updates the correlation index.
  Future<void> persist(String streamId, OpsEvent event) async {
    // Increment position
    final posKey = EventStorageKeys.streamPosition(streamId);
    final currentPos = (await _kvStorage.get(posKey) as int?) ?? 0;
    final newPos = currentPos + 1;

    // Store event
    final eventKey = EventStorageKeys.eventLog(streamId, newPos);
    await _kvStorage.set(eventKey, event.toJson());
    await _kvStorage.set(posKey, newPos);

    // Update correlation index
    final corrKey = EventStorageKeys.correlationIndex(event.correlationId);
    final existing = (await _kvStorage.get(corrKey) as List<dynamic>?) ?? [];
    existing.add(eventKey);
    await _kvStorage.set(corrKey, existing);
  }

  /// Read the current position (event count) of a stream.
  Future<int> getPosition(String streamId) async {
    final posKey = EventStorageKeys.streamPosition(streamId);
    return (await _kvStorage.get(posKey) as int?) ?? 0;
  }

  /// Read a single event by stream and position.
  Future<Map<String, dynamic>?> readEvent(
    String streamId,
    int position,
  ) async {
    final eventKey = EventStorageKeys.eventLog(streamId, position);
    return await _kvStorage.get(eventKey) as Map<String, dynamic>?;
  }

  /// Read events by correlation ID.
  Future<List<Map<String, dynamic>>> readByCorrelation(
    String correlationId,
  ) async {
    final corrKey = EventStorageKeys.correlationIndex(correlationId);
    final eventKeys = (await _kvStorage.get(corrKey) as List<dynamic>?) ?? [];

    final events = <Map<String, dynamic>>[];
    for (final key in eventKeys) {
      final data = await _kvStorage.get(key as String) as Map<String, dynamic>?;
      if (data != null) {
        events.add(data);
      }
    }
    return events;
  }
}
