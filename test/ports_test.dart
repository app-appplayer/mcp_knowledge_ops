/// Tests for the OpsPorts aggregation container.
///
/// Per REDESIGN-PLAN.md Phase 7 (no-legacy) this suite verifies:
/// - 5 provided ports are required at construction
/// - 10 consumed ports are required at construction
/// - 7 optional ports default to null
/// - the metric (instrumentation, singular) vs metrics (evaluation,
///   plural) disambiguation holds
import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

void main() {
  group('OpsPorts', () {
    test('construction with all required ports', () {
      final testPorts = TestOpsPorts();
      final ports = testPorts.toOpsPorts();

      // Provided (5)
      expect(ports.workflow, isA<WorkflowPort>());
      expect(ports.pipeline, isA<PipelinePort>());
      expect(ports.scheduler, isA<ScheduleTriggerPort>());
      expect(ports.audit, isNotNull);
      expect(ports.runbook, isNotNull);

      // Required consumed (10)
      expect(ports.facts, isA<FactsPort>());
      expect(ports.claims, isA<ClaimsPort>());
      expect(ports.skillRuntime, isA<SkillRuntimePort>());
      expect(ports.appraisal, isA<AppraisalPort>());
      expect(ports.decision, isA<DecisionPort>());
      expect(ports.metrics, isA<MetricsPort>());
      expect(ports.mcp, isA<McpPort>());
      expect(ports.llm, isA<LlmPort>());
      expect(ports.philosophy, isA<PhilosophyPort>());
      expect(ports.kvStorage, isA<KvStoragePort>());
    });

    test('optional consumed ports default to null when omitted', () {
      final ports = OpsPorts(
        workflow: TestOpsPorts().toOpsPorts().workflow,
        pipeline: TestOpsPorts().toOpsPorts().pipeline,
        scheduler: TestOpsPorts().toOpsPorts().scheduler,
        audit: TestOpsPorts().toOpsPorts().audit,
        runbook: TestOpsPorts().toOpsPorts().runbook,
        facts: MockFactsPort(),
        claims: MockClaimsPort(),
        skillRuntime: MockSkillRuntimePort(),
        appraisal: MockAppraisalPort(),
        decision: MockDecisionPort(),
        metrics: MockMetricsPort(),
        mcp: MockMcpPort(),
        llm: MockLlmPort(),
        philosophy: MockPhilosophyPort(),
        kvStorage: MockKvStorage(),
      );

      expect(ports.evidence, isNull);
      expect(ports.contextBundle, isNull);
      expect(ports.retrieval, isNull);
      expect(ports.approval, isNull);
      expect(ports.notification, isNull);
      expect(ports.event, isNull);
      expect(ports.metric, isNull);
    });

    test('TestOpsPorts wires all optional ports', () {
      final ports = TestOpsPorts().toOpsPorts();

      expect(ports.notification, isNotNull);
      expect(ports.approval, isNotNull);
      expect(ports.event, isNotNull);
      expect(ports.metric, isNotNull);
    });

    test('metrics (plural, required) vs metric (singular, optional)', () {
      final ports = TestOpsPorts().toOpsPorts();
      expect(ports.metrics, isA<MetricsPort>());
      expect(ports.metric, isA<MetricPort?>());
    });

    test('ConsumedOpsPorts carries only the consumed ports', () {
      final consumed = TestOpsPorts().toConsumedOpsPorts();

      expect(consumed.facts, isA<FactsPort>());
      expect(consumed.claims, isA<ClaimsPort>());
      expect(consumed.skillRuntime, isA<SkillRuntimePort>());
      expect(consumed.appraisal, isA<AppraisalPort>());
      expect(consumed.decision, isA<DecisionPort>());
      expect(consumed.metrics, isA<MetricsPort>());
      expect(consumed.mcp, isA<McpPort>());
      expect(consumed.llm, isA<LlmPort>());
      expect(consumed.philosophy, isA<PhilosophyPort>());
      expect(consumed.kvStorage, isA<KvStoragePort>());
    });
  });

  group('OpsRuntime', () {
    test('fromConsumedPorts returns a runtime with non-stub adapters', () {
      final consumed = TestOpsPorts().toConsumedOpsPorts();
      final runtime = OpsRuntime.fromConsumedPorts(consumed);

      expect(runtime.workflowAdapter, isA<WorkflowPortAdapter>());
      expect(runtime.pipelineAdapter, isA<PipelinePortAdapter>());
      expect(runtime.schedulerAdapter, isA<ScheduleTriggerPortAdapter>());
      expect(runtime.auditAdapter, isA<AuditPortAdapter>());
      expect(runtime.runbookAdapter, isA<RunbookPortAdapter>());
    });

    test('toOpsPorts returns the adapter instances as provided ports', () {
      final consumed = TestOpsPorts().toConsumedOpsPorts();
      final runtime = OpsRuntime.fromConsumedPorts(consumed);
      final ports = runtime.toOpsPorts();

      expect(ports.workflow, same(runtime.workflowAdapter));
      expect(ports.pipeline, same(runtime.pipelineAdapter));
      expect(ports.scheduler, same(runtime.schedulerAdapter));
      expect(ports.audit, same(runtime.auditAdapter));
      expect(ports.runbook, same(runtime.runbookAdapter));
    });

    test('registers 3 built-in workflows', () {
      final consumed = TestOpsPorts().toConsumedOpsPorts();
      final runtime = OpsRuntime.fromConsumedPorts(consumed);
      expect(
          runtime.workflowRegistry.keys,
          containsAll(<String>[
            'skill_build',
            'profile_build',
            'bundle_build',
          ]));
    });

    test('registers 5 built-in pipelines', () {
      final consumed = TestOpsPorts().toConsumedOpsPorts();
      final runtime = OpsRuntime.fromConsumedPorts(consumed);
      expect(
          runtime.pipelineRegistry.keys,
          containsAll(<String>[
            'ingest_pipeline',
            'curation_pipeline',
            'summary_refresh_pipeline',
            'pattern_mining_pipeline',
            'index_rebuild_pipeline',
          ]));
    });
  });
}
