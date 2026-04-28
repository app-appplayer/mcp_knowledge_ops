/// Workflow - Sequential stage-based workflow definitions.
///
/// Provides workflow infrastructure with stages, quality gates, and
/// sequential execution. All workflows are linear pipelines with
/// gates and approvals.
library;

import '../models/stage.dart';
import '../models/gate.dart';
import '../models/execution_result.dart';

/// Base workflow interface.
///
/// Workflows are multi-step build and release processes that produce
/// deployable artifacts (SkillBundle, ProfileBundle, McpBundle).
///
/// All workflows follow a sequential execution model:
/// For each stage in order → check condition → execute handler →
/// record output → evaluate gates → checkpoint → next stage
abstract class Workflow<TInput, TOutput> {
  /// Workflow identifier.
  String get id;

  /// Workflow name.
  String get name;

  /// Workflow version.
  String get version;

  /// Workflow description.
  String? get description;

  /// Ordered list of workflow stages.
  List<WorkflowStage> get stages;

  /// Quality gates evaluated between stages.
  List<Gate> get gates;

  /// Workflow configuration.
  WorkflowConfig get config;

  /// Execute the workflow with the given input and context.
  Future<WorkflowResult<TOutput>> run(TInput input, WorkflowContext context);
}

/// Workflow configuration.
class WorkflowConfig {
  /// Overall workflow timeout.
  final Duration? timeout;

  /// Whether to auto-approve review/approval stages.
  final bool autoApprove;

  /// Whether to run in dry-run mode (no side effects).
  final bool dryRun;

  /// Whether to publish artifacts on successful completion.
  final bool publishOnSuccess;

  const WorkflowConfig({
    this.timeout,
    this.autoApprove = false,
    this.dryRun = false,
    this.publishOnSuccess = false,
  });
}

/// Workflow execution context.
class WorkflowContext {
  /// Unique run identifier.
  final String runId;

  /// Trace identifier for distributed tracing.
  final String? traceId;

  /// Workspace identifier.
  final String workspaceId;

  /// User who initiated the workflow.
  final String userId;

  /// Timestamp for temporal queries.
  final DateTime asOf;

  /// Workflow configuration.
  final WorkflowConfig config;

  const WorkflowContext({
    required this.runId,
    this.traceId,
    required this.workspaceId,
    required this.userId,
    required this.asOf,
    required this.config,
  });
}
