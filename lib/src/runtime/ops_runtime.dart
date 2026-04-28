/// Ops Runtime - Facade assembling the five provided-port adapters.
///
/// See REDESIGN-PLAN.md Phase 7 §3.3 and docs/03_DDD/core-runtime.md §4.
library;

import '../adapters/workflow_port_adapter.dart';
import '../adapters/pipeline_port_adapter.dart';
import '../adapters/schedule_trigger_port_adapter.dart';
import '../adapters/audit_port_adapter.dart';
import '../adapters/runbook_port_adapter.dart';
import '../execution/execution_engine.dart';
import '../execution/handler_registry.dart';
import '../observability/audit_recorder.dart';
import '../ports/ops_port.dart';
import '../runbooks/runbook.dart';
import '../runbooks/runbook_executor.dart';
import '../scheduler/scheduler.dart';
import '../pipeline/pipelines/curation_pipeline.dart';
import '../pipeline/pipelines/index_rebuild_pipeline.dart';
import '../pipeline/pipelines/ingest_pipeline.dart';
import '../pipeline/pipelines/pattern_mining_pipeline.dart';
import '../pipeline/pipelines/summary_refresh_pipeline.dart';
import '../workflow/workflows/bundle_build_workflow.dart';
import '../workflow/workflows/profile_build_workflow.dart';
import '../workflow/workflows/skill_build_workflow.dart';

/// High-level facade that assembles the execution engine, scheduler,
/// runbook executor, audit recorder, and the five provided-port adapters.
///
/// Typical usage:
///
/// ```dart
/// final consumed = ConsumedOpsPorts(
///   facts: factGraphFactsAdapter,
///   claims: factGraphClaimsAdapter,
///   // … remaining required consumed ports
/// );
///
/// final runtime = OpsRuntime.fromConsumedPorts(consumed);
/// final ports = runtime.toOpsPorts();
///
/// final run = await ports.workflow.runWorkflow('skill_build', {
///   'patternId': 'p-1',
/// });
/// ```
class OpsRuntime {
  /// Consumed ports carried through from construction.
  final ConsumedOpsPorts consumed;

  /// Central execution engine.
  final ExecutionEngine engine;

  /// Handler registry.
  final HandlerRegistry handlers;

  /// Scheduler.
  final Scheduler scheduler;

  /// Runbook executor.
  final RunbookExecutor runbookExecutor;

  /// Audit recorder.
  final AuditRecorder auditRecorder;

  /// Workflow id → factory.
  final Map<String, WorkflowFactory> workflowRegistry;

  /// Pipeline id → factory.
  final Map<String, PipelineFactory> pipelineRegistry;

  /// Runbook id → factory.
  final Map<String, Runbook Function()> runbookRegistry;

  // ── provided-port adapters ──

  final WorkflowPortAdapter workflowAdapter;
  final PipelinePortAdapter pipelineAdapter;
  final ScheduleTriggerPortAdapter schedulerAdapter;
  final AuditPortAdapter auditAdapter;
  final RunbookPortAdapter runbookAdapter;

  OpsRuntime._({
    required this.consumed,
    required this.engine,
    required this.handlers,
    required this.scheduler,
    required this.runbookExecutor,
    required this.auditRecorder,
    required this.workflowRegistry,
    required this.pipelineRegistry,
    required this.runbookRegistry,
    required this.workflowAdapter,
    required this.pipelineAdapter,
    required this.schedulerAdapter,
    required this.auditAdapter,
    required this.runbookAdapter,
  });

