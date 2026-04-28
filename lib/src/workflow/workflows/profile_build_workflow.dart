/// Profile Build Workflow - Workflow for building profiles from patterns or manual input.
///
/// Handles the complete profile build lifecycle from source validation
/// through metric extraction, policy generation, testing, review,
/// bundling, signing, and publishing.
library;

import '../workflow.dart';
import '../../models/execution_result.dart';
import '../../models/stage.dart';
import '../../models/gate.dart';

// ---------------------------------------------------------------------------
// Placeholder types
// ---------------------------------------------------------------------------

/// Definition of a profile to be built.
class ProfileDefinition {
  /// Profile name.
  final String name;

  /// Policy definitions for the profile.
  final Map<String, dynamic> policies;

  const ProfileDefinition({required this.name, required this.policies});
}

/// Configuration for profile evaluation.
class ProfileEvaluationConfig {
  /// Test cases to evaluate.
  final List<ProfileTestCase>? testCases;

  /// Minimum consistency score required.
  final double? minConsistency;

  /// Whether to compare results with a baseline profile.
  final bool? compareWithBaseline;

  const ProfileEvaluationConfig({
    this.testCases,
    this.minConsistency,
    this.compareWithBaseline,
  });
}

/// A single test case for profile evaluation.
class ProfileTestCase {
  /// Test case identifier.
  final String id;

  /// Context data for the test case.
  final Map<String, dynamic> context;

  /// Expected decision outcome.
  final String? expectedDecision;

  /// Expected tone outcome.
  final String? expectedTone;

  const ProfileTestCase({
    required this.id,
    required this.context,
    this.expectedDecision,
    this.expectedTone,
  });
}

/// Result of a single profile evaluation test case.
class ProfileEvaluationResult {
  /// Identifier of the test case that was evaluated.
  final String testCaseId;

  /// Whether the test case passed.
  final bool passed;

  /// Additional details about the evaluation.
  final Map<String, dynamic> details;

  const ProfileEvaluationResult({
    required this.testCaseId,
    required this.passed,
    this.details = const {},
  });
}

/// A bundled profile artifact.
class ProfileBundle {
  /// Bundle identifier.
  final String id;

  /// Profile identifier.
  final String profileId;

  /// Bundle version.
  final String version;

  /// Storage path.
  final String path;

  /// Content checksum.
  final String checksum;

  const ProfileBundle({
    required this.id,
    required this.profileId,
    required this.version,
    required this.path,
    required this.checksum,
  });
}

// ---------------------------------------------------------------------------
// Input / Output
// ---------------------------------------------------------------------------

/// Input for the profile build workflow.
class ProfileBuildInput {
  /// Source type: "pattern" or "manual".
  final String source;

  /// Pattern identifier when source is "pattern".
  final String? patternId;

  /// Profile definition when source is "manual".
  final ProfileDefinition? profileDef;

  /// Optional version override.
  final String? version;

  /// Evaluation configuration for profile testing.
  final ProfileEvaluationConfig? evaluationConfig;

  /// Publish target: "draft", "staging", or "production".
  final String? publishTarget;

  const ProfileBuildInput({
    required this.source,
    this.patternId,
    this.profileDef,
    this.version,
    this.evaluationConfig,
    this.publishTarget,
  });
}

/// Output of the profile build workflow.
class ProfileBuildOutput {
  /// Generated profile identifier.
  final String profileId;

  /// Profile version.
  final String version;

  /// The built profile bundle.
  final ProfileBundle bundle;

  /// Evaluation results from profile testing.
  final List<ProfileEvaluationResult> evaluationResults;

  /// Where the profile was published, if applicable.
  final String? publishedTo;

  const ProfileBuildOutput({
    required this.profileId,
    required this.version,
    required this.bundle,
    required this.evaluationResults,
    this.publishedTo,
  });
}

// ---------------------------------------------------------------------------
// Workflow
// ---------------------------------------------------------------------------

