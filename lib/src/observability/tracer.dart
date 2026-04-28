/// Tracer - Distributed tracing for observability.
///
/// Provides tracing for pipeline and workflow execution.
library;

/// Tracer for distributed tracing.
class Tracer {
  /// Trace sink.
  final TraceSink _sink;

  /// Current trace ID.
  final String? _traceId;

  /// Current span stack.
  final List<Span> _spanStack = [];

  Tracer({
    TraceSink? sink,
    String? traceId,
  })  : _sink = sink ?? InMemoryTraceSink(),
        _traceId = traceId;

  /// Get current trace ID.
  String? get traceId => _traceId;

  /// Get current span ID.
  String? get currentSpanId => _spanStack.isNotEmpty ? _spanStack.last.spanId : null;

  /// Start a new root span.
  Span startSpan(String name, {Map<String, dynamic>? attributes}) {
    final span = Span(
      traceId: _traceId ?? _generateId('trace'),
      spanId: _generateId('span'),
      parentSpanId: currentSpanId,
      name: name,
      startTime: DateTime.now(),
      attributes: attributes ?? {},
      sink: _sink,
    );

    _spanStack.add(span);
    return span;
  }

  /// Continue an existing trace from a remote context.
  ///
  /// Creates a new span linked to the given [traceId] and optionally
  /// parented under [parentSpanId]. Used for distributed trace propagation.
  Span continueTrace(
    String traceId, {
    String? parentSpanId,
    String name = 'continued',
    Map<String, dynamic>? attributes,
  }) {
    final span = Span(
      traceId: traceId,
      spanId: _generateId('span'),
      parentSpanId: parentSpanId,
      name: name,
      startTime: DateTime.now(),
      attributes: attributes ?? {},
      sink: _sink,
    );

    _spanStack.add(span);
    return span;
  }

  /// Start a child span of current span.
  @Deprecated('Use Span.startChild() instead. startChild moved to Span per spec.')
  Span startChild(String name, {Map<String, dynamic>? attributes}) {
    return startSpan(name, attributes: attributes);
  }

  /// Get current span.
  Span? get currentSpan => _spanStack.isNotEmpty ? _spanStack.last : null;

  /// End current span.
  void endCurrentSpan() {
    if (_spanStack.isNotEmpty) {
      final span = _spanStack.removeLast();
      span.end();
    }
  }

  String _generateId(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp.hashCode.abs() % 10000;
    return '${prefix}_${timestamp}_$random';
  }
}

/// Span status.
enum SpanStatus {
  unset,
  ok,
  error,
}

/// Trace span.
class Span {
  /// Trace ID.
  final String traceId;

  /// Span ID.
  final String spanId;

  /// Parent span ID.
  final String? parentSpanId;

  /// Span name.
  final String name;

  /// Start time.
  final DateTime startTime;

  /// End time.
  DateTime? _endTime;

  /// Span status.
  SpanStatus _status = SpanStatus.unset;

  /// Span attributes.
  final Map<String, dynamic> attributes;

  /// Events recorded in span.
  final List<SpanEvent> _events = [];

  /// Trace sink.
  final TraceSink _sink;

  Span({
    required this.traceId,
    required this.spanId,
    this.parentSpanId,
    required this.name,
    required this.startTime,
    required this.attributes,
    required TraceSink sink,
  }) : _sink = sink;

  /// Get end time.
  DateTime? get endTime => _endTime;

  /// Get span status.
  SpanStatus get status => _status;

  /// Get events.
  List<SpanEvent> get events => List.unmodifiable(_events);

  /// Get duration.
  Duration? get duration =>
      _endTime != null ? _endTime!.difference(startTime) : null;

  /// Set span status.
  void setStatus(SpanStatus status) {
    _status = status;
  }

  /// Set attribute.
  void setAttribute(String key, dynamic value) {
    attributes[key] = value;
  }

  /// Add event.
  void addEvent(String name, {Map<String, dynamic>? attributes}) {
    _events.add(SpanEvent(
      name: name,
      timestamp: DateTime.now(),
      attributes: attributes ?? {},
    ));
  }

  /// Start a child span under this span.
  Span startChild(String childName, {Map<String, dynamic>? attributes}) {
    return Span(
      traceId: traceId,
      spanId: _generateSpanId(),
      parentSpanId: spanId,
      name: childName,
      startTime: DateTime.now(),
      attributes: attributes ?? {},
      sink: _sink,
    );
  }

  /// Generate a unique span ID.
  static String _generateSpanId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp.hashCode.abs() % 10000;
    return 'span_${timestamp}_$random';
  }

  /// Record error.
  void recordError(Object error, [StackTrace? stackTrace]) {
    addEvent('exception', attributes: {
      'exception.type': error.runtimeType.toString(),
      'exception.message': error.toString(),
      if (stackTrace != null) 'exception.stacktrace': stackTrace.toString(),
    });
  }

  /// End span.
  void end() {
    if (_endTime != null) return;

    _endTime = DateTime.now();
    _sink.record(toSpanData());
  }

  /// Convert to span data.
  SpanData toSpanData() {
    return SpanData(
      traceId: traceId,
      spanId: spanId,
      parentSpanId: parentSpanId,
      name: name,
      startTime: startTime,
      endTime: _endTime,
      status: _status,
      attributes: Map.from(attributes),
      events: List.from(_events),
    );
  }
}

