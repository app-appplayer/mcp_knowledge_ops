// Gate evaluation, circuit breaker and checkpoint branches not reached by the
// other tests.

import 'dart:async';

import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

GateCondition _threshold(String metric, Object? value, [String? op]) =>
    GateCondition(
        type: ConditionType.threshold,
        metric: metric,
        value: value,
        operator: op);

Future<GateResult> _eval(List<GateCondition> conditions,
    {Map<String, dynamic> state = const {},
    GateFailure onFailure = GateFailure.block}) {
  return GateEvaluator().evaluate(
      Gate(
          id: 'g',
          name: 'g',
          afterStage: 's',
          conditions: conditions,
          onFailure: onFailure),
      testExecutionContext(state: state));
}

void main() {
  group('gate thresholds', () {
    test('every comparison operator', () async {
      final state = {'x': 5};
      Future<bool> run(String op, num v) async =>
          (await _eval([_threshold('state.x', v, op)], state: state)).passed;
      expect(await run('<=', 5), isTrue);
      expect(await run('<=', 4), isFalse);
      expect(await run('>=', 5), isTrue);
      expect(await run('>', 4), isTrue);
      expect(await run('<', 6), isTrue);
      expect(await run('==', 5), isTrue);
      expect(await run('!=', 5), isFalse);
      expect(await run('~', 5), isTrue); // unknown operator means >=
    });

    test('missing metric, missing value, non-numeric value', () async {
      final noMetric = await _eval(
          [const GateCondition(type: ConditionType.threshold, value: 1)]);
      expect(noMetric.passed, isFalse);
      final missing = await _eval([_threshold('state.nope', 1)]);
      expect(missing.passed, isFalse);
      final text = await _eval([_threshold('state.s', 1)], state: {'s': 'abc'});
      expect(text.conditionResults.single.message, contains('not numeric'));
      final numericText =
          await _eval([_threshold('state.s', '1')], state: {'s': '2'});
      expect(numericText.passed, isTrue); // numeric strings are accepted
    });

    test('a non-blocking gate evaluates every condition', () async {
      final r = await _eval([
        _threshold('state.x', 10),
        _threshold('state.x', 1),
      ], state: {
        'x': 5
      }, onFailure: GateFailure.warn);
      expect(r.conditionResults, hasLength(2));
      expect(r.passed, isFalse);
    });
  });

  group('gate expressions and approvals', () {
    GateCondition expr(String e) =>
        GateCondition(type: ConditionType.expression, expression: e);

    test('missing expression and an evaluation error', () async {
      expect(
          (await _eval([const GateCondition(type: ConditionType.expression)]))
              .passed,
          isFalse);
      // A comparison of non-numbers throws inside the evaluator.
      final r = await _eval([expr('state.s > 1')], state: {'s': 'abc'});
      expect(r.passed, isFalse);
      expect(r.conditionResults.single.message,
          contains('Expression evaluation error'));
    });

    test('boolean and comparison expressions', () async {
      final state = {
        'a': 3,
        'b': true,
        'list': [10, 20]
      };
      Future<bool> ok(String e) async =>
          (await _eval([expr(e)], state: state)).passed;
      expect(await ok('state.b == true || state.a > 9'), isTrue);
      expect(await ok('state.a > 1 && state.b == true'), isTrue);
      expect(await ok('state.a > 1 && state.a < 2'), isFalse);
      expect(await ok('state.a >= 3'), isTrue);
      expect(await ok('state.a <= 2'), isFalse);
      expect(await ok('state.a != 4'), isTrue);
      expect(await ok('state.list.1 == 20'), isTrue);
      expect(await ok('state.list.9 == 20'), isFalse); // out of range
      expect(await ok('state.a.b == 1'), isFalse); // path into a number
      expect(await ok('state.a > 1 > 0'), isFalse); // not a binary comparison
      expect(await ok(r'${state.b}'), isTrue);
      expect(await ok('null == null'), isTrue);
    });

    test('mapping evaluation resolves expressions', () {
      final ctx = testExecutionContext(state: {'a': 7});
      final out = ExpressionEvaluator().evaluateMapping(
          {'x': 'state.a', 'y': '3', 'z': 'null', 't': 'true'}, ctx);
      expect(out, {'x': 7, 'y': 3, 'z': null, 't': true});
    });

    test('approvals: missing, wrong approver, right approver, denied',
        () async {
      GateCondition cond(List<String>? who) =>
          GateCondition(type: ConditionType.approval, approvers: who);
      expect((await _eval([cond(null)])).passed, isFalse);
      Map<String, dynamic> approval(bool ok, String by) => {
            'approvals.approval_0': {'approved': ok, 'approver': by}
          };
      final wrong = await _eval([
        cond(['boss'])
      ], state: approval(true, 'eve'));
      expect(wrong.conditionResults.single.message, contains('not in allowed'));
      expect(
          (await _eval([
            cond(['boss'])
          ], state: approval(true, 'boss')))
              .passed,
          isTrue);
      expect((await _eval([cond(null)], state: approval(false, 'boss'))).passed,
          isFalse);
    });
  });

  group('circuit breaker', () {
    test('open state allows a request only after the reset timeout', () async {
      final b = CircuitBreaker(
          'c',
          const CircuitBreakerConfig(
              failureThreshold: 1,
              resetTimeout: Duration(milliseconds: 30),
              halfOpenMaxRequests: 1,
              successThreshold: 1));
      await expectLater(
          b.execute<int>(() async => throw StateError('x')), throwsStateError);
      expect(b.state, CircuitState.open);
      expect(b.isAllowed, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(b.isAllowed, isTrue);
    });

    test('half-open rejects requests beyond its limit', () async {
      final b = CircuitBreaker(
          'c',
          const CircuitBreakerConfig(
              failureThreshold: 1,
              resetTimeout: Duration(milliseconds: 10),
              halfOpenMaxRequests: 1,
              successThreshold: 2));
      await expectLater(
          b.execute<int>(() async => throw StateError('x')), throwsStateError);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final gate = Completer<int>();
      final first = b.execute(() => gate.future); // moves to half-open
      await Future<void>.delayed(Duration.zero);
      expect(b.state, CircuitState.halfOpen);
      expect(b.isAllowed, isFalse); // limit reached
      await expectLater(
          b.execute(() async => 1), throwsA(isA<CircuitOpenException>()));
      gate.complete(1);
      await first;
    });

    test('a sliding window forgets old failures', () async {
      final b = CircuitBreaker(
          'c',
          const CircuitBreakerConfig(
              failureThreshold: 2, slidingWindow: Duration(milliseconds: 20)));
      await expectLater(
          b.execute<int>(() async => throw StateError('x')), throwsStateError);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await expectLater(
          b.execute<int>(() async => throw StateError('x')), throwsStateError);
      expect(b.state, CircuitState.closed); // the first failure aged out
    });
  });

  group('resilient executor', () {
    test('retry delay backs off, is clamped and jittered', () {
      const c = ResilientRetryConfig(
          initialDelay: Duration(milliseconds: 100),
          maxDelay: Duration(milliseconds: 150),
          jitterFactor: 0.5);
      expect(c.calculateDelay(0), Duration.zero);
      for (var i = 0; i < 20; i++) {
        final d = c.calculateDelay(3);
        expect(d, lessThanOrEqualTo(const Duration(milliseconds: 150)));
      }
    });

    test('retries, then succeeds; stops when not retryable; rethrows',
        () async {
      final breaker = CircuitBreaker(
          'c', const CircuitBreakerConfig(failureThreshold: 100));
      final ex = ResilientExecutor(
          circuitBreaker: breaker,
          retryConfig: const ResilientRetryConfig(
              maxAttempts: 3,
              initialDelay: Duration(milliseconds: 1),
              jitterFactor: 0));
      var n = 0;
      expect(
          await ex.execute(() async {
            if (++n < 3) throw StateError('again');
            return n;
          }),
          3);
      n = 0;
      await expectLater(
          ex.execute<int>(() async {
            n++;
            throw StateError('fatal');
          }, isRetryable: (e) => false),
          throwsStateError);
      expect(n, 1);
      n = 0;
      await expectLater(ex.execute<int>(() async {
        n++;
        throw StateError('always');
      }), throwsStateError);
      expect(n, 3);
    });

    test('an open circuit is not retried', () async {
      final breaker = CircuitBreaker(
          'c',
          const CircuitBreakerConfig(
              failureThreshold: 1, resetTimeout: Duration(minutes: 5)));
      await expectLater(breaker.execute<int>(() async => throw StateError('x')),
          throwsStateError);
      final ex = ResilientExecutor(circuitBreaker: breaker);
      await expectLater(
          ex.execute(() async => 1), throwsA(isA<CircuitOpenException>()));
    });
  });

  group('persistent checkpoints', () {
    late MockKvStorage storage;
    late PersistentCheckpointManager manager;

    Checkpoint cp(String id, String run, DateTime at, {DateTime? expires}) =>
        Checkpoint(
            id: id,
            runId: run,
            name: id,
            state: const {},
            stageOutputs: const {},
            executionState: ExecutionState.paused,
            createdAt: at,
            expiresAt: expires);

    setUp(() {
      storage = MockKvStorage();
      manager = PersistentCheckpointManager(storage: storage, namespace: 'n');
    });

    test('loadLatest skips non-active and expired; list filters and limits',
        () async {
      final t = DateTime.now();
      await manager.save(cp('a', 'r', t.subtract(const Duration(minutes: 3))));
      await manager.save(cp('b', 'r', t.subtract(const Duration(minutes: 2))));
      await manager.save(cp('c', 'r', t.subtract(const Duration(minutes: 1))));
      expect((await manager.loadLatest('r'))!.id, 'c');
      await manager.markResumed('c');
      expect(await manager.loadLatest('r'), isNull); // a, b are superseded
      expect(await manager.loadLatest('other'), isNull);

      final resumed =
          await manager.listForRun('r', status: CheckpointStatus.resumed);
      expect(resumed.map((c) => c.id), ['c']);
      final limited = await manager.listForRun('r', limit: 2);
      expect(limited, hasLength(2));
      expect(limited.first.id, 'c'); // newest first
      expect(await manager.listForRun('r', limit: 10), hasLength(3));

      // An active checkpoint that has expired is skipped.
      await manager
          .save(cp('e', 'r', t, expires: t.subtract(const Duration(hours: 1))));
      expect(await manager.loadLatest('r'), isNull);
    });

    test('cleanup removes expired checkpoints and keeps the rest of a run',
        () async {
      final t = DateTime.now();
      await manager.save(
          cp('old', 'r', t, expires: t.subtract(const Duration(hours: 1))));
      await manager.save(cp('live', 'r', t));
      expect(
          await manager.cleanupExpired(olderThan: const Duration(hours: 1)), 1);
      expect((await manager.listForRun('r')).map((c) => c.id), ['live']);
      await manager.invalidateForRun('r');
      expect(await manager.loadLatest('r'), isNull);
    });

    test('an unknown stored status reads as active', () async {
      await manager.save(cp('x', 'r', DateTime.now()));
      await storage.set('n:status:x', 'garbage');
      expect((await manager.loadLatest('r'))!.id, 'x');
    });

    test('checkpoint exception text', () {
      expect(CheckpointException('bad', checkpointId: 'x').toString(),
          'CheckpointException: bad');
    });
  });
}
