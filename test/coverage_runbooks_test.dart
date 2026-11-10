// Runbook executor branches: dependencies, checks, failure modes, rollback,
// every action type, and the runbook model constructors.

import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

class _Approvals extends MockApprovalPort {
  _Approvals(this.status) : super(autoApprove: false);
  final ApprovalStatus status;
  @override
  Future<ApprovalResult> requestApproval(ApprovalRequest request) async =>
      ApprovalResult(
        approvalId: 'a1',
        status: status,
        approverId: 'boss',
        reason: status == ApprovalStatus.rejected ? 'no' : null,
        decidedAt: DateTime.utc(2026),
      );
}

RunbookContext _ctx([Map<String, dynamic>? state]) =>
    RunbookContext(runId: 'r', traceId: 't', workspaceId: 'w', state: state);

RunbookStep _step(
  String id,
  RunbookAction action, {
  String? condition,
  bool optional = false,
  RunbookOnFailure onFailure = RunbookOnFailure.fail,
  List<String> dependsOn = const [],
  List<StepCheck> pre = const [],
  List<StepCheck> post = const [],
}) =>
    RunbookStep(
      id: id,
      name: id,
      action: action,
      condition: condition,
      optional: optional,
      onFailure: onFailure,
      dependsOn: dependsOn,
      preChecks: pre,
      postChecks: post,
    );

const _noop = RunbookAction(type: RunbookStepType.wait);
const _failing = RunbookAction(type: RunbookStepType.pipeline, pipelineId: 'p');

Runbook _book(List<RunbookStep> steps, {RunbookConfig? config}) =>
    Runbook(id: 'rb', name: 'rb', steps: steps, config: config);

