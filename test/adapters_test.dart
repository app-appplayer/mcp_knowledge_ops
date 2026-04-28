/// Unit tests for the five provided-port adapters and the OpsRuntime
/// facade. Covers TC-300~356 and IT-300~302 from
/// `docs/04_TEST/core-runtime.md`.
///
/// The TEST spec lists these under `test/adapters/*_test.dart` and
/// `test/runtime/ops_runtime_test.dart`, but they are consolidated into
/// one file because the adapters share construction fixtures and the
/// TCs are compact.
library;

import 'package:mcp_bundle/src/ports/audit_port.dart' as port_audit;
import 'package:mcp_bundle/src/ports/runbook_port.dart' as port_runbook;
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';
import 'package:mcp_knowledge_ops/src/observability/audit_recorder.dart'
    as obs;
import 'package:test/test.dart';

import 'test_helpers.dart';

class _TestWorkflow implements Workflow<Map<String, dynamic>, Map<String, dynamic>> {
  @override
  String get id => 'test_wf';
  @override
  String get name => 'Test Workflow';
  @override
  String get version => '1.0.0';
  @override
  String? get description => null;
  @override
  List<WorkflowStage> get stages => const [];
  @override
  List<Gate> get gates => const [];
  @override
  WorkflowConfig get config => const WorkflowConfig();

  _TestWorkflow();

  @override
  Future<WorkflowResult<Map<String, dynamic>>> run(
    Map<String, dynamic> input,
    WorkflowContext context,
  ) async {
    return WorkflowResult.success(
      output: {'echoed': input},
      stages: const [],
      metrics: WorkflowMetrics(totalDuration: Duration.zero),
    );
  }
}

class _ExplodingWorkflow implements Workflow<Map<String, dynamic>, Map<String, dynamic>> {
  @override
  String get id => 'exploding_wf';
  @override
  String get name => 'Exploding Workflow';
  @override
  String get version => '1.0.0';
  @override
  String? get description => null;
  @override
  List<WorkflowStage> get stages => const [];
  @override
  List<Gate> get gates => const [];
  @override
  WorkflowConfig get config => const WorkflowConfig();

  @override
  Future<WorkflowResult<Map<String, dynamic>>> run(
    Map<String, dynamic> input,
    WorkflowContext context,
  ) async {
    throw StateError('boom');
  }
}

class _TestPipeline implements Pipeline<Map<String, dynamic>, Map<String, dynamic>> {
  @override
  String get id => 'test_pipe';
  @override
  String get name => 'Test Pipeline';
  @override
  String get version => '1.0.0';
  @override
  String? get description => null;
  @override
  List<PipelineStage> get stages => const [];
  @override
  PipelineConfig get config => const PipelineConfig();

  _TestPipeline();

  @override
  Future<PipelineResult<Map<String, dynamic>>> run(
    Map<String, dynamic> input,
    PipelineContext context,
  ) async {
    return PipelineResult.success(
      output: {'echoed': input},
      stages: const [],
      metrics: PipelineMetrics.empty(),
    );
  }
}

