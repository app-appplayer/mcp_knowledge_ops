/// Event Tracing - Distributed tracing integration for events.
///
/// Provides trace context generation, propagation, and enrichment
/// for events flowing through the knowledge ops event system.
library;

import '../observability/tracer.dart';
import 'ops_event.dart';

/// Distributed tracing integration for events.
///
/// Generates and propagates trace context headers for correlation
/// of events across distributed components. Accepts an optional
/// [Tracer] dependency for integration with the observability layer.
class EventTracing {
  /// Optional tracer for creating spans.
  final Tracer? _tracer;

  EventTracing({Tracer? tracer}) : _tracer = tracer;

  /// Start a new trace span for an event.
  ///
  /// If a [Tracer] is configured, creates a real [Span]. Otherwise
  /// returns null. Uses [continueTrace] if parent context is available.
  Span? startEventSpan(
    OpsEvent event, {
    Map<String, String>? parentContext,
  }) {
    if (_tracer == null) return null;

    final parentTraceId = parentContext?['trace-id'] ?? event.meta.traceId;
    final parentSpanId = parentContext?['span-id'] ?? event.meta.spanId;

    if (parentTraceId != null) {
      return _tracer!.continueTrace(
        parentTraceId,
        parentSpanId: parentSpanId,
        name: 'event.${event.eventType}',
      );
    }

    return _tracer!.startSpan('event.${event.eventType}');
  }

  /// Enrich an event with trace context from the current span.
  ///
  /// Returns a new [OpsEvent] with trace IDs populated from the span
  /// or from the existing trace context headers.
  OpsEvent enrichWithTrace(
    OpsEvent event, {
    Span? span,
    Map<String, String>? traceContext,
  }) {
    final traceId = span?.traceId ??
        traceContext?['trace-id'] ??
        event.meta.traceId ??
        _generateTraceId();
    final spanId = span?.spanId ??
        traceContext?['span-id'] ??
        event.meta.spanId ??
        _generateSpanId();

    return event.copyWith(
      meta: event.meta.copyWith(
        traceId: traceId,
        spanId: spanId,
      ),
    );
  }

  /// Extract trace context from event metadata as W3C trace headers.
  Map<String, String>? extractTraceContext(OpsEvent event) {
    if (event.meta.traceId == null) return null;
    return {
      'trace-id': event.meta.traceId!,
      if (event.meta.spanId != null) 'span-id': event.meta.spanId!,
    };
  }

  /// Generate a trace ID based on current microsecond timestamp.
  String _generateTraceId() {
    return DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  }

  /// Generate a span ID based on current microsecond timestamp.
  String _generateSpanId() {
    return DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  }
}
