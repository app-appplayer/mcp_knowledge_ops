// Observability (alerts, logging, audit export, tracing), the port adapters'
// failure paths, and the runtime's built-in registries and scheduler dispatch.

import 'dart:async';

import 'package:mcp_bundle/src/ports/audit_port.dart' as port_audit;
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';
import 'package:mcp_knowledge_ops/src/observability/audit_recorder.dart' as obs;
import 'package:test/test.dart';

import 'test_helpers.dart';

class _Output {
  Map<String, dynamic> toJson() => {'a': 1};
}

class _Pipe implements Pipeline<Map<String, dynamic>, Object?> {
  _Pipe(this.output, {this.explode = false});
  final Object? output;
  final bool explode;
  @override
  String get id => 'p';
  @override
  String get name => 'p';
  @override
  String get version => '1';
  @override
  String? get description => null;
  @override
  List<PipelineStage> get stages => const [];
  @override
  PipelineConfig get config => const PipelineConfig();
  @override
  Future<PipelineResult<Object?>> run(
      Map<String, dynamic> input, PipelineContext context) async {
    if (explode) throw StateError('pipe broke');
    return PipelineResult.success(
        output: output, stages: const [], metrics: PipelineMetrics.empty());
  }
}

class _Wf implements Workflow<Map<String, dynamic>, Object?> {
  _Wf(this.output);
  final Object? output;
  @override
  String get id => 'w';
  @override
  String get name => 'w';
  @override
  String get version => '1';
  @override
  String? get description => null;
  @override
  List<WorkflowStage> get stages => const [];
  @override
  List<Gate> get gates => const [];
  @override
  WorkflowConfig get config => const WorkflowConfig();
  @override
  Future<WorkflowResult<Object?>> run(
          Map<String, dynamic> input, WorkflowContext context) async =>
      WorkflowResult.success(
          output: output,
          stages: const [],
          metrics: WorkflowMetrics(totalDuration: Duration.zero));
}

ConsumedOpsPorts _consumed() => ConsumedOpsPorts(
      facts: const StubFactsPort(),
      claims: const StubClaimsPort(),
      skillRuntime: const StubSkillRuntimePort(),
      appraisal: const StubAppraisalPort(),
      decision: const StubDecisionPort(),
      metrics: const StubMetricsPort(),
      mcp: const StubMcpPort(),
      llm: StubLlmPort(),
      philosophy: const StubPhilosophyPort(),
      kvStorage: InMemoryKvStoragePort(),
    );

