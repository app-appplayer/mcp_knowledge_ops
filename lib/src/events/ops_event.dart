/// OpsEvent - Rich event model for knowledge ops event architecture.
///
/// Extends the base PortEvent with correlation tracking, versioning,
/// metadata, and full serialization support for event sourcing.
library;

import '../ports/ops_port.dart';

/// Metadata attached to every ops event for tracing and provenance.
class OpsEventMeta {
  /// Source system or component that produced the event.
  final String source;

  /// Distributed trace ID for cross-service correlation.
  final String? traceId;

  /// Span ID within the trace for fine-grained correlation.
  final String? spanId;

  const OpsEventMeta({
    required this.source,
    this.traceId,
    this.spanId,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'source': source,
        if (traceId != null) 'traceId': traceId,
        if (spanId != null) 'spanId': spanId,
      };

  /// Deserialize from JSON.
  factory OpsEventMeta.fromJson(Map<String, dynamic> json) {
    return OpsEventMeta(
      source: json['source'] as String,
      traceId: json['traceId'] as String?,
      spanId: json['spanId'] as String?,
    );
  }

  /// Create a copy with updated fields.
  OpsEventMeta copyWith({
    String? source,
    String? traceId,
    String? spanId,
  }) {
    return OpsEventMeta(
      source: source ?? this.source,
      traceId: traceId ?? this.traceId,
      spanId: spanId ?? this.spanId,
    );
  }

  @override
  String toString() => 'OpsEventMeta(source: $source, '
      'traceId: $traceId, spanId: $spanId)';
}

/// Rich event model for knowledge ops.
///
/// Carries full correlation context, versioning, and metadata
/// beyond what the base [PortEvent] provides. Supports bidirectional
/// conversion to/from [PortEvent] for port-level transport.
class OpsEvent {
  /// Unique event identifier (UUID-like).
  final String eventId;

  /// Fully qualified event type (e.g. 'ops.pipeline.started').
  final String eventType;

  /// Event schema version for forward compatibility.
  final String version;

  /// Correlation ID linking related events across a workflow.
  final String correlationId;

  /// Causation ID pointing to the event that caused this one.
  final String? causationId;

  /// Execution run ID.
  final String runId;

  /// Workspace scope.
  final String workspaceId;

  /// Event timestamp.
  final DateTime timestamp;

  /// Event payload data.
  final Map<String, dynamic> payload;

  /// Event metadata for tracing and provenance.
  final OpsEventMeta meta;

  const OpsEvent({
    required this.eventId,
    required this.eventType,
    this.version = '1.0',
    required this.correlationId,
    this.causationId,
    required this.runId,
    required this.workspaceId,
    required this.timestamp,
    required this.payload,
    required this.meta,
  });

  /// Convert this ops event to a [PortEvent] for transport via [EventPort].
  PortEvent toPortEvent() {
    return PortEvent(
      type: eventType,
      payload: {
        'eventId': eventId,
        'version': version,
        'correlationId': correlationId,
        if (causationId != null) 'causationId': causationId,
        'runId': runId,
        'workspaceId': workspaceId,
        'meta': meta.toJson(),
        'payload': payload,
      },
      timestamp: timestamp,
      source: meta.source,
    );
  }

  /// Reconstruct an [OpsEvent] from a [PortEvent].
  ///
  /// Expects the port event payload to contain the enriched fields
  /// written by [toPortEvent].
  factory OpsEvent.fromPortEvent(PortEvent portEvent) {
    final p = portEvent.payload;
    final metaJson = p['meta'] as Map<String, dynamic>?;

    return OpsEvent(
      eventId: p['eventId'] as String? ?? generateEventId(),
      eventType: portEvent.type,
      version: p['version'] as String? ?? '1.0',
      correlationId: p['correlationId'] as String? ?? generateEventId(),
      causationId: p['causationId'] as String?,
      runId: p['runId'] as String? ?? '',
      workspaceId: p['workspaceId'] as String? ?? '',
      timestamp: portEvent.timestamp,
      payload: (p['payload'] ?? p['data']) as Map<String, dynamic>? ?? Map<String, dynamic>.from(p),
      meta: metaJson != null
          ? OpsEventMeta.fromJson(metaJson)
          : OpsEventMeta(source: portEvent.source ?? 'unknown'),
    );
  }

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'eventType': eventType,
        'version': version,
        'correlationId': correlationId,
        if (causationId != null) 'causationId': causationId,
        'runId': runId,
        'workspaceId': workspaceId,
        'timestamp': timestamp.toIso8601String(),
        'payload': payload,
        'meta': meta.toJson(),
      };

  /// Deserialize from JSON map.
  factory OpsEvent.fromJson(Map<String, dynamic> json) {
    return OpsEvent(
      eventId: json['eventId'] as String,
      eventType: json['eventType'] as String,
      version: json['version'] as String? ?? '1.0',
      correlationId: json['correlationId'] as String,
      causationId: json['causationId'] as String?,
      runId: json['runId'] as String,
      workspaceId: json['workspaceId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      payload: json['payload'] as Map<String, dynamic>,
      meta: OpsEventMeta.fromJson(json['meta'] as Map<String, dynamic>),
    );
  }

  /// Create a copy with updated fields.
  OpsEvent copyWith({
    String? eventId,
    String? eventType,
    String? version,
    String? correlationId,
    String? causationId,
    String? runId,
    String? workspaceId,
    DateTime? timestamp,
    Map<String, dynamic>? payload,
    OpsEventMeta? meta,
  }) {
    return OpsEvent(
      eventId: eventId ?? this.eventId,
      eventType: eventType ?? this.eventType,
      version: version ?? this.version,
      correlationId: correlationId ?? this.correlationId,
      causationId: causationId ?? this.causationId,
      runId: runId ?? this.runId,
      workspaceId: workspaceId ?? this.workspaceId,
      timestamp: timestamp ?? this.timestamp,
      payload: payload ?? this.payload,
      meta: meta ?? this.meta,
    );
  }

  /// Generate a unique event identifier.
  static String generateEventId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    // A process-wide counter keeps ids made in the same clock tick apart;
    // the web clock only ticks every millisecond.
    _eventIdSequence = (_eventIdSequence + 1) & 0xFFFFFF;
    return 'evt_${ts.toRadixString(16)}_'
        '${_eventIdSequence.toRadixString(16).padLeft(6, '0')}';
  }

  static int _eventIdSequence = 0;

  /// Convenience factory to create a new event with auto-generated ID and timestamp.
  factory OpsEvent.create({
    required String eventType,
    String version = '1.0',
    required String correlationId,
    String? causationId,
    required String runId,
    required String workspaceId,
    required Map<String, dynamic> payload,
    required OpsEventMeta meta,
  }) {
    return OpsEvent(
      eventId: generateEventId(),
      eventType: eventType,
      version: version,
      correlationId: correlationId,
      causationId: causationId,
      runId: runId,
      workspaceId: workspaceId,
      timestamp: DateTime.now(),
      payload: payload,
      meta: meta,
    );
  }

  @override
  String toString() => 'OpsEvent(id: $eventId, type: $eventType, '
      'correlationId: $correlationId, runId: $runId)';
}
