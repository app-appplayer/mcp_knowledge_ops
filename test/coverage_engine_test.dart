// Execution engine, stage executor and parallel executor paths that the
// other tests leave out: listeners, gate modes, parallel pipelines, resume,
// review and approval stages.

import 'dart:async';

import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';
import 'package:mcp_knowledge_ops/src/execution/parallel_executor.dart'
    show DependencyGraph, Semaphore;
import 'package:mcp_knowledge_ops/src/execution/stage_executor.dart' as se;
import 'package:test/test.dart';

import 'test_helpers.dart';

class _Listener implements ExecutionEventListener {
  final events = <String>[];
  @override
  void onCheckpoint(String runId, Checkpoint checkpoint) =>
      events.add('checkpoint');
  @override
  void onGateEvaluated(String gateId, GateResult result) =>
      events.add('gate:$gateId');
  @override
  void onGateLogged(String gateId, GateResult result) =>
      events.add('gateLog:$gateId');
  @override
  void onGateWarning(String gateId, GateResult result) =>
      events.add('gateWarn:$gateId');
  @override
  void onPipelineCompleted(String p, String r, PipelineMetrics m) =>
      events.add('pipelineDone');
  @override
  void onPipelineFailed(String p, String r, Object e) =>
      events.add('pipelineFailed');
  @override
  void onPipelineStarted(String p, String r) => events.add('pipelineStart');
  @override
  void onStageCompleted(String s, String r, Duration d) =>
      events.add('stageDone:$s');
  @override
  void onStageFailed(String s, String r, Object e) =>
      events.add('stageFailed:$s');
  @override
  void onStageSkipped(String s, String r, String reason) =>
      events.add('stageSkipped:$s');
  @override
  void onStageStarted(String s, String r) => events.add('stageStart:$s');
  @override
  void onWorkflowCompleted(String w, String r, WorkflowMetrics m) =>
      events.add('workflowDone');
  @override
  void onWorkflowFailed(String w, String r, Object e) =>
      events.add('workflowFailed');
  @override
  void onWorkflowStarted(String w, String r) => events.add('workflowStart');
}

/// Approval port whose watch stream is scripted.
class _Approvals extends MockApprovalPort {
  _Approvals(this.script) : super(autoApprove: false);
  final List<ApprovalStatus> script;

  @override
  Stream<ApprovalEvent> watchApproval(String approvalId) =>
      Stream.fromIterable([
        for (final s in script)
          ApprovalEvent(
            approvalId: approvalId,
            eventType: ApprovalEventType.created,
            currentStatus: s,
            timestamp: DateTime.utc(2026),
          ),
      ]);
}

FunctionHandler _ok(String name, [dynamic out]) => FunctionHandler(
    name: name,
    handler: (input, ctx) async {
      ctx.executionContext?.setState('_output', out ?? name);
      return out ?? name;
    });

FunctionHandler _boom(String name) => FunctionHandler(
    name: name, handler: (input, ctx) async => throw StateError('boom $name'));

ExecutionContext _ctx({
  ExecutionConfig config = const ExecutionConfig(checkpointEnabled: false),
  Map<String, dynamic>? state,
}) =>
    testExecutionContext(config: config, state: state);

Gate _gate(String id, String after, GateFailure mode, {bool pass = false}) =>
    Gate(
      id: id,
      name: id,
      afterStage: after,
      onFailure: mode,
      conditions: [
        GateCondition(
            type: ConditionType.expression,
            expression: pass ? 'true' : 'false'),
      ],
    );

