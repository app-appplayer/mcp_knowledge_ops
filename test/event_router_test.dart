/// EventRouter Tests
///
/// Tests for EventRouter: handler registration, pattern matching
/// (exact, wildcard, double wildcard), interceptors, and error handling.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

void main() {
  group('EventRouter', () {
    late EventRouter router;
    late ExecutionLogger logger;

    setUp(() {
      final result = testLogger();
      logger = result.$1;
      router = EventRouter(logger: logger);
    });

    test('register handler and route matching event', () async {
      final received = <OpsEvent>[];

      router.register('ops.pipeline.started', (event) async {
        received.add(event);
      });

      final event = testOpsEvent(eventType: 'ops.pipeline.started');
      final count = await router.route(event);

      expect(count, equals(1));
      expect(received, hasLength(1));
      expect(received.first.eventType, equals('ops.pipeline.started'));
    });

    test('exact match does not match different type', () async {
      final received = <OpsEvent>[];

      router.register('ops.pipeline.started', (event) async {
        received.add(event);
      });

      final event = testOpsEvent(eventType: 'ops.pipeline.completed');
      final count = await router.route(event);

      expect(count, equals(0));
      expect(received, isEmpty);
    });

    test('wildcard (*) matches single segment', () async {
      final received = <OpsEvent>[];

      router.register('ops.pipeline.*', (event) async {
        received.add(event);
      });

      // Should match single segment after prefix
      final event1 = testOpsEvent(eventType: 'ops.pipeline.started');
      final count1 = await router.route(event1);
      expect(count1, equals(1));
      expect(received, hasLength(1));

      // Should NOT match multiple segments after prefix
      received.clear();
      final event2 = testOpsEvent(eventType: 'ops.pipeline.stage.started');
      final count2 = await router.route(event2);
      expect(count2, equals(0));
      expect(received, isEmpty);
    });

    test('double wildcard (**) matches multiple segments', () async {
      final received = <OpsEvent>[];

      router.register('ops.**', (event) async {
        received.add(event);
      });

      // Should match any event starting with 'ops.'
      final event1 = testOpsEvent(eventType: 'ops.pipeline.started');
      await router.route(event1);

      final event2 = testOpsEvent(eventType: 'ops.workflow.step.completed');
      await router.route(event2);

      expect(received, hasLength(2));
    });

    test('global wildcard (**) matches everything', () async {
      final received = <OpsEvent>[];

      router.register('**', (event) async {
        received.add(event);
      });

      final event = testOpsEvent(eventType: 'any.event.type.at.all');
      final count = await router.route(event);

      expect(count, equals(1));
      expect(received, hasLength(1));
    });

    test('global wildcard (*) matches everything', () async {
      final received = <OpsEvent>[];

      router.register('*', (event) async {
        received.add(event);
      });

      final event = testOpsEvent(eventType: 'some.event.type');
      final count = await router.route(event);

      expect(count, equals(1));
    });

    test('route() returns count of matched handlers', () async {
      router.register('ops.pipeline.started', (event) async {});
      router.register('ops.pipeline.started', (event) async {});
      router.register('ops.**', (event) async {});

      final event = testOpsEvent(eventType: 'ops.pipeline.started');
      final count = await router.route(event);

      // 2 from exact match + 1 from double wildcard
      expect(count, equals(3));
    });

    test('unregister removes handlers for pattern', () async {
      router.register('ops.pipeline.started', (event) async {});
      expect(router.handlerCount('ops.pipeline.started'), equals(1));

      router.unregister('ops.pipeline.started');
      expect(router.handlerCount('ops.pipeline.started'), equals(0));

      final event = testOpsEvent(eventType: 'ops.pipeline.started');
      final count = await router.route(event);
      expect(count, equals(0));
    });

    test('registeredPatterns returns all registered patterns', () {
      router.register('pattern.a', (event) async {});
      router.register('pattern.b', (event) async {});
      router.register('pattern.c', (event) async {});

      expect(
        router.registeredPatterns,
        containsAll(['pattern.a', 'pattern.b', 'pattern.c']),
      );
    });

    test('totalHandlerCount returns sum across all patterns', () {
      router.register('pattern.a', (event) async {});
      router.register('pattern.a', (event) async {});
      router.register('pattern.b', (event) async {});

      expect(router.totalHandlerCount, equals(3));
    });

    test('interceptors execute in order before handlers', () async {
      final order = <String>[];

      router.addInterceptor((event, next) async {
        order.add('interceptor-1');
        await next();
      });

      router.addInterceptor((event, next) async {
        order.add('interceptor-2');
        await next();
      });

      router.register('test.event', (event) async {
        order.add('handler');
      });

      final event = testOpsEvent(eventType: 'test.event');
      await router.route(event);

      expect(order, equals(['interceptor-1', 'interceptor-2', 'handler']));
    });

    test('interceptor can suppress event by not calling next', () async {
      final received = <OpsEvent>[];

      router.addInterceptor((event, next) async {
        // Do not call next() - suppress the event
      });

      router.register('test.event', (event) async {
        received.add(event);
      });

      final event = testOpsEvent(eventType: 'test.event');
      final count = await router.route(event);

      expect(count, equals(0));
      expect(received, isEmpty);
    });

    test('clearInterceptors removes all interceptors', () async {
      final received = <OpsEvent>[];

      router.addInterceptor((event, next) async {
        // Suppress - do not call next
      });

      router.clearInterceptors();

      router.register('test.event', (event) async {
        received.add(event);
      });

      final event = testOpsEvent(eventType: 'test.event');
      final count = await router.route(event);

      expect(count, equals(1));
      expect(received, hasLength(1));
    });

    test('error handler called on handler failure', () async {
      final errors = <({OpsEvent event, String pattern, Object error})>[];

      router = EventRouter(
        logger: logger,
        onError: (event, pattern, error, stack) {
          errors.add((event: event, pattern: pattern, error: error));
        },
      );

      router.register('test.error', (event) async {
        throw StateError('Handler failed');
      });

      final event = testOpsEvent(eventType: 'test.error');
      final count = await router.route(event);

      // Handler matched, so count is 1
      expect(count, equals(1));
      expect(errors, hasLength(1));
      expect(errors.first.pattern, equals('test.error'));
      expect(errors.first.error, isA<StateError>());
    });
  });
}