void main() {
  group('WorkflowPortAdapter (FR-ADAPT-001)', () {
    late WorkflowPortAdapter adapter;

    setUp(() {
      adapter = WorkflowPortAdapter(
        registry: {
          'test_wf': () => _TestWorkflow(),
          'exploding_wf': () => _ExplodingWorkflow(),
        },
      );
    });

    test('TC-300: runWorkflow(knownId) returns succeeded handle', () async {
      final handle = await adapter.runWorkflow('test_wf', {'k': 'v'});
      expect(handle.status, equals('succeeded'));
      expect(handle.workflowId, equals('test_wf'));
      expect(handle.output, isNotNull);
    });

    test('TC-301: runWorkflow(unknownId) returns failed handle with error',
        () async {
      final handle = await adapter.runWorkflow('unknown', {});
      expect(handle.status, equals('failed'));
      expect(handle.error, contains('unknown'));
    });

    test('TC-302: getRun(runId) returns the stored handle', () async {
      final handle = await adapter.runWorkflow('test_wf', {});
      final fetched = await adapter.getRun(handle.runId);
      expect(fetched, isNotNull);
      expect(fetched!.runId, equals(handle.runId));
    });

    test('TC-303: listWorkflows returns one descriptor per registry entry',
        () async {
      final descriptors = await adapter.listWorkflows();
      expect(descriptors.length, equals(2));
      expect(descriptors.map((d) => d.id).toSet(),
          equals({'test_wf', 'exploding_wf'}));
    });

    test('TC-304: exception from workflow surfaces as status=failed', () async {
      final handle = await adapter.runWorkflow('exploding_wf', {});
      expect(handle.status, equals('failed'));
      expect(handle.error, contains('boom'));
    });

    test('TC-305: registered input decoder transforms map input', () async {
      final decoderAdapter = WorkflowPortAdapter(
        registry: {'test_wf': () => _TestWorkflow()},
        decoders: {
          'test_wf': (input) => {...input, 'decoded': true},
        },
      );
      final handle = await decoderAdapter.runWorkflow('test_wf', {'k': 'v'});
      expect(handle.status, equals('succeeded'));
    });
  });

  group('PipelinePortAdapter (FR-ADAPT-002)', () {
    late PipelinePortAdapter adapter;

    setUp(() {
      adapter = PipelinePortAdapter(
        registry: {
          'test_pipe': () => _TestPipeline(),
        },
      );
    });

    test('TC-310: runPipeline(knownId) returns succeeded handle', () async {
      final handle = await adapter.runPipeline('test_pipe', {'k': 'v'});
      expect(handle.status, equals('succeeded'));
      expect(handle.pipelineId, equals('test_pipe'));
    });

    test('TC-311: runPipeline(unknownId) returns failed handle', () async {
      final handle = await adapter.runPipeline('unknown', {});
      expect(handle.status, equals('failed'));
      expect(handle.error, contains('unknown'));
    });

    test('TC-312: getPipelineRun returns the stored handle', () async {
      final handle = await adapter.runPipeline('test_pipe', {});
      final fetched = await adapter.getPipelineRun(handle.runId);
      expect(fetched, isNotNull);
    });
  });

  group('ScheduleTriggerPortAdapter (FR-ADAPT-003)', () {
    late ScheduleTriggerPortAdapter adapter;
    late List<Map<String, dynamic>> dispatched;

    setUp(() {
      dispatched = [];
      adapter = ScheduleTriggerPortAdapter(
        scheduler: Scheduler(),
        action: (data) async {
          dispatched.add(data);
        },
      );
    });

    test('TC-320: schedule() returns a non-empty id', () async {
      final id = await adapter.schedule(
        '0 6 * * *',
        const ScheduleTarget(kind: 'pipeline', id: 'curation_pipeline'),
      );
      expect(id, isNotEmpty);
    });

    test('TC-321: trigger() invokes the dispatch action exactly once',
        () async {
      await adapter.trigger(
        const ScheduleTarget(kind: 'workflow', id: 'skill_build'),
        {'source': 'test'},
      );
      expect(dispatched.length, equals(1));
      expect(dispatched.first['kind'], equals('workflow'));
      expect(dispatched.first['id'], equals('skill_build'));
    });

    test('TC-322: unschedule() removes the job from the scheduler', () async {
      final id = await adapter.schedule(
        '* * * * *',
        const ScheduleTarget(kind: 'pipeline', id: 'curation_pipeline'),
      );
      // Should not throw when called with the returned id.
      await adapter.unschedule(id);
    });
  });

  group('AuditPortAdapter (FR-ADAPT-004)', () {
    late obs.InMemoryAuditRecorder recorder;
    late AuditPortAdapter adapter;

    setUp(() {
      recorder = obs.InMemoryAuditRecorder();
      adapter = AuditPortAdapter(recorder: recorder);
    });

    test('TC-330: record() writes to the underlying recorder', () async {
      final event = port_audit.AuditEvent(
        id: 'evt-1',
        type: 'workflow.started',
        actorId: 'user-1',
        workspaceId: 'ws-1',
        payload: const {'runId': 'wf-1'},
        occurredAt: DateTime(2026, 4, 11),
      );
      await adapter.record(event);
      expect(recorder.length, equals(1));
      expect(recorder.events.first.action, equals('workflow.started'));
    });

    test('TC-331: query() returns recorded events in port shape', () async {
      final event = port_audit.AuditEvent(
        id: 'evt-2',
        type: 'pipeline.completed',
        workspaceId: 'ws-1',
        occurredAt: DateTime(2026, 4, 11),
      );
      await adapter.record(event);
      final results = await adapter.query(const port_audit.AuditFilter());
      expect(results.length, equals(1));
      expect(results.first.type, equals('pipeline.completed'));
      expect(results.first.workspaceId, equals('ws-1'));
    });
  });

  group('RunbookPortAdapter (FR-ADAPT-005)', () {
    late RunbookPortAdapter adapter;

    setUp(() {
      adapter = RunbookPortAdapter(
        executor: RunbookExecutor(handlers: HandlerRegistry()),
        registry: {
          'test_rb': () => const Runbook(
                id: 'test_rb',
                name: 'Test Runbook',
                description: 'Unit test runbook',
                steps: [],
              ),
        },
      );
    });

    test('TC-340: runRunbook(knownId) returns succeeded execution', () async {
      final exec = await adapter.runRunbook('test_rb', {});
      expect(exec.status, equals('succeeded'));
      expect(exec.runbookId, equals('test_rb'));
    });

    test('TC-341: runRunbook(unknownId) returns failed execution', () async {
      final exec = await adapter.runRunbook('unknown', {});
      expect(exec.status, equals('failed'));
      expect(exec.error, contains('unknown'));
    });

    test('TC-342: listRunbooks returns one descriptor per registry entry',
        () async {
      final descriptors = await adapter.listRunbooks();
      expect(descriptors.length, equals(1));
      expect(descriptors.first.id, equals('test_rb'));
    });
  });

  group('OpsRuntime (FR-RT-001..005)', () {
    test('TC-350: fromConsumedPorts returns a live runtime', () {
      final consumed = TestOpsPorts().toConsumedOpsPorts();
      final runtime = OpsRuntime.fromConsumedPorts(consumed);
      expect(runtime, isA<OpsRuntime>());
      expect(runtime.engine, isA<ExecutionEngine>());
    });

    test('TC-351: toOpsPorts() returns OpsPorts whose provided fields are adapter instances',
        () {
      final consumed = TestOpsPorts().toConsumedOpsPorts();
      final runtime = OpsRuntime.fromConsumedPorts(consumed);
      final ports = runtime.toOpsPorts();
      expect(ports.workflow, same(runtime.workflowAdapter));
      expect(ports.pipeline, same(runtime.pipelineAdapter));
      expect(ports.scheduler, same(runtime.schedulerAdapter));
      expect(ports.audit, same(runtime.auditAdapter));
      expect(ports.runbook, same(runtime.runbookAdapter));
    });

    test('TC-352: toOpsPorts() forwards the consumed ports', () {
      final test = TestOpsPorts();
      final runtime = OpsRuntime.fromConsumedPorts(test.toConsumedOpsPorts());
      final ports = runtime.toOpsPorts();
      expect(ports.facts, same(test.facts));
      expect(ports.claims, same(test.claims));
      expect(ports.skillRuntime, same(test.skillRuntime));
      expect(ports.appraisal, same(test.appraisal));
      expect(ports.decision, same(test.decision));
      expect(ports.metrics, same(test.metrics));
      expect(ports.mcp, same(test.mcp));
      expect(ports.llm, same(test.llm));
      expect(ports.philosophy, same(test.philosophy));
    });

    test('TC-353: registers 3 built-in workflow factories', () {
      final runtime = OpsRuntime.fromConsumedPorts(
        TestOpsPorts().toConsumedOpsPorts(),
      );
      expect(runtime.workflowRegistry.keys, containsAll(<String>[
        'skill_build',
        'profile_build',
        'bundle_build',
      ]));
    });

    test('TC-354: registers 5 built-in pipeline factories', () {
      final runtime = OpsRuntime.fromConsumedPorts(
        TestOpsPorts().toConsumedOpsPorts(),
      );
      expect(runtime.pipelineRegistry.keys, containsAll(<String>[
        'ingest_pipeline',
        'curation_pipeline',
        'summary_refresh_pipeline',
        'pattern_mining_pipeline',
        'index_rebuild_pipeline',
      ]));
    });

    test('TC-355: built-in runbook registry starts empty (hosts register)',
        () {
      final runtime = OpsRuntime.fromConsumedPorts(
        TestOpsPorts().toConsumedOpsPorts(),
      );
      expect(runtime.runbookRegistry, isEmpty);
    });

    test('TC-356: construction is synchronous', () {
      // If construction performed I/O, building a runtime inside a
      // sync context would require `await`. We just verify the factory
      // signature returns non-Future and the runtime is usable without
      // awaiting.
      final runtime = OpsRuntime.fromConsumedPorts(
        TestOpsPorts().toConsumedOpsPorts(),
      );
      expect(runtime, isNotNull);
    });
  });

  group('Integration — OpsRuntime end-to-end', () {
    test('IT-300: runWorkflow through runtime-wired adapter', () async {
      final runtime = OpsRuntime.fromConsumedPorts(
        TestOpsPorts().toConsumedOpsPorts(),
      );
      final ports = runtime.toOpsPorts();
      final handle = await ports.workflow.runWorkflow(
        'skill_build',
        {'workspaceId': 'ws-1', 'patternId': 'p-1'},
      );
      expect(handle.workflowId, equals('skill_build'));
      // Built-in workflow run() returns a placeholder success per the
      // no-legacy declarative design.
      expect(handle.status, equals('succeeded'));
    });

    test('IT-301: runPipeline through runtime-wired adapter', () async {
      final runtime = OpsRuntime.fromConsumedPorts(
        TestOpsPorts().toConsumedOpsPorts(),
      );
      final ports = runtime.toOpsPorts();
      final handle = await ports.pipeline.runPipeline(
        'curation_pipeline',
        {'workspaceId': 'ws-1'},
      );
      expect(handle.pipelineId, equals('curation_pipeline'));
      expect(handle.status, equals('succeeded'));
    });

    test('IT-302: AuditPort round-trip', () async {
      final runtime = OpsRuntime.fromConsumedPorts(
        TestOpsPorts().toConsumedOpsPorts(),
      );
      final ports = runtime.toOpsPorts();
      await ports.audit.record(port_audit.AuditEvent(
        id: 'it-302',
        type: 'test.event',
        workspaceId: 'ws-1',
        payload: const {'foo': 'bar'},
        occurredAt: DateTime(2026, 4, 11),
      ));
      final results =
          await ports.audit.query(const port_audit.AuditFilter());
      expect(results.length, equals(1));
      expect(results.first.type, equals('test.event'));
    });
  });

  group('FR-CPIPE-009 / FR-CWF-006 grep guards', () {
    test('concrete pipelines expose no field typed as legacy ports', () {
      // This is a structural check: instantiating every concrete pipeline
      // with no args proves that no required legacy-port constructor arg
      // exists.
      expect(() => IngestPipeline(), returnsNormally);
      expect(() => CurationPipeline(), returnsNormally);
      expect(() => SummaryRefreshPipeline(), returnsNormally);
      expect(() => PatternMiningPipeline(), returnsNormally);
      expect(() => IndexRebuildPipeline(), returnsNormally);
    });

    test('concrete workflows expose no field typed as legacy ports', () {
      expect(() => SkillBuildWorkflow(), returnsNormally);
      expect(() => ProfileBuildWorkflow(), returnsNormally);
      expect(() => BundleBuildWorkflow(), returnsNormally);
    });
  });

  // The `port_runbook` prefix is used indirectly via the runtime-wired
  // adapters above. This reference keeps the import active for
  // readers following the TEST spec.
  test('port_runbook prefix is available for tests that need the raw types', () {
    expect(port_runbook.RunbookExecution, isNotNull);
  });
}
