// Event delivery through OpsEventSubscriber: patterns, concurrency, retries.

import 'dart:async';

import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart' hide RetryPolicy;
import 'package:mcp_knowledge_ops/src/events/event_subscriber.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

PortEvent _event(String type, [Map<String, dynamic>? payload]) => PortEvent(
    type: type, payload: payload ?? {'k': type}, timestamp: DateTime.utc(2026));

Future<void> _settle([int ms = 20]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late MockEventPort port;
  late OpsEventSubscriber subscriber;

  setUp(() {
    port = MockEventPort();
    subscriber = OpsEventSubscriber(eventPort: port, logger: testLogger().$1);
  });

  tearDown(() => subscriber.cancelAll());

  test('streams: an exact type, and a wildcard pattern', () async {
    final exact = <OpsEvent>[];
    final wild = <OpsEvent>[];
    subscriber.subscribe('a.b.c').listen(exact.add);
    subscriber.subscribe('a.*.c').listen(wild.add);
    for (final t in ['a.b.c', 'a.x.c', 'a.b.d']) {
      await port.publish(_event(t));
    }
    await _settle();
    expect(exact.map((e) => e.eventType), ['a.b.c']);
    expect(wild.map((e) => e.eventType), ['a.b.c', 'a.x.c']);
  });

  group('handler patterns', () {
    Future<List<String>> deliver(String pattern, List<String> types) async {
      final got = <String>[];
      subscriber.subscribeWithHandler(
          pattern, (e) async => got.add(e.eventType));
      for (final t in types) {
        await port.publish(_event(t));
      }
      await _settle();
      return got;
    }

    test('star matches everything', () async {
      expect(await deliver('*', ['a', 'b.c']), ['a', 'b.c']);
    });
    test('an exact type matches only itself', () async {
      expect(await deliver('a.b', ['a.b', 'a.c']), ['a.b']);
    });
    test('a trailing star matches a segment under the prefix', () async {
      expect(
          await deliver('ops.pipeline.*',
              ['ops.pipeline.started', 'ops.workflow.started', 'ops.pipeline']),
          ['ops.pipeline.started']);
    });
    test('a middle star needs that segment to exist and the length to match',
        () async {
      expect(await deliver('a.*.c', ['a.b.c', 'a.b.c.d', 'a']), ['a.b.c']);
    });
    test('a double star matches the rest', () async {
      expect(await deliver('a.**', ['a.b.c', 'b.c']), ['a.b.c']);
    });
    test('a literal segment that differs, or is missing, fails', () async {
      expect(await deliver('a.b.*', ['a.x.y', 'a']), isEmpty);
    });
  });

  test('stats count what is received and processed', () async {
    final sub = subscriber.subscribeWithHandler('e', (e) async {});
    await port.publish(_event('e'));
    await port.publish(_event('e'));
    await _settle();
    expect(sub.stats.received, 2);
    expect(sub.stats.processed, 2);
  });

  test('a paused subscription resumes; a cancelled one stops delivering',
      () async {
    var n = 0;
    final sub = subscriber.subscribeWithHandler('e', (e) async => n++);
    await sub.pause();
    await port.publish(_event('e'));
    await _settle();
    expect(n, 0);
    await sub.resume();
    await _settle();
    expect(n, 1);
    await subscriber.unsubscribe(sub);
    await port.publish(_event('e'));
    await _settle();
    expect(n, 1);
    expect(subscriber.activeSubscriptions, isEmpty);
  });

  test('concurrency one runs handlers one after another', () async {
    final order = <String>[];
    subscriber.subscribeWithHandler('e', (e) async {
      order.add('in:${e.payload['n']}');
      await Future<void>.delayed(const Duration(milliseconds: 15));
      order.add('out:${e.payload['n']}');
    });
    await port.publish(_event('e', {'n': 1}));
    await port.publish(_event('e', {'n': 2}));
    await port.publish(_event('e', {'n': 3}));
    await _settle(120);
    expect(order, ['in:1', 'out:1', 'in:2', 'out:2', 'in:3', 'out:3']);
  });

  test('concurrency above one overlaps handlers', () async {
    var active = 0, peak = 0;
    subscriber.subscribeWithHandler('e', (e) async {
      active++;
      if (active > peak) peak = active;
      await Future<void>.delayed(const Duration(milliseconds: 15));
      active--;
    }, concurrency: 3);
    for (var i = 0; i < 3; i++) {
      await port.publish(_event('e'));
    }
    await _settle(80);
    expect(peak, 3);
  });

  test('a failing handler is retried with backoff, then counted as an error',
      () async {
    var attempts = 0;
    final sub = subscriber.subscribeWithHandler('e', (e) async {
      attempts++;
      throw StateError('no');
    },
        retryPolicy: const RetryPolicy(
            maxRetries: 2, initialDelay: Duration(milliseconds: 2)));
    await port.publish(_event('e'));
    await _settle(100);
    expect(attempts, 3);
    expect(sub.stats.errors, 1);
    expect(sub.stats.processed, 0);
  });

  test('a handler that succeeds on a retry is processed once', () async {
    var attempts = 0;
    final sub = subscriber.subscribeWithHandler('e', (e) async {
      if (++attempts < 2) throw StateError('once');
    },
        retryPolicy: const RetryPolicy(
            maxRetries: 2, initialDelay: Duration(milliseconds: 2)));
    await port.publish(_event('e'));
    await _settle(60);
    expect(sub.stats.processed, 1);
    expect(sub.stats.errors, 0);
  });

  test('without a retry policy a failure is final', () async {
    final sub = subscriber.subscribeWithHandler(
        'e', (e) async => throw StateError('x'));
    await port.publish(_event('e'));
    await _settle();
    expect(sub.stats.errors, 1);
  });

  test('retry delays grow and are capped', () {
    const p = RetryPolicy(
        initialDelay: Duration(milliseconds: 10),
        maxDelay: Duration(milliseconds: 25));
    expect(p.delayForAttempt(1), const Duration(milliseconds: 10));
    expect(p.delayForAttempt(2), const Duration(milliseconds: 20));
    expect(p.delayForAttempt(3), const Duration(milliseconds: 25));
  });
}
