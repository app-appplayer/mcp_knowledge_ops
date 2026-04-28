/// EventPublisher - Publishes OpsEvents through the EventPort.
///
/// Provides enrichment, batch publishing, and acknowledged delivery
/// with configurable retry logic on top of the base EventPort.
library;

import 'dart:async';

import '../ports/ops_port.dart';
import '../observability/logger.dart';
import '../observability/audit_recorder.dart';
import 'ops_event.dart';

/// Abstract event publisher contract.
abstract class EventPublisher {
  /// Publish a single event.
  Future<void> publish(OpsEvent event);

  /// Publish a batch of events in order.
  Future<void> publishBatch(List<OpsEvent> events);

  /// Publish with guaranteed delivery, retrying on failure.
  Future<void> publishWithAck(
    OpsEvent event, {
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
  });
}

/// Concrete publisher that enriches events with trace context
/// and publishes through the [EventPort].
class OpsEventPublisher implements EventPublisher {
  /// The underlying event port for transport.
  final EventPort _eventPort;

  /// Logger for publish operations.
  final ExecutionLogger _logger;

  /// Default source tag applied when meta.source is not set.
  final String _defaultSource;

  /// Optional trace ID injector for enrichment.
  final String Function()? _traceIdProvider;

  /// Optional span ID injector for enrichment.
  final String Function()? _spanIdProvider;

  /// Optional audit recorder for recording events to the audit trail.
  final AuditRecorder? _auditRecorder;

  OpsEventPublisher({
    required EventPort eventPort,
    required ExecutionLogger logger,
    String defaultSource = 'mcp_knowledge_ops',
    String Function()? traceIdProvider,
    String Function()? spanIdProvider,
    AuditRecorder? auditRecorder,
  })  : _eventPort = eventPort,
        _logger = logger.child('event_publisher'),
        _defaultSource = defaultSource,
        _traceIdProvider = traceIdProvider,
        _spanIdProvider = spanIdProvider,
        _auditRecorder = auditRecorder;

  @override
  Future<void> publish(OpsEvent event) async {
    final enriched = _enrich(event);

    // Record to audit trail before publishing
    if (_auditRecorder != null) {
      await _auditRecorder!.record(AuditEvent.create(
        actor: AuditActor(
          type: ActorType.system,
          id: enriched.meta.source,
        ),
        action: enriched.eventType,
        resource: AuditResource(
          type: 'event',
          id: enriched.eventId,
        ),
        outcome: AuditOutcome.success,
        context: AuditContext(
          workspaceId: enriched.workspaceId,
          traceId: enriched.meta.traceId,
          requestId: enriched.correlationId,
        ),
      ));
    }

    final portEvent = enriched.toPortEvent();

    _logger.debug('Publishing event', {
      'eventId': enriched.eventId,
      'eventType': enriched.eventType,
      'correlationId': enriched.correlationId,
    });

    await _eventPort.publish(portEvent);

    _logger.trace('Event published', {
      'eventId': enriched.eventId,
      'eventType': enriched.eventType,
    });
  }

  @override
  Future<void> publishBatch(List<OpsEvent> events) async {
    if (events.isEmpty) return;

    _logger.debug('Publishing event batch', {
      'count': events.length,
      'types': events.map((e) => e.eventType).toSet().toList(),
    });

    for (final event in events) {
      await publish(event);
    }

    _logger.debug('Event batch published', {
      'count': events.length,
    });
  }

  @override
  Future<void> publishWithAck(
    OpsEvent event, {
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
  }) async {
    var attempt = 0;
    Object? lastError;

    while (attempt < maxRetries) {
      attempt++;
      try {
        await publish(event).timeout(timeout);
        return;
      } on TimeoutException catch (e) {
        lastError = e;
        _logger.warn('Publish timed out, retrying', {
          'eventId': event.eventId,
          'attempt': attempt,
          'maxRetries': maxRetries,
          'timeoutMs': timeout.inMilliseconds,
        });
      } catch (e) {
        lastError = e;
        _logger.warn('Publish failed, retrying', {
          'eventId': event.eventId,
          'attempt': attempt,
          'maxRetries': maxRetries,
          'error': e.toString(),
        });
      }

      // Exponential backoff between retries.
      if (attempt < maxRetries) {
        final delayMs = 100 * (1 << (attempt - 1));
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }

    _logger.error(
      'Publish failed after all retries',
      error: lastError,
      context: {'stackTrace': StackTrace.current.toString()},
    );

    throw lastError ?? StateError('Publish failed after $maxRetries retries');
  }

  /// Enrich the event with trace context if not already present.
  OpsEvent _enrich(OpsEvent event) {
    var meta = event.meta;
    var changed = false;

    // Apply default source if empty.
    if (meta.source.isEmpty) {
      meta = meta.copyWith(source: _defaultSource);
      changed = true;
    }

    // Inject trace ID if provider is available and not already set.
    if (meta.traceId == null && _traceIdProvider != null) {
      meta = meta.copyWith(traceId: _traceIdProvider!());
      changed = true;
    }

    // Inject span ID if provider is available and not already set.
    if (meta.spanId == null && _spanIdProvider != null) {
      meta = meta.copyWith(spanId: _spanIdProvider!());
      changed = true;
    }

    if (!changed) return event;
    return event.copyWith(meta: meta);
  }
}
