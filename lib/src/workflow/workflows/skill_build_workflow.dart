/// Skill Build Workflow - Workflow for building skills from patterns.
///
/// Handles the complete skill build lifecycle from pattern validation
/// through evaluation, review, bundling, signing, and publishing.
library;

import '../workflow.dart';
import '../../models/execution_result.dart';
import '../../models/stage.dart';
import '../../models/gate.dart';
import '../../id_generator.dart';

// ---------------------------------------------------------------------------
// Placeholder types
// ---------------------------------------------------------------------------

/// Configuration for skill evaluation.
class EvaluationConfig {
  /// Evaluation set identifiers to run.
  final List<String>? evalSets;

  /// Minimum pass rate required (0.0 - 1.0).
  final double? minPassRate;

  /// Whether to run regression checks.
  final bool? regressionCheck;

  /// Whether to run benchmark checks.
  final bool? benchmarkCheck;

  const EvaluationConfig({
    this.evalSets,
    this.minPassRate,
    this.regressionCheck,
    this.benchmarkCheck,
  });
}

/// Result of a single evaluation set run.
class EvaluationResult {
  /// Evaluation set identifier.
  final String evalSetId;

  /// Pass rate (0.0 - 1.0).
  final double passRate;

  /// Detailed evaluation results.
  final Map<String, dynamic> details;

  const EvaluationResult({
    required this.evalSetId,
    required this.passRate,
    this.details = const {},
  });
}

/// Packaged skill bundle artifact.
class SkillBundle {
  /// Bundle identifier.
  final String id;

  /// Skill identifier this bundle belongs to.
  final String skillId;

  /// Bundle version.
  final String version;

  /// Storage path or URI.
  final String path;

  /// Content checksum for integrity verification.
  final String checksum;

  const SkillBundle({
    required this.id,
    required this.skillId,
    required this.version,
    required this.path,
    required this.checksum,
  });
}

// ---------------------------------------------------------------------------
// Input / Output
// ---------------------------------------------------------------------------

/// Input for the skill build workflow.
class SkillBuildInput {
  /// Pattern identifier to build from.
  final String patternId;

  /// Optional skill name override.
  final String? skillName;

  /// Optional version override.
  final String? version;

  /// Evaluation configuration.
  final EvaluationConfig? evaluationConfig;

  /// Target for publishing: "draft" | "staging" | "production".
  final String? publishTarget;

  const SkillBuildInput({
    required this.patternId,
    this.skillName,
    this.version,
    this.evaluationConfig,
    this.publishTarget,
  });
}

/// Output of the skill build workflow.
class SkillBuildOutput {
  /// Generated skill identifier.
  final String skillId;

  /// Skill version.
  final String version;

  /// Produced skill bundle.
  final SkillBundle bundle;

  /// Evaluation results for all evaluation sets.
  final List<EvaluationResult> evaluationResults;

  /// Where the skill was published, if applicable.
  final String? publishedTo;

  const SkillBuildOutput({
    required this.skillId,
    required this.version,
    required this.bundle,
    required this.evaluationResults,
    this.publishedTo,
  });
}

// ---------------------------------------------------------------------------
// Workflow
// ---------------------------------------------------------------------------

/// Workflow for building skills from patterns.
///
/// Stages:
/// 1. validate_pattern - Validate the source pattern
/// 2. generate_skill_draft - Generate initial skill code
/// 3. generate_rubric - Generate evaluation rubric
/// 4. run_evaluation - Run skill evaluation against rubric
/// 5. evaluation_gate - Quality gate: check evaluation results
/// 6. regression_check - Check for regressions (conditional)
/// 7. human_review - Request human review (conditional)
/// 8. create_bundle - Create skill bundle
/// 9. sign_bundle - Sign the bundle
/// 10. publish - Publish the skill (conditional)
class SkillBuildWorkflow extends Workflow<SkillBuildInput, SkillBuildOutput> {
  @override
  final String id;

  @override
  final String name;

  @override
  final String version;

  @override
  final String? description;

  /// Workflow stages definition.
  final List<WorkflowStage> _workflowStages;

  /// Quality gates.
  final List<Gate> _gates;

  @override
  final WorkflowConfig config;

  SkillBuildWorkflow({
    String? id,
    this.name = 'Skill Build Workflow',
    this.version = '1.0.0',
    this.description = 'Build, evaluate, and publish skills from patterns.',
    WorkflowConfig? config,
  })  : id = id ?? 'skill_build',
        _workflowStages = _buildWorkflowStages(),
        _gates = _buildGates(),
        config = config ?? const WorkflowConfig();

  @override
  List<WorkflowStage> get stages => _workflowStages;