  /// Construct an [OpsRuntime] from a [ConsumedOpsPorts].
  ///
  /// This is synchronous and performs no I/O.
  factory OpsRuntime.fromConsumedPorts(
    ConsumedOpsPorts consumed, {
    ExecutionEngineConfig? engineConfig,
    AuditRecorder? auditRecorder,
    HandlerRegistry? handlers,
  }) {
    final resolvedHandlers = handlers ?? HandlerRegistry();
    final resolvedAudit = auditRecorder ?? InMemoryAuditRecorder();

    // 1. Built-in workflow registry
    final workflowRegistry = <String, WorkflowFactory>{
      'skill_build': () => SkillBuildWorkflow(),
      'profile_build': () => ProfileBuildWorkflow(),
      'bundle_build': () => BundleBuildWorkflow(),
    };

    // 2. Built-in pipeline registry
    final pipelineRegistry = <String, PipelineFactory>{
      'ingest_pipeline': () => IngestPipeline(),
      'curation_pipeline': () => CurationPipeline(),
      'summary_refresh_pipeline': () => SummaryRefreshPipeline(),
      'pattern_mining_pipeline': () => PatternMiningPipeline(),
      'index_rebuild_pipeline': () => IndexRebuildPipeline(),
    };

    // 3. Built-in runbook registry — intentionally empty. Hosts register
    // their own runbooks after construction via [runbookRegistry]. The
    // legacy [StandardRunbooks] API returned shapes that do not match the
    // canonical [Runbook] type and is not used here.
    final runbookRegistry = <String, Runbook Function()>{};

    // 4. Adapter instances — the workflow/pipeline adapters are
    // constructed first so the scheduler-dispatch closure can reference
    // them. Built-in decoders map the generic `Map<String, dynamic>`
    // port input into the typed `Input` DTO each concrete pipeline /
    // workflow expects. Since the Phase 7 declarative pipelines are
    // stubs that ignore their input, the decoders return default-
    // constructed DTOs rather than parsing every field — hosts that
    // want richer input-to-DTO mapping can inject custom decoders.
    final workflowAdapter = WorkflowPortAdapter(
      registry: workflowRegistry,
      decoders: {
        'skill_build': (input) => SkillBuildInput(
              patternId: (input['patternId'] as String?) ?? '',
              skillName: input['skillName'] as String?,
              version: input['version'] as String?,
              publishTarget: input['publishTarget'] as String?,
            ),
        'profile_build': (input) => ProfileBuildInput(
              source: (input['source'] as String?) ?? 'pattern',
              patternId: input['patternId'] as String?,
              version: input['version'] as String?,
              publishTarget: input['publishTarget'] as String?,
            ),
        'bundle_build': (input) => BundleBuildInput(
              manifestId: (input['manifestId'] as String?) ?? '',
              components: const BundleComponents(),
              version: input['version'] as String?,
              publishTarget: input['publishTarget'] as String?,
            ),
      },
    );
    final pipelineAdapter = PipelinePortAdapter(
      registry: pipelineRegistry,
      decoders: {
        'ingest_pipeline': (input) => IngestInput(
              content: (input['content'] as String?) ?? '',
              sourceType: (input['sourceType'] as String?) ?? 'text',
            ),
        'curation_pipeline': (input) => const CurationInput(),
        'summary_refresh_pipeline': (input) => const SummaryRefreshInput(),
        'pattern_mining_pipeline': (input) => const PatternMiningInput(),
        'index_rebuild_pipeline': (input) => const IndexRebuildInput(),
      },
    );

    // 5. Runbook executor + adapter
    final runbookExecutor = RunbookExecutor(handlers: resolvedHandlers);
    final runbookAdapter = RunbookPortAdapter(
      executor: runbookExecutor,
      registry: runbookRegistry,
    );

    // 6. Scheduler wired with a dispatch action that routes to the
    // appropriate provided adapter based on target kind.
    final scheduler = Scheduler();
    final schedulerAdapter = ScheduleTriggerPortAdapter(
      scheduler: scheduler,
      action: (data) async {
        final kind = data['kind'] as String?;
        final id = data['id'] as String?;
        final params =
            (data['parameters'] as Map<String, dynamic>?) ?? const {};
        if (id == null) return;
        switch (kind) {
          case 'workflow':
            await workflowAdapter.runWorkflow(id, params);
            break;
          case 'pipeline':
            await pipelineAdapter.runPipeline(id, params);
            break;
          case 'runbook':
            await runbookAdapter.runRunbook(id, params);
            break;
        }
      },
    );

    // 7. Audit adapter
    final auditAdapter = AuditPortAdapter(recorder: resolvedAudit);

    // 8. Build a temporary OpsPorts with placeholder provided adapters so
    // the engine can be constructed with a full OpsPorts. The actual
    // provided-port references in OpsPorts are the same instances used
    // below, so engine handlers that reach through [OpsPorts] see the
    // real adapters.
    final consumedRef = consumed;
    final partialPorts = OpsPorts(
      workflow: workflowAdapter,
      pipeline: pipelineAdapter,
      scheduler: schedulerAdapter,
      audit: auditAdapter,
      runbook: runbookAdapter,
      facts: consumedRef.facts,
      claims: consumedRef.claims,
      skillRuntime: consumedRef.skillRuntime,
      appraisal: consumedRef.appraisal,
      decision: consumedRef.decision,
      metrics: consumedRef.metrics,
      mcp: consumedRef.mcp,
      llm: consumedRef.llm,
      philosophy: consumedRef.philosophy,
      kvStorage: consumedRef.kvStorage,
      evidence: consumedRef.evidence,
      contextBundle: consumedRef.contextBundle,
      retrieval: consumedRef.retrieval,
      approval: consumedRef.approval,
      notification: consumedRef.notification,
      event: consumedRef.event,
      metric: consumedRef.metric,
    );

    // 9. Execution engine
    final engine = ExecutionEngine(
      config: engineConfig ?? const ExecutionEngineConfig(),
      handlers: resolvedHandlers,
      ports: partialPorts,
    );

    return OpsRuntime._(
      consumed: consumed,
      engine: engine,
      handlers: resolvedHandlers,
      scheduler: scheduler,
      runbookExecutor: runbookExecutor,
      auditRecorder: resolvedAudit,
      workflowRegistry: workflowRegistry,
      pipelineRegistry: pipelineRegistry,
      runbookRegistry: runbookRegistry,
      workflowAdapter: workflowAdapter,
      pipelineAdapter: pipelineAdapter,
      schedulerAdapter: schedulerAdapter,
      auditAdapter: auditAdapter,
      runbookAdapter: runbookAdapter,
    );
  }

  /// Build the complete [OpsPorts] by combining the five provided-port
  /// adapters with the consumed ports supplied at construction.
  OpsPorts toOpsPorts() {
    return OpsPorts(
      workflow: workflowAdapter,
      pipeline: pipelineAdapter,
      scheduler: schedulerAdapter,
      audit: auditAdapter,
      runbook: runbookAdapter,
      facts: consumed.facts,
      claims: consumed.claims,
      skillRuntime: consumed.skillRuntime,
      appraisal: consumed.appraisal,
      decision: consumed.decision,
      metrics: consumed.metrics,
      mcp: consumed.mcp,
      llm: consumed.llm,
      philosophy: consumed.philosophy,
      kvStorage: consumed.kvStorage,
      evidence: consumed.evidence,
      contextBundle: consumed.contextBundle,
      retrieval: consumed.retrieval,
      approval: consumed.approval,
      notification: consumed.notification,
      event: consumed.event,
      metric: consumed.metric,
    );
  }
}