/// Workflow for building profiles from patterns or manual input.
///
/// Stages:
/// 1. validate_source - Validate the profile source
/// 2. extract_metrics - Extract metrics from pattern (conditional)
/// 3. generate_policies - Generate policies from pattern (conditional)
/// 4. run_profile_tests - Run profile tests
/// 5. consistency_check - Run consistency checks
/// 6. test_gate - Quality gate: check test results
/// 7. philosophy_alignment - Check philosophy alignment (conditional)
/// 8. human_review - Request human review (conditional)
/// 9. create_bundle - Create profile bundle
/// 10. sign_bundle - Sign the bundle
/// 11. publish - Publish the profile (conditional)
class ProfileBuildWorkflow
    extends Workflow<ProfileBuildInput, ProfileBuildOutput> {
  @override
  final String id;

  @override
  final String name;

  @override
  final String version;

  @override
  final String? description;

  @override
  final WorkflowConfig config;

  ProfileBuildWorkflow({
    String? id,
    this.name = 'Profile Build Workflow',
    this.version = '1.0.0',
    this.description = 'Builds profiles from patterns or manual input through '
        'validation, testing, bundling, signing, and publishing.',
    this.config = const WorkflowConfig(),
  }) : id = id ?? 'profile_build';

  @override
  List<WorkflowStage> get stages => _stages;

  @override
  List<Gate> get gates => _gates;

  @override
  Future<WorkflowResult<ProfileBuildOutput>> run(
    ProfileBuildInput input,
    WorkflowContext context,
  ) async {
    // Declarative stub — see SkillBuildWorkflow.run for rationale.
    return WorkflowResult.success(
      output: ProfileBuildOutput(
        profileId: 'profile-${DateTime.now().microsecondsSinceEpoch}',
        version: version,
        bundle: const ProfileBundle(
          id: '',
          profileId: '',
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

  // -------------------------------------------------------------------------
  // Stage definitions
  // -------------------------------------------------------------------------

  static final List<WorkflowStage> _stages = [
    const WorkflowStage(
      id: 'validate_source',
      name: 'Validate Source',
      description: 'Validate the profile source type and required inputs.',
      handler: 'profile.validateSource',
      type: WorkflowStageType.task,
      order: 1,
    ),
    const WorkflowStage(
      id: 'extract_metrics',
      name: 'Extract Metrics',
      description: 'Extract metrics from the source pattern.',
      handler: 'profile.extractMetrics',
      type: WorkflowStageType.task,
      order: 2,
      condition: "input.source == 'pattern'",
    ),
    const WorkflowStage(
      id: 'generate_policies',
      name: 'Generate Policies',
      description: 'Generate profile policies from extracted metrics.',
      handler: 'profile.generatePolicies',
      type: WorkflowStageType.task,
      order: 3,
      condition: "input.source == 'pattern'",
    ),
    const WorkflowStage(
      id: 'run_profile_tests',
      name: 'Run Profile Tests',
      description: 'Execute test cases against the built profile.',
      handler: 'profile.runTests',
      type: WorkflowStageType.task,
      order: 4,
    ),
    const WorkflowStage(
      id: 'consistency_check',
      name: 'Consistency Check',
      description: 'Verify profile consistency across test scenarios.',
      handler: 'profile.consistencyCheck',
      type: WorkflowStageType.task,
      order: 5,
    ),
    const WorkflowStage(
      id: 'test_gate',
      name: 'Test Gate',
      description: 'Quality gate verifying test pass rate and consistency.',
      handler: 'workflow.checkGate',
      type: WorkflowStageType.gate,
      order: 6,
      config: {'gateId': 'test_pass'},
    ),
    const WorkflowStage(
      id: 'philosophy_alignment',
      name: 'Philosophy Alignment',
      description: 'Check profile alignment with philosophy prohibitions.',
      handler: 'philosophy.checkProhibitions',
      type: WorkflowStageType.task,
      order: 7,
      condition: 'ports.philosophy != null',
    ),
    const WorkflowStage(
      id: 'human_review',
      name: 'Human Review',
      description: 'Request human review of the built profile.',
      handler: 'approval.requestReview',
      type: WorkflowStageType.review,
      order: 8,
      condition: '!config.autoApprove',
      timeout: Duration(hours: 24),
    ),
    const WorkflowStage(
      id: 'create_bundle',
      name: 'Create Bundle',
      description: 'Package the profile into a deployable bundle.',
      handler: 'profile.createBundle',
      type: WorkflowStageType.task,
      order: 9,
    ),
    const WorkflowStage(
      id: 'sign_bundle',
      name: 'Sign Bundle',
      description: 'Cryptographically sign the profile bundle.',
      handler: 'bundle.sign',
      type: WorkflowStageType.task,
      order: 10,
    ),
    const WorkflowStage(
      id: 'publish',
      name: 'Publish',
      description: 'Publish the signed bundle to the target environment.',
      handler: 'profile.publish',
      type: WorkflowStageType.task,
      order: 11,
      condition: 'config.publishOnSuccess',
    ),
  ];

  // -------------------------------------------------------------------------
  // Gate definitions
  // -------------------------------------------------------------------------

  static final List<Gate> _gates = [
    const Gate(
      id: 'test_pass',
      name: 'Profile Test Gate',
      afterStage: 'consistency_check',
      conditions: [
        GateCondition(
          type: ConditionType.threshold,
          metric: 'passRate',
          operator: '>=',
          value: 0.9,
        ),
        GateCondition(
          type: ConditionType.threshold,
          metric: 'consistencyScore',
          operator: '>=',
          value: 0.85,
        ),
      ],
      onFailure: GateFailure.block,
    ),
  ];
}
