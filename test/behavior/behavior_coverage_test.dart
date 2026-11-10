// Routing, failure, resume and storage branches of the behavior engine.

import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';
import 'package:test/test.dart';

BehaviorEngine _engine({
  StateStore? store,
  Future<Map<String, dynamic>?> Function(BehaviorAction, Map<String, dynamic>)?
      dispatch,
}) =>
    BehaviorEngine(
        store: store ?? EphemeralStateStore(),
        dispatch: dispatch ?? (a, s) async => null);

BehaviorStep _step(String id,
        {String? when,
        Map<String, String> then = const {},
        List<String> dependsOn = const [],
        String? onFailure,
        bool action = true}) =>
    BehaviorStep(
        id: id,
        when: when,
        then: then,
        dependsOn: dependsOn,
        onFailure: onFailure,
        action: action ? BehaviorAction(kind: 'tool', ref: id) : null);

void main() {
  group('guard', () {
    const g = GuardEvaluator();
    test('truthiness of every value kind', () {
      expect(GuardEvaluator.truthy(true), isTrue);
      expect(GuardEvaluator.truthy(0), isFalse);
      expect(GuardEvaluator.truthy(2), isTrue);
      expect(GuardEvaluator.truthy(''), isFalse);
      expect(GuardEvaluator.truthy('x'), isTrue);
      expect(GuardEvaluator.truthy(null), isFalse);
      expect(GuardEvaluator.truthy(const [1]), isTrue);
    });

    test('comparators, quoted strings and non-numbers', () {
      expect(g.evaluate('a != 1', {'a': 2}), isTrue);
      expect(g.evaluate('a > 1', {'a': 2}), isTrue);
      expect(g.evaluate('a <= 2', {'a': 2}), isTrue);
      expect(g.evaluate('a <= 1', {'a': 2}), isFalse);
      expect(g.evaluate('a > 1', {'a': 'x'}), isFalse); // not a number
      expect(g.evaluate("s == 'ok'", {'s': 'ok'}), isTrue);
      expect(g.evaluate('s == "ok"', {'s': 'ok'}), isTrue);
    });
  });

  group('outcomes', () {
    test('has, register and unknown names', () {
      final r = OutcomeRegistry.standard();
      expect(r.has('proceed'), isTrue);
      expect(r.has('goto:x'), isTrue);
      expect(r.has('nope'), isFalse);
      r.register('nope', (_) => ControlSignal.proceed);
      expect(r.has('nope'), isTrue);
      expect(
          () => OutcomeRegistry.standard()
              .resolve('missing', _step('s'), const {}),
          throwsStateError);
    });

    test('fail carries its message', () {
      final s = OutcomeRegistry.standard()
          .resolve('fail:because', _step('s'), const {});
      expect(s.primitive, ControlPrimitive.fail);
      expect(s.message, 'because');
    });
  });

  group('engine', () {
    test('no steps completes at once', () async {
      final r = await _engine().run('r', const [], {'a': 1});
      expect(r.isComplete, isTrue);
    });

    test('resume of an unknown run is an error; of a finished run is a no-op',
        () async {
      final engine = _engine();
      expect(() => engine.resume('nope', const []), throwsStateError);
      await engine.run('r', [_step('a')], {});
      final again = await engine.resume('r', [_step('a')]);
      expect(again.isComplete, isTrue);
    });

    test('a failing guard outcome fails the run with its message', () async {
      final r = await _engine().run('r', [
        _step('a', when: 'x', then: {'false': 'fail:no good'})
      ], {
        'x': false
      });
      expect(r.isFailed, isTrue);
      expect(r.error, 'no good');
      final bare = await _engine().run('r2', [
        _step('a', when: 'x', then: {'false': 'fail'})
      ], {
        'x': false
      });
      expect(bare.error, 'failed at a');
    });

    test('stop ends the run as completed, before later steps', () async {
      final calls = <String>[];
      final r = await _engine(dispatch: (a, s) async {
        calls.add(a.ref);
        return null;
      }).run('r', [
        _step('a', when: 'x', then: {'false': 'stop'}),
        _step('b')
      ], {
        'x': false
      });
      expect(r.isComplete, isTrue);
      expect(calls, isEmpty);
    });

    test('a thrown action jumps to onFailure when it names a step', () async {
      final calls = <String>[];
      final r = await _engine(dispatch: (a, s) async {
        calls.add(a.ref);
        if (a.ref == 'a') throw StateError('x');
        return {'ok': true};
      }).run('r', [
        _step('a', onFailure: 'rescue'),
        _step('mid'),
        _step('rescue'),
      ], {});
      expect(r.isComplete, isTrue);
      expect(calls, ['a', 'rescue']);
    });

    test('goto jumps, and a missing target fails', () async {
      final calls = <String>[];
      final ok = await _engine(dispatch: (a, s) async {
        calls.add(a.ref);
        return null;
      }).run('r', [
        _step('a', when: 'x', then: {'true': 'goto:c'}, action: false),
        _step('b'),
        _step('c'),
      ], {
        'x': true
      });
      expect(ok.isComplete, isTrue);
      expect(calls, ['c']);
      final bad = await _engine().run('r2', [
        _step('a', when: 'x', then: {'true': 'goto:zzz'}, action: false)
      ], {
        'x': true
      });
      expect(bad.isFailed, isTrue);
      expect(bad.error, contains('goto target not found: zzz'));
      final none = await _engine().run('r3', [
        _step('a', when: 'x', then: {'true': 'goto'}, action: false)
      ], {
        'x': true
      });
      expect(none.isFailed, isTrue);
    });

    test('dependsOn orders steps and tolerates cycles and unknown ids',
        () async {
      final calls = <String>[];
      final engine = _engine(dispatch: (a, s) async {
        calls.add(a.ref);
        return null;
      });
      await engine.run('r', [
        _step('a', dependsOn: ['b']),
        _step('b', dependsOn: ['ghost']),
      ], {});
      expect(calls, ['b', 'a']);
      calls.clear();
      await engine.run('cyc', [
        _step('a', dependsOn: ['b']),
        _step('b', dependsOn: ['a']),
      ], {});
      expect(calls.toSet(), {'a', 'b'});
    });
  });

  group('actions and runnable', () {
    test('explicit kind/ref json', () {
      final a = BehaviorAction.fromJson({
        'kind': 'skill',
        'ref': 's',
        'args': {'k': 1}
      });
      expect(a.kind, 'skill');
      expect(a.ref, 's');
      expect(a.args, {'k': 1});
    });

    test('a runnable runs, resumes and exposes its store', () async {
      final store = EphemeralStateStore();
      final r = BehaviorRunnable(_engine(store: store), [
        _step('gate', when: 'ok', then: {'false': 'wait'}, action: false)
      ]);
      expect(r.store, same(store));
      expect((await r.run('x', {'ok': false})).isSuspended, isTrue);
      expect(
          (await r.resume('x', statePatch: {'ok': true})).isComplete, isTrue);
    });
  });

  group('state stores', () {
    test('copyWith keeps and replaces', () {
      const s = BehaviorRunState(
          runId: 'r',
          state: {'a': 1},
          cursorStepId: 'c',
          status: BehaviorRunStatus.running);
      final c = s.copyWith(
          state: {'b': 2},
          cursorStepId: 'd',
          status: BehaviorRunStatus.failed,
          completed: ['x']);
      expect(c.state, {'b': 2});
      expect(c.cursorStepId, 'd');
      expect(c.status, BehaviorRunStatus.failed);
      expect(c.completed, ['x']);
      final k = s.copyWith();
      expect(k.state, {'a': 1});
      expect(k.status, BehaviorRunStatus.running);
    });

    test('unknown status in json is running', () {
      final s = BehaviorRunState.fromJson({'runId': 'r', 'status': 'weird'});
      expect(s.status, BehaviorRunStatus.running);
      expect(s.state, isEmpty);
      expect(s.completed, isEmpty);
    });

    test('the key-value store saves, loads and deletes', () async {
      final kv = <String, String>{};
      final store = KvStateStore(
        writeKv: (k, v) async => kv[k] = v,
        readKv: (k) async => kv[k],
        removeKv: (k) async => kv.remove(k),
      );
      await store.save(const BehaviorRunState(
          runId: 'r',
          state: {'a': 1},
          cursorStepId: null,
          status: BehaviorRunStatus.suspended,
          completed: ['s']));
      final back = await store.load('r');
      expect(back!.completed, ['s']);
      expect(await store.load('none'), isNull);
      await store.delete('r');
      expect(await store.load('r'), isNull);
    });

    test('the ephemeral store deletes', () async {
      final s = EphemeralStateStore();
      await s.save(const BehaviorRunState(
          runId: 'r',
          state: {},
          cursorStepId: null,
          status: BehaviorRunStatus.running));
      await s.delete('r');
      expect(await s.load('r'), isNull);
    });
  });
}
