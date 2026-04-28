/// Tracer Tests - Tests for Tracer, Span, TraceContext, and related classes.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // Tracer
  // ═══════════════════════════════════════════════════════════════

  group('Tracer', () {
    late InMemoryTraceSink sink;
    late Tracer tracer;

    setUp(() {
      sink = InMemoryTraceSink();
      tracer = Tracer(sink: sink);
    });

    test('traceId is null when not provided', () {
      expect(tracer.traceId, isNull);
    });

    test('traceId is set when provided', () {
      final tracerWithId = Tracer(sink: sink, traceId: 'my-trace');
      expect(tracerWithId.traceId, equals('my-trace'));
    });

    test('startSpan creates span with correct name', () {
      final span = tracer.startSpan('test-operation');

      expect(span.name, equals('test-operation'));
      expect(span.traceId, isNotEmpty);
      expect(span.spanId, isNotEmpty);
      expect(span.startTime, isNotNull);
    });

    test('startSpan uses provided traceId', () {
      final tracerWithId = Tracer(sink: sink, traceId: 'fixed-trace');
      final span = tracerWithId.startSpan('op');

      expect(span.traceId, equals('fixed-trace'));
    });

    test('startSpan generates traceId when not provided', () {
      final span = tracer.startSpan('op');

      expect(span.traceId, isNotEmpty);
      expect(span.traceId, startsWith('trace_'));
    });

    test('startSpan with attributes', () {
      final span = tracer.startSpan('op', attributes: {'key': 'value'});

      expect(span.attributes['key'], equals('value'));
    });

    test('currentSpanId returns null when no spans', () {
      expect(tracer.currentSpanId, isNull);
    });

    test('currentSpanId returns latest span ID', () {
      final span = tracer.startSpan('op');
      expect(tracer.currentSpanId, equals(span.spanId));
    });

    test('currentSpan returns null when no spans', () {
      expect(tracer.currentSpan, isNull);
    });

    test('currentSpan returns latest span', () {
      final span = tracer.startSpan('op');
      expect(tracer.currentSpan, same(span));
    });

    test('endCurrentSpan ends and records span', () {
      tracer.startSpan('op');
      tracer.endCurrentSpan();

      expect(tracer.currentSpan, isNull);
      expect(sink.spans.length, equals(1));
    });

    test('endCurrentSpan on empty stack does nothing', () {
      tracer.endCurrentSpan();
      expect(sink.spans, isEmpty);
    });

    test('nested spans set parentSpanId', () {
      final parent = tracer.startSpan('parent');
      final child = tracer.startSpan('child');

      expect(child.parentSpanId, equals(parent.spanId));
    });

    test('continueTrace() creates span with given traceId', () {
      final span = tracer.continueTrace(
        'external-trace-id',
        parentSpanId: 'external-span-id',
        name: 'continued-op',
        attributes: {'source': 'remote'},
      );

      expect(span.traceId, equals('external-trace-id'));
      expect(span.parentSpanId, equals('external-span-id'));
      expect(span.name, equals('continued-op'));
      expect(span.attributes['source'], equals('remote'));
    });

    test('continueTrace() with default name', () {
      final span = tracer.continueTrace('ext-trace');
      expect(span.name, equals('continued'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Span
  // ═══════════════════════════════════════════════════════════════

  group('Span', () {
    late InMemoryTraceSink sink;

    setUp(() {
      sink = InMemoryTraceSink();
    });

    Span createSpan({String name = 'test-span'}) {
      return Span(
        traceId: 'trace-1',
        spanId: 'span-1',
        name: name,
        startTime: DateTime.now(),
        attributes: {},
        sink: sink,
      );
    }

    test('end() sets endTime', () {
      final span = createSpan();
      expect(span.endTime, isNull);

      span.end();
      expect(span.endTime, isNotNull);
    });

    test('end() records to sink', () {
      final span = createSpan();
      span.end();

      expect(sink.spans.length, equals(1));
      expect(sink.spans.first.name, equals('test-span'));
    });

    test('end() is idempotent', () {
      final span = createSpan();
      span.end();
      span.end();

      // Should only record once
      expect(sink.spans.length, equals(1));
    });

    test('setStatus() changes span status', () {
      final span = createSpan();
      expect(span.status, equals(SpanStatus.unset));

      span.setStatus(SpanStatus.ok);
      expect(span.status, equals(SpanStatus.ok));

      span.setStatus(SpanStatus.error);
      expect(span.status, equals(SpanStatus.error));
    });

    test('setAttribute() adds attribute', () {
      final span = createSpan();
      span.setAttribute('http.method', 'GET');
      span.setAttribute('http.status_code', 200);

      expect(span.attributes['http.method'], equals('GET'));
      expect(span.attributes['http.status_code'], equals(200));
    });

    test('addEvent() records event', () {
      final span = createSpan();
      span.addEvent('request.start', attributes: {'url': '/api/data'});

      expect(span.events.length, equals(1));
      expect(span.events.first.name, equals('request.start'));
      expect(span.events.first.attributes['url'], equals('/api/data'));
      expect(span.events.first.timestamp, isNotNull);
    });

    test('addEvent() without attributes', () {
      final span = createSpan();
      span.addEvent('checkpoint');

      expect(span.events.length, equals(1));
      expect(span.events.first.attributes, isEmpty);
    });

    test('recordError() adds error event and info', () {
      final span = createSpan();
      final error = StateError('something went wrong');
      final stack = StackTrace.current;

      span.recordError(error, stack);

      expect(span.events.length, equals(1));
      final event = span.events.first;
      expect(event.name, equals('exception'));
      expect(event.attributes['exception.type'], equals('StateError'));
      expect(event.attributes['exception.message'],
          contains('something went wrong'));
      expect(event.attributes['exception.stacktrace'], isNotNull);
    });

    test('recordError() without stack trace', () {
      final span = createSpan();
      span.recordError(Exception('oops'));

      expect(span.events.length, equals(1));
      final event = span.events.first;
      expect(event.attributes.containsKey('exception.stacktrace'), isFalse);
    });

    test('startChild() creates child span with parent reference', () {
      final parent = createSpan();
      final child = parent.startChild('child-op', attributes: {'step': '1'});

      expect(child.traceId, equals(parent.traceId));
      expect(child.parentSpanId, equals(parent.spanId));
      expect(child.name, equals('child-op'));
      expect(child.attributes['step'], equals('1'));
    });

    test('duration is null before end', () {
      final span = createSpan();
      expect(span.duration, isNull);
    });

    test('duration is set after end', () {
      final span = createSpan();
      span.end();

      expect(span.duration, isNotNull);
      expect(span.duration!.inMicroseconds, greaterThanOrEqualTo(0));
    });

    test('toSpanData() converts correctly', () {
      final span = createSpan();
      span.setAttribute('key', 'value');
      span.addEvent('evt');
      span.setStatus(SpanStatus.ok);
      span.end();

      final data = span.toSpanData();
      expect(data.traceId, equals('trace-1'));
      expect(data.spanId, equals('span-1'));
      expect(data.name, equals('test-span'));
      expect(data.status, equals(SpanStatus.ok));
      expect(data.attributes['key'], equals('value'));
      expect(data.events.length, equals(1));
      expect(data.endTime, isNotNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // SpanStatus
  // ═══════════════════════════════════════════════════════════════

  group('SpanStatus', () {
    test('has all expected values', () {
      expect(SpanStatus.values.length, equals(3));
      expect(SpanStatus.values,
          containsAll([SpanStatus.unset, SpanStatus.ok, SpanStatus.error]));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // SpanData
  // ═══════════════════════════════════════════════════════════════

  group('SpanData', () {
    test('toJson() serializes correctly', () {
      final data = SpanData(
        traceId: 'trace-1',
        spanId: 'span-1',
        parentSpanId: 'parent-1',
        name: 'test-op',
        startTime: DateTime(2024, 1, 1),
        endTime: DateTime(2024, 1, 1, 0, 0, 1),
        status: SpanStatus.ok,
        attributes: {'key': 'value'},
        events: [
          SpanEvent(
            name: 'evt',
            timestamp: DateTime(2024, 1, 1),
            attributes: {'a': 'b'},
          ),
        ],
      );

      final json = data.toJson();
      expect(json['traceId'], equals('trace-1'));
      expect(json['spanId'], equals('span-1'));
      expect(json['parentSpanId'], equals('parent-1'));
      expect(json['name'], equals('test-op'));
      expect(json['status'], equals('ok'));
      expect(json['attributes'], equals({'key': 'value'}));
      expect((json['events'] as List).length, equals(1));
    });

    test('duration calculation', () {
      final data = SpanData(
        traceId: 'trace-1',
        spanId: 'span-1',
        name: 'test-op',
        startTime: DateTime(2024, 1, 1, 0, 0, 0),
        endTime: DateTime(2024, 1, 1, 0, 0, 5),
      );

      expect(data.duration, equals(const Duration(seconds: 5)));
    });

    test('duration is null without endTime', () {
      final data = SpanData(
        traceId: 'trace-1',
        spanId: 'span-1',
        name: 'test-op',
        startTime: DateTime(2024),
      );

      expect(data.duration, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // SpanEvent
  // ═══════════════════════════════════════════════════════════════

  group('SpanEvent', () {
    test('toJson() serializes correctly', () {
      final event = SpanEvent(
        name: 'test-event',
        timestamp: DateTime(2024, 1, 1),
        attributes: {'key': 'value'},
      );

      final json = event.toJson();
      expect(json['name'], equals('test-event'));
      expect(json['attributes'], equals({'key': 'value'}));
    });

    test('toJson() omits empty attributes', () {
      final event = SpanEvent(
        name: 'simple',
        timestamp: DateTime(2024, 1, 1),
      );

      final json = event.toJson();
      expect(json.containsKey('attributes'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // TraceContext
  // ═══════════════════════════════════════════════════════════════

  group('TraceContext', () {
    test('basic creation', () {
      const ctx = TraceContext(
        traceId: 'trace-1',
        parentSpanId: 'span-1',
        attributes: {'key': 'value'},
        baggage: {'user': 'test'},
      );

      expect(ctx.traceId, equals('trace-1'));
      expect(ctx.parentSpanId, equals('span-1'));
      expect(ctx.attributes['key'], equals('value'));
      expect(ctx.baggage['user'], equals('test'));
    });

    test('withParentSpan() creates new context with parent', () {
      const ctx = TraceContext(traceId: 'trace-1');
      final child = ctx.withParentSpan('new-span');

      expect(child.traceId, equals('trace-1'));
      expect(child.parentSpanId, equals('new-span'));
    });

    test('withBaggage() adds baggage items', () {
      const ctx = TraceContext(
        traceId: 'trace-1',
        baggage: {'existing': 'value'},
      );
      final updated = ctx.withBaggage({'new-key': 'new-value'});

      expect(updated.baggage['existing'], equals('value'));
      expect(updated.baggage['new-key'], equals('new-value'));
    });

    test('toHeaders/fromHeaders round-trip', () {
      const original = TraceContext(
        traceId: 'trace-abc',
        parentSpanId: 'span-xyz',
        baggage: {'user-id': '123', 'session': 'abc'},
      );

      final headers = original.toHeaders();
      final restored = TraceContext.fromHeaders(headers);

      expect(restored.traceId, equals('trace-abc'));
      expect(restored.parentSpanId, equals('span-xyz'));
      expect(restored.baggage['user-id'], equals('123'));
      expect(restored.baggage['session'], equals('abc'));
    });

    test('toHeaders() produces correct keys', () {
      const ctx = TraceContext(
        traceId: 'trace-1',
        parentSpanId: 'span-1',
        baggage: {'key': 'val'},
      );

      final headers = ctx.toHeaders();
      expect(headers['trace-id'], equals('trace-1'));
      expect(headers['span-id'], equals('span-1'));
      expect(headers['baggage-key'], equals('val'));
    });

    test('fromHeaders() handles missing fields', () {
      final ctx = TraceContext.fromHeaders({});

      expect(ctx.traceId, equals(''));
      expect(ctx.parentSpanId, isNull);
      expect(ctx.baggage, isEmpty);
    });

    test('toJson() serializes correctly', () {
      const ctx = TraceContext(
        traceId: 'trace-1',
        parentSpanId: 'span-1',
        attributes: {'key': 'value'},
        baggage: {'item': 'data'},
      );

      final json = ctx.toJson();
      expect(json['traceId'], equals('trace-1'));
      expect(json['parentSpanId'], equals('span-1'));
      expect(json['attributes'], equals({'key': 'value'}));
      expect(json['baggage'], equals({'item': 'data'}));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // InMemoryTraceSink
  // ═══════════════════════════════════════════════════════════════

  group('InMemoryTraceSink', () {
    late InMemoryTraceSink sink;

    setUp(() {
      sink = InMemoryTraceSink();
    });

    test('records completed spans', () {
      sink.record(SpanData(
        traceId: 'trace-1',
        spanId: 'span-1',
        name: 'op-1',
        startTime: DateTime(2024, 1, 1),
        endTime: DateTime(2024, 1, 1, 0, 0, 1),
      ));

      expect(sink.spans.length, equals(1));
    });

    test('spansByTrace() filters correctly', () {
      sink.record(SpanData(
        traceId: 'trace-A',
        spanId: 'span-1',
        name: 'op-1',
        startTime: DateTime(2024, 1, 1),
      ));
      sink.record(SpanData(
        traceId: 'trace-B',
        spanId: 'span-2',
        name: 'op-2',
        startTime: DateTime(2024, 1, 1),
      ));
      sink.record(SpanData(
        traceId: 'trace-A',
        spanId: 'span-3',
        name: 'op-3',
        startTime: DateTime(2024, 1, 1),
      ));

      final traceA = sink.spansByTrace('trace-A');
      expect(traceA.length, equals(2));

      final traceB = sink.spansByTrace('trace-B');
      expect(traceB.length, equals(1));
    });

    test('spanById() returns correct span', () {
      sink.record(SpanData(
        traceId: 'trace-1',
        spanId: 'span-abc',
        name: 'target',
        startTime: DateTime(2024, 1, 1),
      ));

      final span = sink.spanById('span-abc');
      expect(span, isNotNull);
      expect(span!.name, equals('target'));
    });

    test('spanById() returns null for unknown ID', () {
      expect(sink.spanById('nonexistent'), isNull);
    });

    test('clear() removes all spans', () {
      sink.record(SpanData(
        traceId: 'trace-1',
        spanId: 'span-1',
        name: 'op',
        startTime: DateTime(2024, 1, 1),
      ));
      sink.clear();

      expect(sink.spans, isEmpty);
    });
  });
}
