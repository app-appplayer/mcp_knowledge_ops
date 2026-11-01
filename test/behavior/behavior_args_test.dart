// Arguments of a behavior action are filled from the run state before the
// dispatcher sees them (bundle spec 11 §11.7).

import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';
import 'package:test/test.dart';

/// Records the actions it is given and returns scripted outputs by ref.
class _Dispatcher {
  final List<BehaviorAction> actions = [];
  final Map<String, Map<String, dynamic>> outputs;

  _Dispatcher([this.outputs = const {}]);

  Future<Map<String, dynamic>?> call(
    BehaviorAction action,
    Map<String, dynamic> state,
  ) async {
    actions.add(action);
    return outputs[action.ref];
  }
}

BehaviorAction tool(String ref, [Map<String, dynamic> args = const {}]) =>
    BehaviorAction(kind: 'tool', ref: ref, args: args);

Future<_Dispatcher> run(
  List<BehaviorStep> steps, {
  Map<String, dynamic> state = const {},
  Map<String, Map<String, dynamic>> outputs = const {},
}) async {
  final d = _Dispatcher(outputs);
  await BehaviorEngine(store: EphemeralStateStore(), dispatch: d.call)
      .run('r', steps, state);
  return d;
}

void main() {
  test('an earlier result is passed on, with its type', () async {
    final d = await run([
      BehaviorStep(id: 'work', action: tool('work')),
      BehaviorStep(
          id: 'check',
          action: tool('check', {'prev': r'${work}', 'score': r'${work.score}'})),
    ], outputs: {
      'work': {'score': 7, 'tags': ['a']},
    });
    final args = d.actions.last.args;
    expect(args['score'], 7);
    expect(args['prev'], {'score': 7, 'tags': ['a']});
  });

  test('a value from the initial state is passed with its type', () async {
    final d = await run(
      [BehaviorStep(id: 's', action: tool('t', {'n': r'${count}', 'on': r'${flag}'}))],
      state: {'count': 3, 'flag': true},
    );
    expect(d.actions.single.args, {'n': 3, 'on': true});
  });

  test('text around an expression makes the value text', () async {
    final d = await run(
      [BehaviorStep(id: 's', action: tool('t', {'v': r'id-${count}', 'w': r' ${count}'}))],
      state: {'count': 3},
    );
    expect(d.actions.single.args, {'v': 'id-3', 'w': ' 3'});
  });

  test('maps and lists are walked at any depth', () async {
    final d = await run(
      [
        BehaviorStep(
            id: 's',
            action: tool('t', {
              'list': [r'${a}', 'plain', 7],
              'deep': {
                'rows': [
                  {'v': r'${a}'},
                ],
              },
            })),
      ],
      state: {'a': 'x'},
    );
    expect(d.actions.single.args, {
      'list': ['x', 'plain', 7],
      'deep': {
        'rows': [
          {'v': 'x'},
        ],
      },
    });
  });

  test('a path with no value is null alone and nothing inside text', () async {
    final d = await run([
      BehaviorStep(
          id: 's', action: tool('t', {'a': r'${nope}', 'b': r'[${nope}]'})),
    ]);
    expect(d.actions.single.args, {'a': isNull, 'b': '[]'});
  });

  test('a backslash dollar keeps a literal dollar sign', () async {
    final d = await run(
      [BehaviorStep(id: 's', action: tool('t', {'v': r'\${HOME} costs \$5'}))],
      state: {'HOME': 'x'},
    );
    expect(d.actions.single.args, {'v': r'${HOME} costs $5'});
  });

  test('arguments without a template are passed as written', () async {
    final d = await run([
      BehaviorStep(
          id: 's', action: tool('t', {'a': 'plain', 'n': 4, 'b': false, 'l': [1]})),
    ]);
    expect(d.actions.single.args, {'a': 'plain', 'n': 4, 'b': false, 'l': [1]});
  });

  test('an action without arguments is passed with the same kind and ref',
      () async {
    final d = await run([BehaviorStep(id: 's', action: tool('t'))]);
    expect(d.actions.single.kind, 'tool');
    expect(d.actions.single.ref, 't');
    expect(d.actions.single.args, isEmpty);
  });

  test('the kind and ref are kept', () async {
    final d = await run([
      BehaviorStep(
          id: 's',
          action: const BehaviorAction(
              kind: 'skill', ref: 'x', args: {'v': r'${a}'})),
    ], state: {'a': 1});
    expect(d.actions.single.kind, 'skill');
    expect(d.actions.single.ref, 'x');
  });

  test('the stored step definition is not changed by rendering', () async {
    final step = BehaviorStep(id: 's', action: tool('t', {'v': r'${a}'}));
    await run([step], state: {'a': 1});
    expect(step.action!.args, {'v': r'${a}'});
  });

  test('a skill input written as inputs is rendered too', () async {
    final step = BehaviorStep.fromJson({
      'id': 's',
      'do': {'skill': 'judge', 'inputs': {'prev': r'${work}'}},
    });
    final d = await run([step], state: {'work': 5});
    expect(d.actions.single.args, {'prev': 5});
  });
}
