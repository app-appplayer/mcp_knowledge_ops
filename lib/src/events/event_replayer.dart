/// Event Replayer - Replays events for execution recovery and debugging.
///
/// Reads persisted events from KvStoragePort via [EventPersister] key
/// conventions and replays them through the [EventRouter] or in dry-run mode.
library;

import 'ops_event.dart';
import 'event_store.dart';
import 'event_router.dart';
import '../observability/logger.dart';
import '../ports/ops_port.dart';

/// Result of replaying a single event.
class ReplayEventResult {
  /// Event ID that was replayed.
  final String eventId;

  /// Event type of the replayed event.
  final String eventType;

  /// Whether the replay succeeded.
  final bool success;

  /// Error message if the replay failed.
  final String? error;

  const ReplayEventResult({
    required this.eventId,
    required this.eventType,
    required this.success,
    this.error,
  });

  /// Whether this result represents a successful replay.
  bool get isSuccess => success;

  /// Whether this result represents a failed replay.
  bool get isFailed => !success;

  /// Create a success result.
  factory ReplayEventResult.successful(OpsEvent event) {
    return ReplayEventResult(
      eventId: event.eventId,
      eventType: event.eventType,
      success: true,
    );
  }

  /// Create a simulated (dry-run) result.
  factory ReplayEventResult.simulated(OpsEvent event) {
    return ReplayEventResult(
      eventId: event.eventId,
      eventType: event.eventType,
      success: true,
    );
  }

  /// Create a failure result.
  factory ReplayEventResult.failed(OpsEvent event, String error) {
    return ReplayEventResult(
      eventId: event.eventId,
      eventType: event.eventType,
      success: false,
      error: error,
    );
  }
}

/// Aggregate result of replaying events for an execution.
class ReplayResult {
  /// Execution identifier that was replayed.
  final String executionId;

  /// Total number of events in the stream.
  final int totalEvents;

  /// Number of events that were replayed.
  final int replayedEvents;

  /// Number of events that were skipped.
  final int skippedEvents;

  /// Individual event replay results.
  final List<ReplayEventResult> results;

  /// Total duration of the replay operation.
  final Duration duration;

  const ReplayResult({
    required this.executionId,
    required this.totalEvents,
    required this.replayedEvents,
    required this.skippedEvents,
    required this.results,
    required this.duration,
  });
}

/// Replays persisted events for execution recovery and debugging.
///
/// Events are read from [KvStoragePort] using the key conventions
/// defined in [EventStorageKeys] and [EventStreams], then routed
/// through the [EventRouter] (or simulated in dry-run mode).
class EventReplayer {
  /// Key-value storage for reading persisted events.
  final KvStoragePort _kvStorage;

  /// Event router for dispatching replayed events.
  final EventRouter _router;

  /// Logger for replay operations.
  final ExecutionLogger _logger;

  EventReplayer({
    required KvStoragePort kvStorage,
    required EventRouter router,
    required ExecutionLogger logger,
  })  : _kvStorage = kvStorage,
        _router = router,
        _logger = logger.child('event_replayer');

  /// Replay all events for a specific execution.
  ///
  /// Reads events from the execution stream in order and routes them
  /// through the [EventRouter]. Use [fromTimestamp] and [toTimestamp]
  /// to filter by time range. Use [fromPosition] to start replay from
  /// a specific stream position (1-based). Set [dryRun] to true to
  /// simulate replay without invoking handlers.
  Future<ReplayResult> replayExecution(
    String executionId, {
    int? fromPosition,
    DateTime? fromTimestamp,
    DateTime? toTimestamp,
    bool dryRun = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    final stream = EventStreams.execution(executionId);
    final posKey = EventStorageKeys.streamPosition(stream);
    final maxPos = (await _kvStorage.get(posKey) as int?) ?? 0;
    final startPos = (fromPosition != null && fromPosition > 0)
        ? fromPosition
        : 1;

    _logger.info('Starting event replay', {
      'executionId': executionId,
      'totalPositions': maxPos,
      'startPosition': startPos,
      'dryRun': dryRun,
      if (fromTimestamp != null)
        'fromTimestamp': fromTimestamp.toIso8601String(),
      if (toTimestamp != null) 'toTimestamp': toTimestamp.toIso8601String(),
    });

    final results = <ReplayEventResult>[];
    var skipped = 0;

    for (var pos = startPos; pos <= maxPos; pos++) {
      final eventKey = EventStorageKeys.eventLog(stream, pos);
      final data = await _kvStorage.get(eventKey) as Map<String, dynamic>?;
      if (data == null) {
        skipped++;
        continue;
      }

      final event = OpsEvent.fromJson(data);

      // Apply time range filter if specified.
      if (fromTimestamp != null && event.timestamp.isBefore(fromTimestamp)) {
        skipped++;
        continue;
      }
      if (toTimestamp != null && event.timestamp.isAfter(toTimestamp)) {
        skipped++;
        continue;
      }

      if (dryRun) {
        results.add(ReplayEventResult.simulated(event));
      } else {
        try {
          await _router.route(event);
          results.add(ReplayEventResult.successful(event));
        } catch (e) {
          results.add(ReplayEventResult.failed(event, e.toString()));
        }
      }
    }

    stopwatch.stop();

    _logger.info('Event replay completed', {
      'executionId': executionId,
      'totalEvents': maxPos,
      'replayed': results.length,
      'skipped': skipped,
      'successful': results.where((r) => r.isSuccess).length,
      'failed': results.where((r) => r.isFailed).length,
      'durationMs': stopwatch.elapsedMilliseconds,
    });

    return ReplayResult(
      executionId: executionId,
      totalEvents: maxPos,
      replayedEvents: results.length,
      skippedEvents: skipped,
      results: results,
      duration: stopwatch.elapsed,
    );
  }
}