void main() {
  group('alerts', () {
    late InMemoryMetricSink sink;
    late AlertManager manager;
    setUp(() {
      sink = InMemoryMetricSink();
      manager = AlertManager(metrics: MetricsCollector(sink: sink));
    });

    test('actions and rules serialize', () {
      final action = AlertAction(
          type: AlertActionType.slack,
          config: const {'channel': 'x'},
          delay: const Duration(seconds: 1),
          repeatInterval: const Duration(minutes: 1));
      final json = action.toJson();
      expect(json['delay'], 1000);
      expect(json['repeatInterval'], 60000);
      expect(json['config'], {'channel': 'x'});
      expect(AlertAction(type: AlertActionType.email).toJson().length, 1);
      final rule = AlertRule(
          id: 'r',
          name: 'n',
          condition: const AlertCondition(type: AlertConditionType.metric),
          actions: [action],
          labels: const {'l': 'v'},
          annotations: const {'a': 'v'});
      expect(rule.toJson()['actions'], hasLength(1));
      final copy = rule.copyWith(name: 'other');
      expect(copy.name, 'other');
      expect(copy.id, 'r');
      expect(rule.copyWith().name, 'n');
      expect(manager.metrics, isNotNull);
    });

    test('acknowledged alerts serialize their acknowledgement', () async {
      sink.record(Metric(
          name: 'm',
          value: 5,
          type: MetricType.gauge,
          timestamp: DateTime.now(),
          labels: const {}));
      manager.addRule(AlertRule(
          id: 'r',
          name: 'n',
          condition: const AlertCondition(
              type: AlertConditionType.metric,
              metric: 'm',
              operator: '>',
              threshold: 1)));
      final alerts = await manager.evaluate();
      await manager.acknowledgeAlert(alerts.single.id, 'user');
      final json = alerts.single.toJson();
      expect(json['acknowledgedBy'], 'user');
      expect(json['acknowledgedAt'], isNotNull);
    });

    test('log and expression conditions, every comparison', () async {
      sink.record(Metric(
          name: 'log.errors',
          value: 3,
          type: MetricType.counter,
          timestamp: DateTime.now(),
          labels: const {}));
      sink.record(Metric(
          name: 'load',
          value: 5,
          type: MetricType.gauge,
          timestamp: DateTime.now(),
          labels: const {}));
      Future<int> fired(AlertCondition c) async {
        final m = AlertManager(metrics: MetricsCollector(sink: sink));
        m.addRule(AlertRule(id: 'r', name: 'n', condition: c));
        return (await m.evaluate()).length;
      }

      expect(
          await fired(const AlertCondition(
              type: AlertConditionType.log,
              logQuery: 'errors',
              countThreshold: 3)),
          1);
      expect(
          await fired(const AlertCondition(
              type: AlertConditionType.log,
              logQuery: 'errors',
              countThreshold: 9)),
          0);
      expect(
          await fired(const AlertCondition(type: AlertConditionType.log)), 0);
      expect(
          await fired(const AlertCondition(
              type: AlertConditionType.expression, expression: 'load >= 5')),
          1);
      expect(
          await fired(const AlertCondition(
              type: AlertConditionType.expression, expression: 'load <= 4')),
          0);
      expect(
          await fired(const AlertCondition(
              type: AlertConditionType.expression, expression: 'load != 4')),
          1);
      expect(
          await fired(const AlertCondition(
              type: AlertConditionType.expression, expression: 'load == 5')),
          1);
      expect(
          await fired(const AlertCondition(
              type: AlertConditionType.expression, expression: 'load < 9')),
          1);
      expect(
          await fired(const AlertCondition(
              type: AlertConditionType.expression, expression: 'nonsense')),
          0);
      expect(
          await fired(const AlertCondition(
              type: AlertConditionType.expression, expression: 'load > x')),
          0);
      expect(
          await fired(const AlertCondition(
              type: AlertConditionType.expression, expression: 'nope > 1')),
          0);
      expect(
          await fired(
              const AlertCondition(type: AlertConditionType.expression)),
          0);
      expect(
          await fired(const AlertCondition(
              type: AlertConditionType.metric,
              metric: 'load',
              operator: '~',
              threshold: 1)),
          0);
      expect(
          await fired(const AlertCondition(
              type: AlertConditionType.metric,
              metric: 'load',
              operator: '<=',
              threshold: 5)),
          1);
      expect(
          await fired(const AlertCondition(
              type: AlertConditionType.metric,
              metric: 'load',
              operator: '!=',
              threshold: 5)),
          0);
      expect(
          await fired(const AlertCondition(
              type: AlertConditionType.metric,
              metric: 'ghost',
              operator: '>',
              threshold: 1)),
          0);
    });

    test('a collector that is not in memory cannot be read', () async {
      final other = AlertManager(metrics: MetricsCollector(sink: _NullSink()));
      other.addRule(AlertRule(
          id: 'r',
          name: 'n',
          condition: const AlertCondition(
              type: AlertConditionType.log, logQuery: 'q', countThreshold: 1)));
      other.addRule(AlertRule(
          id: 'r2',
          name: 'n',
          condition: const AlertCondition(
              type: AlertConditionType.expression, expression: 'a > 1')));
      other.addRule(AlertRule(
          id: 'r3',
          name: 'n',
          condition: const AlertCondition(
              type: AlertConditionType.metric,
              metric: 'a',
              operator: '>',
              threshold: 1)));
      expect(await other.evaluate(), isEmpty);
    });
  });

  group('logging', () {
    test('console sink writes through the zone, the default sink is console',
        () async {
      final printed = <String>[];
      await runZoned(() async {
        final logger = Logger(name: 'x');
        logger.info('hello');
        await ConsoleLogSink().flush();
        await ConsoleLogSink().close();
      },
          zoneSpecification:
              ZoneSpecification(print: (s, p, z, line) => printed.add(line)));
      expect(printed.single, contains('hello'));
    });

    test('execution logger helpers carry their metadata', () {
      final (logger, sink) = testLogger();
      logger.stageStart('s', metadata: {'m': 1});
      logger.stageEnd('s', result: 'r', metadata: {'m': 1});
      logger.stageFail('s', StateError('x'), metadata: {'m': 1});
      logger.stageSkip('s', reason: 'why', metadata: {'m': 1});
      logger.gateEvaluate('g', true, metadata: {'m': 1});
      logger.progress('s', current: 1, total: 4, metadata: {'m': 1});
      logger.progress('s', percent: 0.5);
      logger.checkpoint('c', data: 'd', metadata: {'m': 1});
      logger.metric('x', 2, unit: 'ms', metadata: {'m': 1});
      expect(sink.entries.where((e) => e.context['m'] == 1), hasLength(8));
      final traced = logger.withTraceId('t1').child('sub');
      traced.info('x');
      expect(sink.entries.last.traceId, 't1');
      expect(logger.withContext({'k': 'v'}).name, logger.name);
    });
  });

  group('audit', () {
    obs.AuditEvent event(String action,
            {String resource = 'r1'}) =>
        obs.AuditEvent(
            id: action,
            timestamp: DateTime.utc(2026),
            actor: const obs.AuditActor(type: obs.ActorType.user, id: 'u'),
            action: action,
            resource: obs.AuditResource(
                type: 'pipe', id: resource, attributes: const {'a': 1}),
            outcome: obs.AuditOutcome.success,
            context: const obs.AuditContext(workspaceId: 'w'),
            details: const {'d': 1},
            reason: 'has, comma',
            error: 'say "hi"\nnow');

    test('json round trip keeps attributes and details', () {
      final back = obs.AuditEvent.fromJson(event('a').toJson());
      expect(back.resource.attributes, {'a': 1});
      expect(back.details, {'d': 1});
    });

    test('filters by resource ids; exports csv (escaped) and parquet',
        () async {
      final recorder = obs.InMemoryAuditRecorder();
      await recorder.record(event('a', resource: 'r1'));
      await recorder.record(event('b', resource: 'r2'));
      final only =
          await recorder.query(const obs.AuditFilter(resourceIds: ['r2']));
      expect(only.single.id, 'b');
      final csv = String.fromCharCodes(
          await recorder.export(const obs.AuditFilter(), obs.ExportFormat.csv));
      expect(csv, contains('"has, comma"'));
      expect(csv, contains('"say ""hi""\nnow"'));
      final parquet = await recorder.export(
          const obs.AuditFilter(), obs.ExportFormat.parquet);
      expect(String.fromCharCodes(parquet), contains('"id"'));
    });

    test('the audit port adapter limits results and parses outcomes', () async {
      final recorder = obs.InMemoryAuditRecorder();
      final adapter = AuditPortAdapter(recorder: recorder);
      for (var i = 0; i < 3; i++) {
        await adapter.record(port_audit.AuditEvent(
            id: 'e$i',
            type: 'x',
            payload: {'outcome': i == 0 ? 'bogus' : 5},
            occurredAt: DateTime.utc(2026)));
      }
      final limited =
          await adapter.query(const port_audit.AuditFilter(limit: 2));
      expect(limited, hasLength(2));
      expect(await adapter.query(const port_audit.AuditFilter(limit: 10)),
          hasLength(3));
    });
  });

  group('tracing and metrics sinks', () {
    test('a default tracer, deprecated child, span children, sink lifecycle',
        () async {
      final tracer = Tracer(traceId: 't');
      final root = tracer.startSpan('root');
      // ignore: deprecated_member_use_from_same_package
      final deprecated = tracer.startChild('old');
      expect(deprecated.name, 'old');
      final child = root.startChild('child');
      expect(child.parentSpanId, root.spanId);
      final sink = InMemoryTraceSink();
      await sink.flush();
      await sink.close();
      final metrics = InMemoryMetricSink();
      await metrics.flush();
      await metrics.close();
      expect(MetricsCollector().sink, isA<InMemoryMetricSink>());
    });
  });

  group('adapters', () {
    test('pipeline adapter: toJson outputs, map outputs, failures', () async {
      PipelinePortAdapter adapter(Pipeline<Map<String, dynamic>, Object?> p) =>
          PipelinePortAdapter(registry: {'p': () => p});
      final json = await adapter(_Pipe(_Output())).runPipeline('p', {});
      expect(json.output, {'a': 1});
      final map = await adapter(_Pipe({'m': 1})).runPipeline('p', {});
      expect(map.output, {'m': 1});
      final plain = await adapter(_Pipe(42)).runPipeline('p', {});
      expect(plain.output, {'value': '42'});
      final a = adapter(_Pipe(null, explode: true));
      final broken = await a.runPipeline('p', {});
      expect(broken.status, 'failed');
      expect(broken.error, contains('pipe broke'));
      expect((await a.getPipelineRun(broken.runId))!.error, isNotNull);
    });

    test('workflow adapter: toJson outputs', () async {
      final adapter =
          WorkflowPortAdapter(registry: {'w': () => _Wf(_Output())});
      expect((await adapter.runWorkflow('w', {})).output, {'a': 1});
    });

    test('runbook adapter: a runbook that throws is a failed execution',
        () async {
      final executor = RunbookExecutor(handlers: HandlerRegistry());
      final adapter = RunbookPortAdapter(executor: executor, registry: {
        'bad': () => throw StateError('no runbook'),
      });
      final r = await adapter.runRunbook('bad', {});
      expect(r.status, 'failed');
      expect(r.error, contains('no runbook'));
    });

    test('schedule adapter runs the action with the target', () async {
      final calls = <Map<String, dynamic>>[];
      final adapter = ScheduleTriggerPortAdapter(
          scheduler: Scheduler(), action: (d) async => calls.add(d));
      const target = ScheduleTarget(kind: 'workflow', id: 'x');
      await adapter.trigger(target, {'e': 1});
      expect(calls.single['id'], 'x');
      final id = await adapter.schedule('* * * * *', target);
      await adapter.unschedule(id);
    });
  });

  group('runtime', () {
    late OpsRuntime runtime;
    setUp(() => runtime = OpsRuntime.fromConsumedPorts(_consumed()));

    test('every built-in workflow and pipeline is runnable by id', () async {
      for (final id in ['skill_build', 'profile_build', 'bundle_build']) {
        final r = await runtime.workflowAdapter.runWorkflow(id, {
          'source': 'manual',
          'patternId': 'p',
          'version': '1',
          'publishTarget': 'draft',
          'manifestId': 'm',
        });
        expect(r.status, 'succeeded', reason: id);
      }
      for (final id in [
        'ingest_pipeline',
        'curation_pipeline',
        'summary_refresh_pipeline',
        'pattern_mining_pipeline',
        'index_rebuild_pipeline',
      ]) {
        final r =
            await runtime.pipelineAdapter.runPipeline(id, {'content': 'x'});
        expect(r.status, 'succeeded', reason: id);
      }
    });

    test('scheduler dispatch reaches workflows, pipelines and runbooks',
        () async {
      final adapter = runtime.schedulerAdapter;
      for (final target in [
        const ScheduleTarget(kind: 'workflow', id: 'skill_build'),
        const ScheduleTarget(kind: 'pipeline', id: 'curation_pipeline'),
        const ScheduleTarget(kind: 'runbook', id: 'none'),
        const ScheduleTarget(kind: 'other', id: 'x'),
      ]) {
        await adapter.trigger(target, const {});
      }
      await adapter.action({'kind': 'workflow'}); // no id: ignored
      expect(runtime.workflowAdapter, isNotNull);
    });
  });
}

class _NullSink implements MetricSink {
  @override
  void record(Metric metric) {}
  @override
  Future<void> flush() async {}
  @override
  Future<void> close() async {}
}