void main() {
  late HandlerRegistry handlers;
  setUp(() => handlers = HandlerRegistry());

  RunbookExecutor exec({
    ApprovalPort? approval,
    bool pipelines = false,
  }) =>
      RunbookExecutor(
        handlers: handlers,
        approvalPort: approval,
        pipelineExecutor:
            pipelines ? (id, input) async => {'out': 1, 'id': id} : null,
        workflowExecutor: pipelines ? (id, input) async => 'wf:$id' : null,
      );

  group('dependencies and conditions', () {
    test('an unmet dependency fails the run, or is skipped when optional',
        () async {
      final fail = await exec().execute(
          _book([
            _step('b', _noop, dependsOn: ['a'])
          ]),
          {},
          _ctx());
      expect(fail.success, isFalse);
      expect(fail.error!.stepId, 'b');
      final skip = await exec().execute(
          _book([
            _step('b', _noop, dependsOn: ['a'], optional: true),
            _step('c', _noop)
          ]),
          {},
          _ctx());
      expect(skip.success, isTrue);
      expect(skip.steps.first.success, isFalse);
    });

    test('condition forms', () async {
      Future<bool> ran(String cond, Map<String, dynamic> state) async {
        final r = await exec().execute(
            _book([_step('s', _noop, condition: cond)]), {}, _ctx(state));
        return r.success;
      }

      // A false condition still records the step as done.
      expect(await ran("mode == 'a'", {'mode': 'a'}), isTrue);
      expect(await ran('mode != "a"', {'mode': 'b'}), isTrue);
      expect(await ran('flag', {'flag': true}), isTrue);
      expect(await ran('flag', {'flag': 'x'}), isTrue);
      expect(await ran('flag', {'flag': 3}), isTrue);
      expect(await ran('flag', {}), isTrue);
    });
  });

  group('checks', () {
    StepCheck check(String name, CheckType type, Map<String, dynamic> config,
            [CheckSeverity sev = CheckSeverity.fail]) =>
        StepCheck(name: name, type: type, config: config, severity: sev);

    test('pre-checks: expression and metric kinds', () async {
      Future<RunbookResult> run(List<StepCheck> pre,
              {Map<String, dynamic>? state, bool optional = false}) =>
          exec().execute(
              _book([_step('s', _noop, pre: pre, optional: optional)]),
              {},
              _ctx(state));
      expect(
          (await run([
            check('c', CheckType.expression, {'expression': 'ok'})
          ], state: {
            'ok': true
          }))
              .success,
          isTrue);
      final noExpr = await run([check('c', CheckType.expression, {})]);
      expect(noExpr.success, isFalse);
      expect(noExpr.error!.message, contains('pre-check failed'));
      // Optional step: failure recorded, run continues.
      final opt =
          await run([check('c', CheckType.expression, {})], optional: true);
      expect(opt.success, isTrue);
      // A warning-level failure does not stop the step.
      final warn =
          await run([check('c', CheckType.expression, {}, CheckSeverity.warn)]);
      expect(warn.success, isTrue);

      Future<bool> metric(String op, num v,
              {Map<String, dynamic>? state}) async =>
          (await run([
            check('m', CheckType.metric,
                {'metric': 'x', 'threshold': 5, 'operator': op})
          ], state: state ?? {'x': v}))
              .success;
      expect(await metric('>=', 5), isTrue);
      expect(await metric('>', 6), isTrue);
      expect(await metric('<=', 5), isTrue);
      expect(await metric('<', 4), isTrue);
      expect(await metric('==', 5), isTrue);
      expect(await metric('~', 5), isFalse);
      expect(await metric('>', 1), isFalse);
      expect(await metric('>', 1, state: {}), isFalse); // metric missing
      expect((await run([check('m', CheckType.metric, {})])).success, isFalse);
      // Default operator is >=.
      expect(
          (await run([
            check('m', CheckType.metric, {'metric': 'x', 'threshold': 5})
          ], state: {
            'x': 5
          }))
              .success,
          isTrue);
    });

    test('command checks use a result in the state, or pass without one',
        () async {
      Future<bool> run(Map<String, dynamic> state) async =>
          (await exec().execute(
                  _book([
                    _step('s', _noop, pre: [
                      check('c', CheckType.command, {'resultKey': 'k'})
                    ])
                  ]),
                  {},
                  _ctx(state)))
              .success;
      expect(await run({}), isTrue);
      expect(await run({'k': true}), isTrue);
      expect(await run({'k': 'success'}), isTrue);
      expect(await run({'k': 0}), isTrue);
      expect(await run({'k': 'bad'}), isFalse);
    });

    test('post-checks fail the step, or are skipped when optional', () async {
      final bad = check('p', CheckType.expression, {'expression': 'never'});
      final fail = await exec().execute(
          _book([
            _step('s', _noop, post: [bad])
          ]),
          {},
          _ctx());
      expect(fail.success, isFalse);
      expect(fail.error!.message, contains('post-check failed'));
      final opt = await exec().execute(
          _book([
            _step('s', _noop, post: [bad], optional: true)
          ]),
          {},
          _ctx());
      expect(opt.success, isTrue);
      final warn = await exec().execute(
          _book([
            _step('s', _noop, post: [
              check('p', CheckType.expression, {'expression': 'never'},
                  CheckSeverity.warn)
            ])
          ]),
          {},
          _ctx());
      expect(warn.success, isTrue);
    });
  });

  group('failure modes and rollback', () {
    test('continue, skip, fail and rollback', () async {
      Future<RunbookResult> run(RunbookOnFailure f, {RunbookConfig? config}) =>
          exec().execute(
              _book([
                _step('first', _noop),
                _step('bad', _failing, onFailure: f),
                _step('last', _noop),
              ], config: config),
              {},
              _ctx());
      expect((await run(RunbookOnFailure.continue_)).success, isTrue);
      expect((await run(RunbookOnFailure.skip)).success, isTrue);
      final failed = await run(RunbookOnFailure.fail);
      expect(failed.success, isFalse);
      expect(failed.error!.message, contains('bad failed'));
      final rolled = await run(RunbookOnFailure.rollback);
      expect(rolled.success, isFalse);
      expect(rolled.error!.message, contains('rolled back'));
    });

    test('auto-rollback runs the rollback steps, even a failing one', () async {
      final ctx = _ctx();
      final r = await exec().execute(
          _book([
            _step('bad', _failing),
            _step('undo', _noop),
            _step('undo2', _failing),
          ],
              config: const RunbookConfig(
                  autoRollback: true,
                  rollbackSteps: ['undo', 'undo2', 'ghost'])),
          {},
          ctx);
      expect(r.success, isFalse);
      expect(ctx.state['_rolledBack'], isTrue);
      expect(ctx.state['_rollbackSteps'], isA<List>());
    });
  });

  group('actions', () {
    test('pipeline and workflow with and without executors', () async {
      final none =
          await exec().execute(_book([_step('p', _failing)]), {}, _ctx());
      expect(none.error!.message, contains('Pipeline executor not configured'));
      final wfNone = await exec().execute(
          _book([
            _step(
                'w',
                const RunbookAction(
                    type: RunbookStepType.workflow, workflowId: 'x'))
          ]),
          {},
          _ctx());
      expect(
          wfNone.error!.message, contains('Workflow executor not configured'));

      final ok = await exec(pipelines: true).execute(
          _book([
            _step(
                'p',
                const RunbookAction(
                    type: RunbookStepType.pipeline,
                    pipelineId: 'pl',
                    inputMapping: {'in': 'src'},
                    outputMapping: {'out': 'dst', 'absent': 'nowhere'})),
            _step(
                'w',
                const RunbookAction(
                    type: RunbookStepType.workflow, workflowId: 'wf')),
          ]),
          {},
          _ctx({'src': 1}));
      expect(ok.success, isTrue);
      expect(ok.output['dst'], 1);
      expect(ok.output.containsKey('nowhere'), isFalse);
    });

    test('wait, manual and notification', () async {
      final ctx = _ctx();
      final r = await exec().execute(
          _book([
            _step(
                'w',
                const RunbookAction(
                    type: RunbookStepType.wait, config: {'duration': 5})),
            _step(
                'm',
                const RunbookAction(
                    type: RunbookStepType.manual,
                    instructions: 'do it',
                    checklist: ['a'],
                    expectedDuration: Duration(minutes: 1))),
            _step(
                'n',
                const RunbookAction(
                    type: RunbookStepType.notification,
                    channel: 'mail',
                    template: 't',
                    recipients: ['x'])),
          ]),
          {},
          ctx);
      expect(r.success, isTrue);
      expect(ctx.state['_pendingManualSteps'], hasLength(1));
      expect(r.steps.last.output['channel'], 'mail');
    });

    test('approval: no port, approved, rejected, not granted', () async {
      const action = RunbookAction(type: RunbookStepType.approval, config: {
        'approvers': ['a'],
        'requiredApprovals': 2,
        'timeout': 5,
        'description': 'ok?'
      });
      final auto =
          await exec().execute(_book([_step('a', action)]), {}, _ctx());
      expect(auto.steps.single.output['method'], 'auto');
      final approved = await exec(approval: _Approvals(ApprovalStatus.approved))
          .execute(_book([_step('a', action)]), {}, _ctx());
      expect(approved.success, isTrue);
      final rejected = await exec(approval: _Approvals(ApprovalStatus.rejected))
          .execute(_book([_step('a', action)]), {}, _ctx());
      expect(rejected.success, isFalse);
      final pending = await exec(approval: _Approvals(ApprovalStatus.pending))
          .execute(
              _book([
                _step('a', const RunbookAction(type: RunbookStepType.approval))
              ]),
              {},
              _ctx());
      expect(pending.success, isFalse);
    });

    test('decision: matching branch, default branch, none', () async {
      RunbookAction decision({String? def}) => RunbookAction(
              type: RunbookStepType.decision,
              defaultBranch: def,
              branches: const [
                DecisionBranch(condition: "mode == 'a'", steps: ['x', 'ghost']),
              ]);
      final steps = [
        _step('x', _noop),
        _step('y', _noop),
      ];
      Future<dynamic> out(RunbookAction a, Map<String, dynamic> state) async =>
          (await exec()
                  .execute(_book([...steps, _step('d', a)]), {}, _ctx(state)))
              .steps
              .last
              .output;
      expect((await out(decision(), {'mode': 'a'}))['branch'], "mode == 'a'");
      expect(
          (await out(decision(def: 'y'), {'mode': 'b'}))['branch'], isNotNull);
      expect((await out(decision(def: 'ghost'), {'mode': 'b'}))['branch'],
          isNotNull);
      expect((await out(decision(), {'mode': 'b'}))['branch'], 'none');
      expect(
          (await out(const RunbookAction(type: RunbookStepType.decision), {}))[
              'branch'],
          'none');
    });

    test('parallel: empty, steps, fail fast', () async {
      final steps = [
        _step('x', _noop),
        _step('y', _failing, onFailure: RunbookOnFailure.continue_)
      ];
      Future<dynamic> out(RunbookAction a) async =>
          (await exec().execute(_book([...steps, _step('p', a)]), {}, _ctx()))
              .steps
              .last
              .output;
      expect(await out(const RunbookAction(type: RunbookStepType.parallel)),
          isEmpty);
      final both = await out(const RunbookAction(
          type: RunbookStepType.parallel, parallelSteps: ['x', 'ghost']));
      expect(both['x']['success'], isTrue);
      final failFast = await exec().execute(
          _book([
            ...steps,
            _step(
                'p',
                const RunbookAction(
                    type: RunbookStepType.parallel,
                    parallelSteps: ['x', 'y'],
                    failFast: true))
          ]),
          {},
          _ctx());
      expect(failFast.steps.isNotEmpty, isTrue);
    });

    test('loop: items, missing and bad collections', () async {
      final body = _step('body', _noop);
      RunbookAction loop(String? c) => RunbookAction(
          type: RunbookStepType.loop,
          collection: c,
          itemVariable: 'it',
          loopSteps: const ['body', 'ghost']);
      final ok = await exec().execute(
          _book([body, _step('l', loop('items'))]),
          {},
          _ctx({
            'items': [1, 2]
          }));
      expect(ok.steps.last.output['iterations'], hasLength(2));
      final defaultVar = await exec().execute(
          _book([
            body,
            _step(
                'l',
                const RunbookAction(
                    type: RunbookStepType.loop, collection: 'items'))
          ]),
          {},
          _ctx({
            'items': [1]
          }));
      expect(defaultVar.success, isTrue);
      final none = await exec()
          .execute(_book([body, _step('l', loop(null))]), {}, _ctx());
      expect(none.error!.message, contains('requires a collection'));
      final bad = await exec().execute(
          _book([body, _step('l', loop('items'))]), {}, _ctx({'items': 'no'}));
      expect(bad.error!.message, contains('not a List'));
    });

    test('script: missing handler and a handler', () async {
      const action = RunbookAction(
          type: RunbookStepType.script,
          script: 'echo',
          interpreter: 'sh',
          inputMapping: {'a': 'src'});
      final missing =
          await exec().execute(_book([_step('s', action)]), {}, _ctx());
      expect(missing.error!.message, contains('Script handler not found'));
      handlers.register(
          'sh',
          FunctionHandler(
              name: 'sh', handler: (input, ctx) async => {'got': input}));
      final ok = await exec()
          .execute(_book([_step('s', action)]), {}, _ctx({'src': 4}));
      expect(ok.success, isTrue);
      handlers.register('script',
          FunctionHandler(name: 'script', handler: (i, c) async => i));
      final plain = await exec().execute(
          _book([
            _step('s',
                const RunbookAction(type: RunbookStepType.script, script: 's'))
          ]),
          {},
          _ctx());
      expect(plain.success, isTrue);
    });
  });

  group('model constructors', () {
    test('wait conditions', () {
      expect(WaitCondition.metric('m').type, WaitType.metric);
      expect(WaitCondition.event('e').event, 'e');
      final t = DateTime.utc(2026);
      expect(WaitCondition.time(t).until, t);
      expect(WaitCondition.expression('x').expression, 'x');
      expect(WaitCondition(type: WaitType.metric).metric, isNull);
    });

    test('execution records', () {
      final started = DateTime.utc(2026);
      final trig = TriggerInfo(type: 'manual', triggeredAt: started);
      final ex = RunbookExecution(
          id: 'e',
          runbookId: 'rb',
          runbookVersion: '1',
          status: RunbookExecutionStatus.running,
          startedAt: started,
          triggeredBy: trig);
      final done = ex.copyWith(
          status: RunbookExecutionStatus.completed,
          completedAt: started,
          steps: [
            StepExecution(stepId: 's', status: StepExecutionStatus.completed)
          ],
          variables: {'a': 1},
          approvals: [
            RunbookApprovalRecord(
                stepId: 's', approver: 'x', approved: true, decidedAt: started)
          ],
          result: {'r': 1},
          error: RunbookExecutionError(
              stepId: 's', code: 'c', message: 'm', recoverable: true));
      expect(done.status, RunbookExecutionStatus.completed);
      expect(done.steps, hasLength(1));
      expect(done.error!.code, 'c');
      final same = ex.copyWith();
      expect(same.status, RunbookExecutionStatus.running);
      expect(same.runbookId, 'rb');
      expect(CheckResult(name: 'n', passed: true).name, 'n');
    });

    test('standard runbooks', () {
      final r = StandardRunbooks.philosophyAlignmentRunbook();
      expect(r['id'], 'philosophy_alignment');
      expect(r['steps'], isNotEmpty);
    });

    test('step exception text', () {
      expect(RunbookStepException('m', stepId: 's').toString(),
          'RunbookStepException: m');
    });
  });
}
