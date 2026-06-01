import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';
import 'package:test/test.dart';

/// Records dispatched actions and returns scripted outputs.
class _Dispatcher {
  final List<String> calls = [];
  final Map<String, Map<String, dynamic>> outputs;

  _Dispatcher([this.outputs = const {}]);

  Future<Map<String, dynamic>?> call(
    BehaviorAction action,
    Map<String, dynamic> state,
  ) async {
    calls.add(action.ref);
    return outputs[action.ref];
  }
}

BehaviorEngine _engine(_Dispatcher d, {StateStore? store}) => BehaviorEngine(
      store: store ?? EphemeralStateStore(),
      dispatch: d.call,
    );

void main() {
  group('guard evaluation', () {
    const g = GuardEvaluator();

    test('bare reference returns the raw value', () {
      expect(g.evaluate('count', {'count': 100}), 100);
      expect(g.evaluate('status', {'status': 'paused'}), 'paused');
    });

    test('comparators yield bool', () {
      expect(g.evaluate('count == 100', {'count': 100}), true);
      expect(g.evaluate('count < 10', {'count': 100}), false);
      expect(g.evaluate('count >= 10', {'count': 10}), true);
    });

    test('boolean combinators', () {
      final s = {'a': true, 'b': false};
      expect(g.evaluate('a || b', s), true);
      expect(g.evaluate('a && b', s), false);
      expect(g.evaluate('(a || b) && a', s), true);
    });

    test('empty guard is true', () => expect(g.evaluate('', {}), true));
  });

  group('linear run', () {
    test('runs steps in order, merges output into state', () async {
      final d = _Dispatcher({
        'fetch': {'value': 7},
      });
      final result = await _engine(d).run(
        'r1',
        [
          const BehaviorStep(
              id: 's1', action: BehaviorAction(kind: 'tool', ref: 'fetch')),
          const BehaviorStep(
              id: 's2', action: BehaviorAction(kind: 'tool', ref: 'store')),
        ],
        {},
      );
      expect(result.isComplete, isTrue);
      expect(d.calls, ['fetch', 'store']);
      expect(result.state['value'], 7);
    });
  });

  group('gate on a prior step output (philosophy/quality pattern)', () {
    test('a later guard reads the check step output merged into state',
        () async {
      // Mirrors `bk.philosophy.check` → next step gates on hasHardViolation.
      final d = _Dispatcher({
        'philo_check': {'hasHardViolation': false},
      });
      final result = await _engine(d).run(
        'r',
        [
          const BehaviorStep(
            id: 'check',
            action: BehaviorAction(kind: 'tool', ref: 'philo_check'),
          ),
          const BehaviorStep(
            id: 'proceed',
            when: 'hasHardViolation == false',
            action: BehaviorAction(kind: 'tool', ref: 'do_it'),
          ),
        ],
        {},
      );
      expect(result.isComplete, isTrue);
      expect(d.calls, ['philo_check', 'do_it']); // gate opened
    });

    test('hard violation blocks the gated step', () async {
      final d = _Dispatcher({
        'philo_check': {'hasHardViolation': true},
      });
      final result = await _engine(d).run(
        'r',
        [
          const BehaviorStep(
              id: 'check',
              action: BehaviorAction(kind: 'tool', ref: 'philo_check')),
          const BehaviorStep(
            id: 'blocked',
            when: 'hasHardViolation == false',
            then: {'false': 'stop'},
            action: BehaviorAction(kind: 'tool', ref: 'do_it'),
          ),
        ],
        {},
      );
      expect(result.isComplete, isTrue);
      expect(d.calls, ['philo_check']); // 'do_it' never runs — gate blocked
    });
  });

  group('guard routing', () {
    test('false guard skips the action (legacy semantics)', () async {
      final d = _Dispatcher();
      final result = await _engine(d).run(
        'r2',
        [
          const BehaviorStep(
            id: 's1',
            when: 'ready == true',
            action: BehaviorAction(kind: 'tool', ref: 'go'),
          ),
        ],
        {'ready': false},
      );
      expect(result.isComplete, isTrue);
      expect(d.calls, isEmpty); // skipped
    });

    test('then maps an arbitrary value to an outcome', () async {
      final d = _Dispatcher();
      final result = await _engine(d).run(
        'r3',
        [
          const BehaviorStep(
            id: 's1',
            when: 'status',
            then: {'paused': 'wait', 'go': 'proceed'},
            action: BehaviorAction(kind: 'tool', ref: 'go'),
          ),
        ],
        {'status': 'paused'},
      );
      expect(result.isSuspended, isTrue);
      expect(result.waitingStepId, 's1');
    });
  });

  group('wait + resume (durable behavior)', () {
    test('suspends on wait then resumes when state changes', () async {
      final store = EphemeralStateStore();
      final d = _Dispatcher();
      final steps = [
        const BehaviorStep(
          id: 'gate',
          when: 'approved == true',
          then: {'false': 'wait'},
        ),
        const BehaviorStep(
            id: 'pay', action: BehaviorAction(kind: 'tool', ref: 'pay')),
      ];

      final first = await _engine(d, store: store).run('run', steps, {});
      expect(first.isSuspended, isTrue);
      expect(first.waitingStepId, 'gate');
      expect(d.calls, isEmpty);

      // A tool sets the state the guard reads — then resume.
      final saved = await store.load('run');
      saved!.state['approved'] = true;
      await store.save(saved);

      final resumed = await _engine(d, store: store).resume('run', steps);
      expect(resumed.isComplete, isTrue);
      expect(d.calls, ['pay']);
    });

    test('resume statePatch unblocks the gate (approval path)', () async {
      final store = EphemeralStateStore();
      final d = _Dispatcher();
      final steps = [
        const BehaviorStep(
          id: 'gate',
          when: 'approved == true',
          then: {'false': 'wait'},
        ),
        const BehaviorStep(
            id: 'pay', action: BehaviorAction(kind: 'tool', ref: 'pay')),
      ];
      final engine = BehaviorEngine(store: store, dispatch: d.call);

      final first = await engine.run('run', steps, {});
      expect(first.isSuspended, isTrue);

      // Approver resumes with the state delta — no separate store write.
      final resumed = await engine
          .resume('run', steps, statePatch: {'approved': true});
      expect(resumed.isComplete, isTrue);
      expect(d.calls, ['pay']);
    });

    test('resume while still waiting stays suspended', () async {
      final store = EphemeralStateStore();
      final d = _Dispatcher();
      final steps = [
        const BehaviorStep(
            id: 'gate', when: 'approved == true', then: {'false': 'wait'}),
      ];
      await _engine(d, store: store).run('run', steps, {});
      final again = await _engine(d, store: store).resume('run', steps);
      expect(again.isSuspended, isTrue);
    });
  });

  group('durable store (KvStateStore)', () {
    test('a fresh engine + store resumes a persisted run (restart sim)',
        () async {
      final kv = <String, String>{};
      KvStateStore makeStore() => KvStateStore(
            writeKv: (k, v) async => kv[k] = v,
            readKv: (k) async => kv[k],
            removeKv: (k) async {
              kv.remove(k);
            },
          );
      final steps = [
        const BehaviorStep(
            id: 'gate', when: 'approved == true', then: {'false': 'wait'}),
        const BehaviorStep(
            id: 'pay', action: BehaviorAction(kind: 'tool', ref: 'pay')),
      ];

      final d = _Dispatcher();
      final first =
          await BehaviorEngine(store: makeStore(), dispatch: d.call)
              .run('run', steps, {});
      expect(first.isSuspended, isTrue);
      expect(kv.isNotEmpty, isTrue); // persisted to the kv backend

      // Simulate a restart: brand-new store instance over the same kv.
      final store2 = makeStore();
      final saved = await store2.load('run');
      saved!.state['approved'] = true;
      await store2.save(saved);

      final resumed = await BehaviorEngine(store: store2, dispatch: d.call)
          .resume('run', steps);
      expect(resumed.isComplete, isTrue);
      expect(d.calls, ['pay']);
    });
  });

  group('control outcomes', () {
    test('stop halts the run', () async {
      final d = _Dispatcher();
      final result = await _engine(d).run(
        'r',
        [
          const BehaviorStep(id: 's1', when: 'x', then: {'true': 'stop'}),
          const BehaviorStep(
              id: 's2', action: BehaviorAction(kind: 'tool', ref: 'after')),
        ],
        {'x': true},
      );
      expect(result.isComplete, isTrue);
      expect(d.calls, isEmpty);
    });

    test('goto jumps to a target step', () async {
      final d = _Dispatcher();
      final result = await _engine(d).run(
        'r',
        [
          const BehaviorStep(id: 's1', when: 'x', then: {'true': 'goto:s3'}),
          const BehaviorStep(
              id: 's2', action: BehaviorAction(kind: 'tool', ref: 'skipped')),
          const BehaviorStep(
              id: 's3', action: BehaviorAction(kind: 'tool', ref: 'target')),
        ],
        {'x': true},
      );
      expect(result.isComplete, isTrue);
      expect(d.calls, ['target']);
    });

    test('custom outcome handler registers without core change', () async {
      final outcomes = OutcomeRegistry.standard()
        ..register('escalate', (_) => ControlSignal.stop);
      final d = _Dispatcher();
      final engine = BehaviorEngine(
        store: EphemeralStateStore(),
        dispatch: d.call,
        outcomes: outcomes,
      );
      final result = await engine.run(
        'r',
        [
          const BehaviorStep(id: 's1', when: 'sev', then: {'high': 'escalate'}),
          const BehaviorStep(
              id: 's2', action: BehaviorAction(kind: 'tool', ref: 'after')),
        ],
        {'sev': 'high'},
      );
      expect(result.isComplete, isTrue);
      expect(d.calls, isEmpty);
    });
  });

  group('ordering and failure', () {
    test('dependsOn orders execution', () async {
      final d = _Dispatcher();
      await _engine(d).run(
        'r',
        [
          const BehaviorStep(
              id: 'b',
              dependsOn: ['a'],
              action: BehaviorAction(kind: 'tool', ref: 'b')),
          const BehaviorStep(
              id: 'a', action: BehaviorAction(kind: 'tool', ref: 'a')),
        ],
        {},
      );
      expect(d.calls, ['a', 'b']);
    });

    test('onFailure jumps; absence fails the run', () async {
      final throwing = BehaviorEngine(
        store: EphemeralStateStore(),
        dispatch: (action, state) async => throw StateError('boom'),
      );
      final result = await throwing.run(
        'r',
        [
          const BehaviorStep(id: 's1', action: BehaviorAction(kind: 'tool', ref: 'x')),
        ],
        {},
      );
      expect(result.isFailed, isTrue);
      expect(result.error, contains('boom'));
    });
  });

  group('json round-trip', () {
    test('step serializes and parses', () {
      final step = BehaviorStep.fromJson({
        'id': 's1',
        'do': {'tool': 'send', 'args': {'to': 'x'}},
        'when': 'ok == true',
        'then': {'false': 'wait'},
        'dependsOn': ['s0'],
      });
      expect(step.action!.kind, 'tool');
      expect(step.action!.ref, 'send');
      expect(step.then['false'], 'wait');
      final json = step.toJson();
      expect(json['do'], isA<Map>());
      expect((json['do'] as Map)['ref'], 'send');
    });

    test('skill shorthand parses to skill action', () {
      final step = BehaviorStep.fromJson({
        'id': 's1',
        'do': {'skill': 'review', 'inputs': {'doc': 1}},
      });
      expect(step.action!.kind, 'skill');
      expect(step.action!.ref, 'review');
      expect(step.action!.args['doc'], 1);
    });
  });
}
