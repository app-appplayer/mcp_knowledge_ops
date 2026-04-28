/// Ops Ports - Aggregated container for the standard ports consumed and
/// provided by `mcp_knowledge_ops`.
///
/// Per REDESIGN-PLAN.md Phase 7 (no-legacy), this module re-exports only
/// the capability-named standard ports from `mcp_bundle`. The legacy
/// consumer-sliced ports (`FactGraphPort`/`SkillPort`/`ProfilePort`/
/// `BundlePort` from `mcp_bundle/src/ports/ops_ports.dart`) are not
/// imported, re-exported, or referenced anywhere in this package.
library;

// ── provided ports (implemented by MOD-CORE-011 adapters) ─────────────────
export 'package:mcp_bundle/src/ports/workflow_port.dart';
export 'package:mcp_bundle/src/ports/pipeline_port.dart';
export 'package:mcp_bundle/src/ports/schedule_trigger_port.dart';
// Hide AuditEvent / AuditFilter because the internal
// `observability/audit_recorder.dart` defines richer types with the
// same names. Hosts needing the standard shapes import the port file
// directly or use `AuditPortAdapter`.
export 'package:mcp_bundle/src/ports/audit_port.dart'
    hide AuditEvent, AuditFilter;
// Hide RunbookExecution / RunbookDescriptor similarly — the internal
// `runbooks/runbook.dart` uses a different `RunbookExecution` class.
export 'package:mcp_bundle/src/ports/runbook_port.dart'
    hide RunbookExecution, RunbookDescriptor;

// ── data/context consumed ports ───────────────────────────────────────────
export 'package:mcp_bundle/src/ports/facts_port.dart';
export 'package:mcp_bundle/src/ports/claims_port.dart';
export 'package:mcp_bundle/src/ports/evidence_port.dart';
export 'package:mcp_bundle/src/ports/context_bundle_port.dart';
export 'package:mcp_bundle/src/ports/retrieval_port.dart';

// ── skill + MCP consumed ports ────────────────────────────────────────────
export 'package:mcp_bundle/src/ports/skill_runtime_port.dart';
export 'package:mcp_bundle/src/ports/mcp_port.dart';

// ── profile consumed ports ────────────────────────────────────────────────
export 'package:mcp_bundle/src/ports/appraisal_port.dart';
export 'package:mcp_bundle/src/ports/decision_port.dart';
export 'package:mcp_bundle/src/ports/metrics_port.dart';

// ── LLM / storage / cross-cutting ─────────────────────────────────────────
export 'package:mcp_bundle/src/ports/llm_port.dart';
export 'package:mcp_bundle/src/ports/storage_port.dart';
export 'package:mcp_bundle/src/ports/metric_port.dart';
export 'package:mcp_bundle/src/ports/event_port.dart';
export 'package:mcp_bundle/src/ports/notification_port.dart';
export 'package:mcp_bundle/src/ports/approval_port.dart';

// Philosophy port (hide PipelineContext to avoid clash with local type in
// `pipeline.dart`).
export 'package:mcp_bundle/src/ports/philosophy_port.dart' hide PipelineContext;

// ── shared DTOs used by handlers ──────────────────────────────────────────
export 'package:mcp_bundle/src/types/claim.dart';
export 'package:mcp_bundle/src/types/period.dart';
export 'package:mcp_bundle/src/types/appraisal_result.dart';
export 'package:mcp_bundle/src/types/decision_guidance.dart';
// `SkillResult.Artifact` is hidden because the execution-result module
// defines its own `Artifact` type.
export 'package:mcp_bundle/src/types/skill_result.dart' hide Artifact;

// ── internal imports for the OpsPorts container ───────────────────────────
import 'package:mcp_bundle/src/ports/workflow_port.dart';
import 'package:mcp_bundle/src/ports/pipeline_port.dart';
import 'package:mcp_bundle/src/ports/schedule_trigger_port.dart';
import 'package:mcp_bundle/src/ports/audit_port.dart';
import 'package:mcp_bundle/src/ports/runbook_port.dart';
import 'package:mcp_bundle/src/ports/facts_port.dart';
import 'package:mcp_bundle/src/ports/claims_port.dart';
import 'package:mcp_bundle/src/ports/evidence_port.dart';
import 'package:mcp_bundle/src/ports/context_bundle_port.dart';
import 'package:mcp_bundle/src/ports/retrieval_port.dart';
import 'package:mcp_bundle/src/ports/skill_runtime_port.dart';
import 'package:mcp_bundle/src/ports/mcp_port.dart';
import 'package:mcp_bundle/src/ports/appraisal_port.dart';
import 'package:mcp_bundle/src/ports/decision_port.dart';
import 'package:mcp_bundle/src/ports/metrics_port.dart';
import 'package:mcp_bundle/src/ports/llm_port.dart';
import 'package:mcp_bundle/src/ports/storage_port.dart';
import 'package:mcp_bundle/src/ports/metric_port.dart';
import 'package:mcp_bundle/src/ports/event_port.dart';
import 'package:mcp_bundle/src/ports/notification_port.dart';
import 'package:mcp_bundle/src/ports/approval_port.dart';
import 'package:mcp_bundle/src/ports/philosophy_port.dart';