void main() {
  late HandlerRegistry handlers;
  late _Listener listener;

  ExecutionEngine engine({OpsPorts? ports, CheckpointManager? cp}) =>
      ExecutionEngine(
          config: const ExecutionEngineConfig(),
          handlers: handlers,
          eventListener: listener,
          checkpointManager: cp,
          ports: ports);

  setUp(() {
    handlers = HandlerRegistry()
      ..register('ok', _ok('ok'))
      ..register('boom', _boom('boom'));
    listener = _Listener();
  });

  group('executePipeline', () {
    test('listener sees failure, skip, and warn/log gates', () async {
      final result = await engine().executePipeline(
        PipelineDefinition(id: 'p', name: 'p', stages: const [
          Stage(id: 'a', name: 'a', handler: 'ok'),
          Stage(id: 'b', name: 'b', handler: 'ok', condition: 'false'),
        ], gates: [
          _gate('warn', 'a', GateFailure.warn),
          _gate('log', 'a', GateFailure.log),
        ]),
        null,
        _ctx(),
      );
      expect(result.success, isTrue);
      expect(
          listener.events,
          containsAll([
            'gateWarn:warn',
            'gateLog:log',
            'stageSkipped:b',
            'pipelineDone'
          ]));

      listener.events.clear();
      final failed = await engine().executePipeline(
        PipelineDefinition(
            id: 'p',
            name: 'p',
            stages: const [Stage(id: 'x', name: 'x', handler: 'boom')]),
        null,
        _ctx(),
      );
      expect(failed.success, isFalse);
      expect(listener.events, contains('stageFailed:x'));
    });

    test('checkpoints are saved and a run can be resumed', () async {
      final cp = InMemoryCheckpointManager();
      final e = engine(cp: cp);
      final pipeline = PipelineDefinition(id: 'p', name: 'p', stages: const [
        Stage(id: 's1', name: '1', handler: 'ok'),
        Stage(id: 's2', name: '2', handler: 'ok'),
      ]);
      final context = _ctx(
          config: const ExecutionConfig(
              checkpointEnabled: true, checkpointInterval: Duration.zero));
      await e.executePipeline(pipeline, null, context);
      expect(listener.events, contains('checkpoint'));
      final saved = await cp.loadLatest(context.runId);
      expect(saved, isNotNull);

      // A checkpoint taken after s1 resumes at s1 (the stage itself).
      await cp.save(Checkpoint(
          id: 'resume-1',
          runId: 'r2',
          name: 'n',
          state: const {},
          stageOutputs: const {},
          lastCompletedStage: 's2',
          executionState: ExecutionState.paused,
          createdAt: DateTime.now()));
      final resumed =
          await e.resumeFromCheckpoint<dynamic>(pipeline, 'resume-1');
      expect(resumed.success, isTrue);
      expect(resumed.stages, hasLength(1)); // only s2 ran
      expect((await cp.listForRun('r2', status: CheckpointStatus.resumed)),
          isNotEmpty);

      // An unknown id.
      await expectLater(e.resumeFromCheckpoint<dynamic>(pipeline, 'nope'),
          throwsA(isA<CheckpointException>()));
      // A checkpoint that is not resumable.
      await cp.save(Checkpoint(
          id: 'done-1',
          runId: 'r3',
          name: 'n',
          state: const {},
          stageOutputs: const {},
          executionState: ExecutionState.completed,
          createdAt: DateTime.now()));
      await expectLater(e.resumeFromCheckpoint<dynamic>(pipeline, 'done-1'),
          throwsA(isA<CheckpointException>()));
    });

    test('an unknown resume stage starts from the beginning; mappings apply',
        () async {
      handlers.register(
          'emit',
          FunctionHandler(
              name: 'emit',
              handler: (input, ctx) async => {'a': 1, 'b': null}));
      handlers.register(
          'echo',
          FunctionHandler(
              name: 'echo',
              handler: (input, ctx) async {
                ctx.executionContext?.setState('_output', input);
                return input;
              }));
      final pipeline = PipelineDefinition(id: 'p', name: 'p', stages: const [
        Stage(
            id: 'one',
            name: '1',
            handler: 'emit',
            outputMapping: {'a': 'mapped', 'b': 'never'}),
        Stage(
            id: 'two',
            name: '2',
            handler: 'echo',
            inputMapping: {'x': 'mapped', 'y': 'absent'}),
      ]);
      final context = ExecutionContext(
          runId: 'r',
          traceId: 't',
          workspaceId: 'w',
          asOf: DateTime.utc(2026),
          config: const ExecutionConfig(checkpointEnabled: false),
          resumeFromStage: 'no-such-stage');
      final r = await engine().executePipeline(pipeline, null, context);
      expect(r.success, isTrue);
      expect(r.stages, hasLength(2));
      expect(context.getState('mapped'), 1);
      expect(context.getState('never'), isNull);
    });
  });

  group('executePipelineParallel', () {
    test('runs independent stages, evaluates gates, succeeds', () async {
      final r = await engine().executePipelineParallel<dynamic>(
        PipelineDefinition(id: 'p', name: 'p', stages: const [
          Stage(id: 'a', name: 'a', handler: 'ok'),
          Stage(id: 'b', name: 'b', handler: 'ok'),
          Stage(id: 'c', name: 'c', handler: 'ok', dependsOn: ['a', 'b']),
        ], gates: [
          _gate('warn', 'c', GateFailure.warn),
          _gate('log', 'c', GateFailure.log),
          _gate('fine', 'c', GateFailure.block, pass: true),
        ]),
        null,
        _ctx(),
      );
      expect(r.success, isTrue);
      expect(listener.events,
          containsAll(['gateWarn:warn', 'gateLog:log', 'pipelineDone']));
    });

    test('a blocking gate and a failed stage both fail the pipeline', () async {
      final blocked = await engine().executePipelineParallel<dynamic>(
        PipelineDefinition(
            id: 'p',
            name: 'p',
            stages: const [Stage(id: 'a', name: 'a', handler: 'ok')],
            gates: [_gate('g', 'a', GateFailure.block)]),
        null,
        _ctx(),
      );
      expect(blocked.success, isFalse);

      final failed = await engine().executePipelineParallel<dynamic>(
        PipelineDefinition(id: 'p', name: 'p', stages: const [
          Stage(id: 'a', name: 'a', handler: 'boom'),
          Stage(id: 'b', name: 'b', handler: 'ok', dependsOn: ['a']),
        ]),
        null,
        _ctx(),
      );
      expect(failed.success, isFalse);
      expect(failed.error!.code, 'PARALLEL_EXECUTION_FAILED');
      expect(failed.error!.stageId, 'a');
      expect(listener.events, containsAll(['stageFailed:a', 'pipelineFailed']));
    });

    test('a dependency cycle is reported as a failure', () async {
      final r = await engine().executePipelineParallel<dynamic>(
        PipelineDefinition(id: 'p', name: 'p', stages: const [
          Stage(id: 'a', name: 'a', handler: 'ok', dependsOn: ['b']),
          Stage(id: 'b', name: 'b', handler: 'ok', dependsOn: ['a']),
        ]),
        null,
        _ctx(),
      );
      expect(r.success, isFalse);
      expect(r.error!.message, contains('Circular dependency'));
    });
  });

  group('executeWorkflow', () {
    WorkflowDefinition wf(List<WorkflowStage> stages,
            {List<Gate> gates = const []}) =>
        WorkflowDefinition(id: 'w', name: 'w', stages: stages, gates: gates);

    test('warn and log gates continue; a blocking gate fails', () async {
      final ok = await engine().executeWorkflow<dynamic>(
        wf(const [
          WorkflowStage(
              id: 't', name: 't', handler: 'ok', type: WorkflowStageType.task),
          WorkflowStage(
              id: 'g', name: 'g', handler: 'ok', type: WorkflowStageType.gate),
        ], gates: [
          _gate('warn', 't', GateFailure.warn),
          _gate('log', 't', GateFailure.log),
        ]),
        null,
        _ctx(),
      );
      expect(ok.success, isTrue);
      expect(listener.events, containsAll(['gateWarn:warn', 'gateLog:log']));
      final blocked = await engine().executeWorkflow<dynamic>(
        wf(const [
          WorkflowStage(
              id: 't', name: 't', handler: 'ok', type: WorkflowStageType.task),
        ], gates: [
          _gate('b', 't', GateFailure.block)
        ]),
        null,
        _ctx(),
      );
      expect(blocked.success, isFalse);
    });

    test('review and approval without a port stay pending; auto-approve skips',
        () async {
      for (final type in [
        WorkflowStageType.review,
        WorkflowStageType.approval
      ]) {
        final stage =
            WorkflowStage(id: 'x', name: 'x', handler: 'ok', type: type);
        final pending =
            await engine().executeWorkflow<dynamic>(wf([stage]), null, _ctx());
        expect(pending.stages.single.status, StageStatus.waitingOverride);
        final auto = await engine().executeWorkflow<dynamic>(
            wf([stage]),
            null,
            _ctx(
                config: const ExecutionConfig(
                    checkpointEnabled: false, autoApprove: true)));
        expect(auto.stages.single.status, StageStatus.skipped);
      }
    });

    test('review: approved, rejected and timed out', () async {
      Future<StageResult> run(List<ApprovalStatus> script, WorkflowStageType t,
          {Map<String, dynamic> config = const {}}) async {
        final ports = TestOpsPorts();
        final approvals = _Approvals(script);
        final opsPorts = OpsPorts(
          workflow: ports.toOpsPorts().workflow,
          pipeline: ports.toOpsPorts().pipeline,
          scheduler: ports.toOpsPorts().scheduler,
          audit: ports.toOpsPorts().audit,
          runbook: ports.toOpsPorts().runbook,
          facts: ports.facts,
          claims: ports.claims,
          skillRuntime: ports.skillRuntime,
          appraisal: ports.appraisal,
          decision: ports.decision,
          metrics: ports.metrics,
          mcp: ports.mcp,
          llm: ports.llm,
          philosophy: ports.philosophy,
          kvStorage: ports.kvStorage,
          approval: approvals,
          notification: ports.notification,
        );
        final r = await engine(ports: opsPorts).executeWorkflow<dynamic>(
            wf([
              WorkflowStage(
                  id: 'x', name: 'x', handler: 'ok', type: t, config: config)
            ]),
            null,
            _ctx(
                config: const ExecutionConfig(
                    checkpointEnabled: true,
                    checkpointInterval: Duration.zero)));
        return r.stages.single;
      }

      for (final t in [WorkflowStageType.review, WorkflowStageType.approval]) {
        expect(
            (await run([ApprovalStatus.pending, ApprovalStatus.approved], t))
                .status,
            StageStatus.completed);
        final rejected = await run([ApprovalStatus.rejected], t);
        expect(rejected.status, StageStatus.failed);
        expect(rejected.error, contains('rejected'));
        final timeout = await run([ApprovalStatus.pending], t);
        expect(timeout.status, StageStatus.failed);
        expect(timeout.error, contains('timeout'));
      }
      // Reviewers, approvers and a policy come from the stage config.
      final configured =
          await run([ApprovalStatus.approved], WorkflowStageType.approval,
              config: {
                'approvers': ['a'],
                'policy': 'anyOne'
              });
      expect(configured.status, StageStatus.completed);
      final reviewers =
          await run([ApprovalStatus.approved], WorkflowStageType.review,
              config: {
                'reviewers': ['r']
              });
      expect(reviewers.status, StageStatus.completed);
      final unknownPolicy = await run(
          [ApprovalStatus.approved], WorkflowStageType.approval,
          config: {'policy': 'no-such-policy'});
      expect(unknownPolicy.status, StageStatus.completed);
    });
  });

  group('stage executor', () {
    StageExecutor exec() => StageExecutor(handlers: handlers);

    test('conditions: negation, state values, absent', () async {
      Future<StageStatus> run(String cond, Map<String, dynamic> state) async =>
          (await exec().execute(
                  Stage(id: 's', name: 's', handler: 'ok', condition: cond),
                  null,
                  _ctx(state: state)))
              .status;
      expect(await run('!missing', {}), StageStatus.completed);
      expect(await run('!present', {'present': 1}), StageStatus.skipped);
      expect(await run('flag', {'flag': true}), StageStatus.completed);
      expect(await run('flag', {'flag': false}), StageStatus.skipped);
      expect(await run('flag', {'flag': ''}), StageStatus.skipped);
      expect(await run('flag', {'flag': 'x'}), StageStatus.completed);
      expect(await run('flag', {'flag': 0}), StageStatus.skipped);
      expect(await run('flag', {'flag': 2}), StageStatus.completed);
      expect(
          await run('flag', {
            'flag': const [1]
          }),
          StageStatus.completed);
      expect(await run('flag', {}), StageStatus.skipped);
      expect(await run('true', {}), StageStatus.completed);
    });

    test('failure modes', () async {
      Future<StageResult> run(OnFailure f) => exec().execute(
          Stage(id: 's', name: 's', handler: 'boom', onFailure: f),
          null,
          _ctx());
      expect((await run(OnFailure.fail)).status, StageStatus.failed);
      expect((await run(OnFailure.skip)).status, StageStatus.skipped);
      expect((await run(OnFailure.manualOverride)).status,
          StageStatus.waitingOverride);
      expect((await run(OnFailure.retry)).status, StageStatus.failed);
    });

    test('a slow handler times out; a missing handler fails', () async {
      handlers.register(
          'slow',
          FunctionHandler(
              name: 'slow',
              handler: (i, c) =>
                  Future<dynamic>.delayed(const Duration(milliseconds: 200))));
      final timeout = await exec().execute(
          const Stage(
              id: 's',
              name: 's',
              handler: 'slow',
              timeout: Duration(milliseconds: 20)),
          null,
          _ctx());
      expect(timeout.status, StageStatus.failed);
      expect(timeout.error, contains('timed out'));
      final missing = await exec().execute(
          const Stage(id: 's', name: 's', handler: 'nope'), null, _ctx());
      expect(missing.error, contains('Handler not found'));
    });

    test('retries wait and return the last failure; zero attempts', () async {
      var n = 0;
      handlers.register(
          'flaky',
          FunctionHandler(
              name: 'flaky',
              handler: (i, c) async {
                if (++n < 3) throw StateError('x');
                return 'ok';
              }));
      final r = await exec().executeWithRetry(
          const Stage(
              id: 's',
              name: 's',
              handler: 'flaky',
              retryConfig: StageRetryConfig(
                  maxAttempts: 3, initialDelay: Duration(milliseconds: 1))),
          null,
          _ctx());
      expect(r.status, StageStatus.completed);
      expect(n, 3);
      final failed = await exec().executeWithRetry(
          const Stage(
              id: 's',
              name: 's',
              handler: 'boom',
              retryConfig: StageRetryConfig(
                  maxAttempts: 2, initialDelay: Duration(milliseconds: 1))),
          null,
          _ctx());
      expect(failed.status, StageStatus.failed);
      final none = await exec().executeWithRetry(
          const Stage(
              id: 's',
              name: 's',
              handler: 'ok',
              retryConfig: StageRetryConfig(maxAttempts: 0)),
          null,
          _ctx());
      expect(none.error, 'Max retries exceeded');
    });

    test('exception text', () {
      final e =
          se.StageException.fromError('s', StateError('x'), StackTrace.empty);
      expect(e.stageId, 's');
      expect(e.toString(), startsWith('StageException:'));
      expect(TimeoutException('t').toString(), 'TimeoutException: t');
      expect(
          RetryableException('s', 'm').toString(), 'RetryableException(s): m');
    });
  });

  group('parallel executor', () {
    ParallelStageExecutor par({int max = 2}) => ParallelStageExecutor(
        stageExecutor: StageExecutor(handlers: handlers),
        maxConcurrency: max,
        eventListener: listener);

    test('a failure that does not block lets later levels see the dependency',
        () async {
      final results = await par().executeParallel([
        const Stage(
            id: 'a',
            name: 'a',
            handler: 'boom',
            onFailure: OnFailure.manualOverride),
        const Stage(id: 'b', name: 'b', handler: 'ok', dependsOn: ['a']),
      ], _ctx());
      final byId = {for (final r in results) r.stageId: r};
      expect(byId['a']!.status, StageStatus.waitingOverride);
      expect(byId['b']!.status, StageStatus.skipped);
      expect(byId['b']!.error, 'Dependency not satisfied');
    });

    test('a blocking failure cancels later levels', () async {
      final results = await par().executeParallel([
        const Stage(id: 'a', name: 'a', handler: 'boom'),
        const Stage(id: 'b', name: 'b', handler: 'ok', dependsOn: ['a']),
        const Stage(id: 'c', name: 'c', handler: 'ok', dependsOn: ['b']),
      ], _ctx());
      final byId = {for (final r in results) r.stageId: r};
      expect(byId['b']!.error, 'Cancelled due to upstream failure');
      expect(byId['c']!.status, StageStatus.skipped);
    });

    test('more stages than permits wait their turn; default input', () async {
      final order = <String>[];
      handlers.register(
          'wait',
          FunctionHandler(
              name: 'wait',
              handler: (i, c) async {
                order.add('in:${c.stageId}');
                await Future<void>.delayed(const Duration(milliseconds: 10));
                order.add('out:${c.stageId}');
                return i;
              }));
      final results = await par(max: 1).executeParallel([
        for (final id in ['a', 'b', 'c'])
          Stage(id: id, name: id, handler: 'wait'),
      ], _ctx(state: {'input': 'x'}));
      expect(results.every((r) => r.status == StageStatus.completed), isTrue);
      // With one permit no stage starts before the previous one is done.
      expect(order, ['in:a', 'out:a', 'in:b', 'out:b', 'in:c', 'out:c']);
    });

    test('a cycle is rejected', () async {
      await expectLater(
          par().executeParallel([
            const Stage(id: 'a', name: 'a', handler: 'ok', dependsOn: ['b']),
            const Stage(id: 'b', name: 'b', handler: 'ok', dependsOn: ['a']),
          ], _ctx()),
          throwsA(isA<ParallelExecutionException>()));
      expect(ParallelExecutionException('m').toString(),
          'ParallelExecutionException: m');
    });

    test('the dependency graph and semaphore helpers', () {
      final g = DependencyGraph(const [
        Stage(id: 'a', name: 'a', handler: 'ok'),
        Stage(id: 'b', name: 'b', handler: 'ok', dependsOn: ['a']),
      ]);
      expect(g.getDependents('a'), ['b']);
      expect(g.getDependencies('b'), ['a']);
      expect(g.getDependents('zzz'), isEmpty);
      expect(g.getDependencies('zzz'), isEmpty);
      expect(g.getExecutionLevels(), [
        ['a'],
        ['b']
      ]);
      final cyclic = DependencyGraph(const [
        Stage(id: 'a', name: 'a', handler: 'ok', dependsOn: ['b']),
        Stage(id: 'b', name: 'b', handler: 'ok', dependsOn: ['a']),
      ]);
      expect(cyclic.detectCycles(), isNotNull);
      expect(() => cyclic.getExecutionLevels(),
          throwsA(isA<ParallelExecutionException>()));

      final s = Semaphore(1);
      expect(s.available, 1);
      expect(s.tryAcquire(), isTrue);
      expect(s.inUse, 1);
      expect(s.tryAcquire(), isFalse);
      s.release();
      expect(s.available, 1);
    });
  });
}
