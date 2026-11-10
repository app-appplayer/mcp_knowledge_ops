/// MCP Knowledge Operations - Orchestration layer for MakeMind.
///
/// This library provides orchestration operations for MCP applications,
/// including pipelines, workflows, scheduling, runbooks, and observability.
///
/// ## Architecture
///
/// mcp_knowledge_ops is the stateless orchestration layer that coordinates
/// operations across the MakeMind ecosystem. All persistence is delegated
/// to mcp_fact_graph.
///
/// ## Core Components
///
/// - **Execution Engine**: Central coordinator for pipeline/workflow execution
/// - **Pipelines**: Data processing pipelines with stages and gates
/// - **Workflows**: Build/release workflows with reviews and approvals
/// - **Scheduler**: Trigger management with cron, event, and deadline triggers
/// - **Runbooks**: Operational procedures
/// - **Observability**: Logging, metrics, and tracing
///
/// ## Usage
///
/// ```dart
/// import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';
///
/// // Create handler registry
/// final handlers = HandlerRegistry();
/// handlers.register('myHandler', MyHandler());
///
/// // Create execution engine
/// final engine = ExecutionEngine(
///   config: ExecutionEngineConfig(),
///   handlers: handlers,
/// );
///
/// // Execute pipeline
/// final result = await engine.executePipeline(
///   pipeline,
///   input,
///   context,
/// );
/// ```
library mcp_knowledge_ops;

// Models (new canonical models)
// Hide legacy event classes that are superseded by typed OpsEvent subclasses in events_arch
export 'src/models/models.dart'
    hide
        PipelineStartedEvent,
        PipelineCompletedEvent,
        WorkflowStartedEvent,
        WorkflowCompletedEvent,
        CheckpointCreatedEvent;

// Execution engine (new - hide exceptions, canonical in errors)
export 'src/execution/execution.dart'
    hide PipelineException, StageException, GateException;

// Observability (hide PipelineMetrics - canonical in models)
export 'src/observability/observability.dart'
    hide PipelineMetrics, WorkflowMetrics, SchedulerMetrics;

// Runbooks (new)
export 'src/runbooks/runbooks.dart';

// Behavior definition — unified execution engine (flow/pipeline/runbook successor)
export 'src/behavior/behavior.dart';

// Pipeline infrastructure (existing - hide duplicates)
export 'src/pipeline/pipeline.dart'
    hide
        PipelineResult,
        PipelineMetrics,
        PipelineError,
        StageResult,
        StageStatus,
        RetryConfig;
export 'src/pipeline/pipeline_executor.dart'
    hide
        PipelineStartedEvent,
        PipelineCompletedEvent,
        PipelineFailedEvent,
        StageStartedEvent,
        StageCompletedEvent,
        StageFailedEvent;
export 'src/pipeline/pipeline_handler.dart'
    hide FunctionHandler, HandlerFilter, HandlerInfo;
export 'src/pipeline/priority_calculator.dart';
export 'src/pipeline/cascade_refresh.dart';
export 'src/pipeline/clustering.dart';
export 'src/pipeline/handler_adapters.dart';

// Concrete pipelines
export 'src/pipeline/pipelines/curation_pipeline.dart';
export 'src/pipeline/pipelines/summary_refresh_pipeline.dart';
export 'src/pipeline/pipelines/pattern_mining_pipeline.dart';
export 'src/pipeline/pipelines/ingest_pipeline.dart';
export 'src/pipeline/pipelines/index_rebuild_pipeline.dart';

// Workflow infrastructure (existing - hide duplicates)
export 'src/workflow/workflow.dart';
export 'src/workflow/workflow_executor.dart'
    hide
        WorkflowException,
        WorkflowStartedEvent,
        WorkflowCompletedEvent,
        WorkflowFailedEvent;
export 'src/workflow/review_models.dart';
export 'src/workflow/approval_router.dart';
export 'src/workflow/cancellation.dart';

// Concrete workflows
export 'src/workflow/workflows/skill_build_workflow.dart';
export 'src/workflow/workflows/profile_build_workflow.dart';
export 'src/workflow/workflows/bundle_build_workflow.dart';

// Errors
export 'src/errors/errors.dart' hide CircuitOpenException;

// Events (hide RetryPolicy canonical in pipeline; hide typed event names
// that duplicate scheduler_events.dart canonical OpsEvent subclasses)
export 'src/events/events_arch.dart'
    hide
        RetryPolicy,
        ScheduleDeletedEvent,
        SchedulePausedEvent,
        ScheduleResumedEvent,
        ScheduleTriggeredEvent,
        ExecutionQueuedEvent,
        ExecutionStartedEvent,
        ExecutionCompletedEvent,
        ExecutionFailedEvent;

// Scheduler (hide TriggerInfo, canonical in runbooks)
export 'src/scheduler/scheduler.dart' hide TriggerInfo, ExecutionError;
export 'src/scheduler/scheduler_events.dart';
export 'src/scheduler/mcp_tools.dart';

// Ports (re-export standard ports from mcp_bundle + OpsPorts/ConsumedOpsPorts)
export 'src/ports/ops_port.dart';

// Provided-port adapters (MOD-CORE-011)
export 'src/adapters/workflow_port_adapter.dart';
export 'src/adapters/pipeline_port_adapter.dart';
export 'src/adapters/schedule_trigger_port_adapter.dart';
// Only `AuditPortAdapter` is re-exported — the `mcp_bundle` `AuditEvent`
// and `AuditFilter` types clash with the internal observability types of
// the same name, so the bundle types remain accessible via direct import.
export 'src/adapters/audit_port_adapter.dart' show AuditPortAdapter;
export 'src/adapters/runbook_port_adapter.dart';

// OpsRuntime facade (MOD-CORE-011)
export 'src/runtime/ops_runtime.dart';