/// Aggregated port container for `mcp_knowledge_ops`.
///
/// Structure (REDESIGN-PLAN.md Phase 7 §3.5):
///   1. Five **provided** ports implemented by this package via adapters
///      (see `src/adapters/`). They are required.
///   2. Ten **required consumed** ports supplied by other packages.
///   3. Seven **optional consumed** ports.
class OpsPorts {
  // ── 1. Provided ports (adapters implemented in src/adapters/) ──

  /// Workflow execution facade.
  final WorkflowPort workflow;

  /// Pipeline execution facade.
  final PipelinePort pipeline;

  /// Cron/event/deadline scheduling facade.
  final ScheduleTriggerPort scheduler;

  /// Audit event recording/query facade.
  final AuditPort audit;

  /// Runbook execution facade.
  final RunbookPort runbook;

  // ── 2. Required consumed ports (capability-named) ──

  /// Fact CRUD over the fact graph.
  final FactsPort facts;

  /// Claim CRUD and validation.
  final ClaimsPort claims;

  /// Skill execution runtime.
  final SkillRuntimePort skillRuntime;

  /// Profile dimension appraisal.
  final AppraisalPort appraisal;

  /// Profile policy decision.
  final DecisionPort decision;

  /// Profile evaluation metrics (plural — evaluation layer).
  final MetricsPort metrics;

  /// MCP tool/resource access.
  final McpPort mcp;

  /// LLM completion.
  final LlmPort llm;

  /// Philosophy evaluation & intervention.
  final PhilosophyPort philosophy;

  /// Key-value storage for checkpoints, rollback, dedupe.
  final KvStoragePort kvStorage;

  // ── 3. Optional consumed ports ──

  /// Evidence fragment extraction.
  final EvidencePort? evidence;

  /// Context bundle assembly for LLM prompts.
  final ContextBundlePort? contextBundle;

  /// Knowledge retrieval / RAG.
  final RetrievalPort? retrieval;

  /// Approval routing (human-in-the-loop).
  final ApprovalPort? approval;

  /// Notification delivery.
  final NotificationPort? notification;

  /// Event pub/sub.
  final EventPort? event;

  /// Instrumentation-layer metric export (singular — distinct from
  /// evaluation-layer [MetricsPort]).
  final MetricPort? metric;

  const OpsPorts({
    required this.workflow,
    required this.pipeline,
    required this.scheduler,
    required this.audit,
    required this.runbook,
    required this.facts,
    required this.claims,
    required this.skillRuntime,
    required this.appraisal,
    required this.decision,
    required this.metrics,
    required this.mcp,
    required this.llm,
    required this.philosophy,
    required this.kvStorage,
    this.evidence,
    this.contextBundle,
    this.retrieval,
    this.approval,
    this.notification,
    this.event,
    this.metric,
  });
}

/// Value type holding only the consumed ports (10 required + 7 optional).
///
/// Used by `OpsRuntime.fromConsumedPorts` to defer construction of the
/// five provided-port adapters. After runtime assembly, combining
/// [ConsumedOpsPorts] with the five adapters produces a full [OpsPorts].
class ConsumedOpsPorts {
  final FactsPort facts;
  final ClaimsPort claims;
  final SkillRuntimePort skillRuntime;
  final AppraisalPort appraisal;
  final DecisionPort decision;
  final MetricsPort metrics;
  final McpPort mcp;
  final LlmPort llm;
  final PhilosophyPort philosophy;
  final KvStoragePort kvStorage;

  final EvidencePort? evidence;
  final ContextBundlePort? contextBundle;
  final RetrievalPort? retrieval;
  final ApprovalPort? approval;
  final NotificationPort? notification;
  final EventPort? event;
  final MetricPort? metric;

  const ConsumedOpsPorts({
    required this.facts,
    required this.claims,
    required this.skillRuntime,
    required this.appraisal,
    required this.decision,
    required this.metrics,
    required this.mcp,
    required this.llm,
    required this.philosophy,
    required this.kvStorage,
    this.evidence,
    this.contextBundle,
    this.retrieval,
    this.approval,
    this.notification,
    this.event,
    this.metric,
  });
}