/// Span event.
class SpanEvent {
  /// Event name.
  final String name;

  /// Event timestamp.
  final DateTime timestamp;

  /// Event attributes.
  final Map<String, dynamic> attributes;

  const SpanEvent({
    required this.name,
    required this.timestamp,
    this.attributes = const {},
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'name': name,
        'timestamp': timestamp.toIso8601String(),
        if (attributes.isNotEmpty) 'attributes': attributes,
      };
}

/// Completed span data.
class SpanData {
  /// Trace ID.
  final String traceId;

  /// Span ID.
  final String spanId;

  /// Parent span ID.
  final String? parentSpanId;

  /// Span name.
  final String name;

  /// Start time.
  final DateTime startTime;

  /// End time.
  final DateTime? endTime;

  /// Span status.
  final SpanStatus status;

  /// Span attributes.
  final Map<String, dynamic> attributes;

  /// Events.
  final List<SpanEvent> events;

  const SpanData({
    required this.traceId,
    required this.spanId,
    this.parentSpanId,
    required this.name,
    required this.startTime,
    this.endTime,
    this.status = SpanStatus.unset,
    this.attributes = const {},
    this.events = const [],
  });

  /// Get duration.
  Duration? get duration =>
      endTime != null ? endTime!.difference(startTime) : null;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'traceId': traceId,
        'spanId': spanId,
        if (parentSpanId != null) 'parentSpanId': parentSpanId,
        'name': name,
        'startTime': startTime.toIso8601String(),
        if (endTime != null) 'endTime': endTime!.toIso8601String(),
        'status': status.name,
        if (attributes.isNotEmpty) 'attributes': attributes,
        if (events.isNotEmpty) 'events': events.map((e) => e.toJson()).toList(),
      };
}

/// Trace context for propagating distributed tracing information.
///
/// Carries trace identity, parent span relationship, attributes,
/// and baggage items for cross-service propagation.
class TraceContext {
  /// Trace ID linking all spans in a distributed trace.
  final String traceId;

  /// Parent span ID for establishing parent-child relationships.
  final String? parentSpanId;

  /// Attributes attached to the trace context.
  final Map<String, dynamic> attributes;

  /// Baggage items propagated across service boundaries.
  final Map<String, String> baggage;

  const TraceContext({
    required this.traceId,
    this.parentSpanId,
    this.attributes = const {},
    this.baggage = const {},
  });

  /// Create a child context under a new parent span.
  TraceContext withParentSpan(String spanId) {
    return TraceContext(
      traceId: traceId,
      parentSpanId: spanId,
      attributes: attributes,
      baggage: baggage,
    );
  }

  /// Create a context with additional baggage items.
  TraceContext withBaggage(Map<String, String> additionalBaggage) {
    return TraceContext(
      traceId: traceId,
      parentSpanId: parentSpanId,
      attributes: attributes,
      baggage: {...baggage, ...additionalBaggage},
    );
  }

  /// Serialize to W3C trace context headers.
  Map<String, String> toHeaders() => {
        'trace-id': traceId,
        if (parentSpanId != null) 'span-id': parentSpanId!,
        for (final entry in baggage.entries) 'baggage-${entry.key}': entry.value,
      };

  /// Deserialize from W3C trace context headers.
  factory TraceContext.fromHeaders(Map<String, String> headers) {
    final baggage = <String, String>{};
    for (final entry in headers.entries) {
      if (entry.key.startsWith('baggage-')) {
        baggage[entry.key.substring(8)] = entry.value;
      }
    }
    return TraceContext(
      traceId: headers['trace-id'] ?? '',
      parentSpanId: headers['span-id'],
      baggage: baggage,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'traceId': traceId,
        if (parentSpanId != null) 'parentSpanId': parentSpanId,
        if (attributes.isNotEmpty) 'attributes': attributes,
        if (baggage.isNotEmpty) 'baggage': baggage,
      };
}

/// Trace sink interface.
abstract class TraceSink {
  /// Record span data.
  void record(SpanData span);

  /// Flush buffered spans.
  Future<void> flush();

  /// Close sink.
  Future<void> close();
}

/// In-memory trace sink for testing.
class InMemoryTraceSink implements TraceSink {
  final List<SpanData> _spans = [];

  /// Get all spans.
  List<SpanData> get spans => List.unmodifiable(_spans);

  /// Get spans by trace ID.
  List<SpanData> spansByTrace(String traceId) {
    return _spans.where((s) => s.traceId == traceId).toList();
  }

  /// Get span by ID.
  SpanData? spanById(String spanId) {
    return _spans.where((s) => s.spanId == spanId).firstOrNull;
  }

  /// Clear spans.
  void clear() => _spans.clear();

  @override
  void record(SpanData span) {
    _spans.add(span);
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}
