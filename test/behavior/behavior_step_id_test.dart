import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';
import 'package:test/test.dart';

/// Records the step id each dispatched action carries.
class _Recorder {
  final List<({String ref, String? stepId, Map<String, dynamic> args})> seen =
      [];

  Future<Map<String, dynamic>?> call(
    BehaviorAction action,
    Map<String, dynamic> state,
  ) async {
    seen.add((ref: action.ref, stepId: action.stepId, args: action.args));
    return null;
  }
}

void main() {
  test('every dispatched action carries its step id', () async {
    final r = _Recorder();
    final engine =
        BehaviorEngine(store: EphemeralStateStore(), dispatch: r.call);
    await engine.run('run', [
      const BehaviorStep(
          id: 'first', action: BehaviorAction(kind: 'tool', ref: 'a')),
      const BehaviorStep(
          id: 'second',
          action: BehaviorAction(kind: 'tool', ref: 'b', args: {'x': r'${n}'})),
    ], {
      'n': 3
    });

    expect(r.seen.map((e) => (e.ref, e.stepId)),
        [('a', 'first'), ('b', 'second')]);
    // Arguments are rendered as before.
    expect(r.seen.last.args, {'x': 3});
  });

  test('the step id is also set after a resume', () async {
    final store = EphemeralStateStore();
    final r = _Recorder();
    final steps = [
      const BehaviorStep(
          id: 'gate', when: 'approved == true', then: {'false': 'wait'}),
      const BehaviorStep(
          id: 'pay', action: BehaviorAction(kind: 'tool', ref: 'pay')),
    ];
    final engine = BehaviorEngine(store: store, dispatch: r.call);
    expect((await engine.run('run', steps, {})).isSuspended, isTrue);
    await engine.resume('run', steps, statePatch: {'approved': true});

    expect(r.seen.single.stepId, 'pay');
  });

  test('a hand-built action has no step id and the JSON form is unchanged', () {
    const action = BehaviorAction(kind: 'tool', ref: 'a', args: {'k': 1});
    expect(action.stepId, isNull);
    expect(action.toJson(), {
      'kind': 'tool',
      'ref': 'a',
      'args': {'k': 1}
    });
  });
}
