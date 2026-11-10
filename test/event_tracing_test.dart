/// EventTracing Tests
///
/// Tests for EventTracing: startEventSpan, enrichWithTrace,
/// and extractTraceContext with and without a Tracer.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

void main() {
  group('EventTracing', () {
    group('with Tracer', () {
      late Tracer tracer;
      late InMemoryTraceSink traceSink;
      late EventTracing tracing;

      setUp(() {
        traceSink = InMemoryTraceSink();
        tracer = Tracer(sink: traceSink, traceId: 'test-trace-id');
        tracing = EventTracing(tracer: tracer);
      });

      test('startEventSpan returns a Span', () {
        final event = testOpsEvent(eventType: 'test.span');
        final span = tracing.startEventSpan(event);

        expect(span, isNotNull);
        expect(span!.name, contains('test.span'));
      });

      test('startEventSpan continues trace when parent context provided', () {
        final event = testOpsEvent(eventType: 'test.child');
        final span = tracing.startEventSpan(
          event,
          parentContext: {
            'trace-id': 'parent-trace',
            'span-id': 'parent-span',
          },
        );

        expect(span, isNotNull);
        expect(span!.traceId, equals('parent-trace'));
        expect(span.parentSpanId, equals('parent-span'));
      });

      test('startEventSpan uses meta traceId when no parent context', () {
        final event = OpsEvent(
          eventId: 'evt-1',
          eventType: 'test.meta',
          correlationId: 'corr-1',
          runId: 'run-1',
          workspaceId: 'ws-1',
          timestamp: DateTime(2024, 1, 1),
          payload: {},
          meta: const OpsEventMeta(
            source: 'test',
            traceId: 'meta-trace',
            spanId: 'meta-span',
          ),
        );

        final span = tracing.startEventSpan(event);

        expect(span, isNotNull);
        expect(span!.traceId, equals('meta-trace'));
        expect(span.parentSpanId, equals('meta-span'));
      });
    });

    group('without Tracer', () {
      late EventTracing tracing;

      setUp(() {
        tracing = EventTracing();
      });

      test('startEventSpan returns null', () {
        final event = testOpsEvent(eventType: 'test.no.tracer');
        final span = tracing.startEventSpan(event);

        expect(span, isNull);
      });
    });

    group('enrichWithTrace', () {
      test('adds trace info from span to event meta', () {
        final traceSink = InMemoryTraceSink();
        final tracer = Tracer(sink: traceSink, traceId: 'enrich-trace');
        final tracing = EventTracing(tracer: tracer);

        final event = testOpsEvent(eventType: 'test.enrich');
        final span = tracer.startSpan('test-span');

        final enriched = tracing.enrichWithTrace(event, span: span);

        expect(enriched.meta.traceId, equals(span.traceId));
        expect(enriched.meta.spanId, equals(span.spanId));
      });

      test('adds trace info from traceContext map', () {
        final tracing = EventTracing();
        final event = testOpsEvent(eventType: 'test.context');

        final enriched = tracing.enrichWithTrace(
          event,
          traceContext: {
            'trace-id': 'ctx-trace',
            'span-id': 'ctx-span',
          },
        );

        expect(enriched.meta.traceId, equals('ctx-trace'));
        expect(enriched.meta.spanId, equals('ctx-span'));
      });

      test('generates trace ID when none available', () {
        final tracing = EventTracing();
        final event = testOpsEvent(eventType: 'test.generated');

        final enriched = tracing.enrichWithTrace(event);

        // Should auto-generate trace and span IDs
        expect(enriched.meta.traceId, isNotNull);
        expect(enriched.meta.spanId, isNotNull);
      });

      test('preserves existing meta traceId when no span or context', () {
        final tracing = EventTracing();
        final event = OpsEvent(
          eventId: 'evt-1',
          eventType: 'test.preserve',
          correlationId: 'corr-1',
          runId: 'run-1',
          workspaceId: 'ws-1',
          timestamp: DateTime(2024, 1, 1),
          payload: {},
          meta: const OpsEventMeta(
            source: 'test',
            traceId: 'existing-trace',
            spanId: 'existing-span',
          ),
        );

        final enriched = tracing.enrichWithTrace(event);

        expect(enriched.meta.traceId, equals('existing-trace'));
        expect(enriched.meta.spanId, equals('existing-span'));
      });
    });

    group('extractTraceContext', () {
      test('returns trace headers from event with trace context', () {
        final tracing = EventTracing();
        final event = OpsEvent(
          eventId: 'evt-1',
          eventType: 'test.extract',
          correlationId: 'corr-1',
          runId: 'run-1',
          workspaceId: 'ws-1',
          timestamp: DateTime(2024, 1, 1),
          payload: {},
          meta: const OpsEventMeta(
            source: 'test',
            traceId: 'extract-trace',
            spanId: 'extract-span',
          ),
        );

        final context = tracing.extractTraceContext(event);

        expect(context, isNotNull);
        expect(context!['trace-id'], equals('extract-trace'));
        expect(context['span-id'], equals('extract-span'));
      });

      test('returns null when event has no trace context', () {
        final tracing = EventTracing();
        final event = testOpsEvent(eventType: 'test.no.trace');

        final context = tracing.extractTraceContext(event);

        expect(context, isNull);
      });

      test('returns trace-id only when spanId is null', () {
        final tracing = EventTracing();
        final event = OpsEvent(
          eventId: 'evt-1',
          eventType: 'test.partial',
          correlationId: 'corr-1',
          runId: 'run-1',
          workspaceId: 'ws-1',
          timestamp: DateTime(2024, 1, 1),
          payload: {},
          meta: const OpsEventMeta(
            source: 'test',
            traceId: 'trace-only',
          ),
        );

        final context = tracing.extractTraceContext(event);

        expect(context, isNotNull);
        expect(context!['trace-id'], equals('trace-only'));
        expect(context.containsKey('span-id'), isFalse);
      });
    });
  });
}