  @override
  List<Gate> get gates => _gates;

  @override
  Future<WorkflowResult<SkillBuildOutput>> run(
    SkillBuildInput input,
    WorkflowContext context,
  ) async {
    // Per REDESIGN-PLAN Phase 7 (no-legacy), concrete workflows are
    // declarative stage specifications. Imperative execution flows
    // through `ExecutionEngine` + registered handlers, not through this
    // method. `run()` returns a placeholder success so callers that
    // inspect the workflow (adapters, tests) keep compiling.
    return WorkflowResult.success(
      output: SkillBuildOutput(
        skillId: generateId('skill', separator: '-'),
        version: version,
        bundle: const SkillBundle(
          id: '',
          skillId: '',
          version: '',
          path: '',
          checksum: '',
        ),
        evaluationResults: const [],
      ),
      stages: const [],
      metrics: WorkflowMetrics.empty(),
    );
  }

  /// Build the workflow stage definitions.
  static List<WorkflowStage> _buildWorkflowStages() {
    return [
      const WorkflowStage(
        id: 'validate_pattern',
        name: 'Validate Pattern',
        description: 'Validate the source pattern for skill generation.',
        handler: 'skill.validatePattern',
        type: WorkflowStageType.task,
        order: 1,
      ),
      const WorkflowStage(
        id: 'generate_skill_draft',
        name: 'Generate Skill Draft',
        description: 'Generate initial skill code from the validated pattern.',
        handler: 'skill.generateDraft',
        type: WorkflowStageType.task,
        order: 2,
      ),
      const WorkflowStage(
        id: 'generate_rubric',
        name: 'Generate Rubric',
        description: 'Generate evaluation rubric for the skill.',
        handler: 'skill.generateRubric',
        type: WorkflowStageType.task,
        order: 3,
      ),
      const WorkflowStage(
        id: 'run_evaluation',
        name: 'Run Evaluation',
        description: 'Run skill evaluation against the generated rubric.',
        handler: 'skill.runEvaluation',
        type: WorkflowStageType.task,
        order: 4,
      ),
      const WorkflowStage(
        id: 'evaluation_gate',
        name: 'Evaluation Gate',
        description: 'Quality gate to check evaluation results.',
        handler: 'workflow.checkGate',
        type: WorkflowStageType.gate,
        order: 5,
        config: {'gateId': 'eval_pass'},
      ),
      const WorkflowStage(
        id: 'regression_check',
        name: 'Regression Check',
        description: 'Check for regressions against previous skill versions.',
        handler: 'skill.regressionCheck',
        type: WorkflowStageType.task,
        order: 6,
        condition: 'config.regressionCheck',
      ),
      const WorkflowStage(
        id: 'philosophy_alignment',
        name: 'Philosophy Alignment',
        description: 'Verify skill draft aligns with value priorities and does not violate prohibitions.',
        handler: 'philosophy.checkProhibitions',
        type: WorkflowStageType.task,
        order: 7,
        condition: 'ports.philosophy != null',
      ),
      const WorkflowStage(
        id: 'human_review',
        name: 'Human Review',
        description: 'Request human review and approval.',
        handler: 'approval.requestReview',
        type: WorkflowStageType.review,
        order: 8,
        condition: '!config.autoApprove',
        timeout: Duration(hours: 24),
      ),
      const WorkflowStage(
        id: 'create_bundle',
        name: 'Create Bundle',
        description: 'Create the skill bundle artifact.',
        handler: 'skill.createBundle',
        type: WorkflowStageType.task,
        order: 9,
      ),
      const WorkflowStage(
        id: 'sign_bundle',
        name: 'Sign Bundle',
        description: 'Sign the skill bundle for integrity verification.',
        handler: 'bundle.sign',
        type: WorkflowStageType.task,
        order: 10,
      ),
      const WorkflowStage(
        id: 'publish',
        name: 'Publish',
        description: 'Publish the signed skill bundle to the target.',
        handler: 'skill.publish',
        type: WorkflowStageType.task,
        order: 11,
        condition: 'config.publishOnSuccess',
      ),
    ];
  }

  /// Build quality gates.
  static List<Gate> _buildGates() {
    return [
      const Gate(
        id: 'eval_pass',
        name: 'Evaluation Pass Gate',
        afterStage: 'run_evaluation',
        conditions: [
          GateCondition(
            type: ConditionType.threshold,
            metric: 'passRate',
            operator: '>=',
            value: 0.85,
          ),
          GateCondition(
            type: ConditionType.threshold,
            metric: 'regressionScore',
            operator: '>=',
            value: 0.95,
          ),
        ],
        onFailure: GateFailure.block,
      ),
    ];
  }
}
