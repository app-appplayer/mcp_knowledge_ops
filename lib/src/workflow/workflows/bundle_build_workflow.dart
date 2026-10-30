/// Bundle Build Workflow - Workflow for assembling and publishing bundles.
///
/// Handles the complete bundle build lifecycle from component resolution
/// through dependency validation, collection, assembly, integrity
/// generation, approval, and publishing.
library;

import '../workflow.dart';
import '../../models/execution_result.dart';
import '../../models/stage.dart';
import '../../models/gate.dart';
import '../../id_generator.dart';

// ---------------------------------------------------------------------------
// Input / Output models
// ---------------------------------------------------------------------------

/// Components to include in the bundle build.
class BundleComponents {
  /// Skill identifiers to include.
  final List<String>? skillIds;

  /// Profile identifiers to include.
  final List<String>? profileIds;

  /// Asset paths to include.
  final List<String>? assetPaths;

  /// Flow identifiers to include.
  final List<String>? flowIds;

  /// UI screen identifiers to include.
  final List<String>? uiScreenIds;

  const BundleComponents({
    this.skillIds,
    this.profileIds,
    this.assetPaths,
    this.flowIds,
    this.uiScreenIds,
  });
}

/// Input for the bundle build workflow.
class BundleBuildInput {
  /// Manifest identifier to build from.
  final String manifestId;

  /// Components to include in the bundle.
  final BundleComponents components;

  /// Optional version override.
  final String? version;

  /// Publish target: "draft" | "staging" | "production".
  final String? publishTarget;

  const BundleBuildInput({
    required this.manifestId,
    required this.components,
    this.version,
    this.publishTarget,
  });
}

/// Placeholder representing an assembled MCP bundle artifact.
class McpBundle {
  /// Bundle identifier.
  final String id;

  /// Bundle version.
  final String version;

  /// Storage path or URI.
  final String path;

  const McpBundle({
    required this.id,
    required this.version,
    required this.path,
  });
}

/// Integrity information for a built bundle.
class BundleIntegrity {
  /// Content checksum.
  final String checksum;

  /// Optional cryptographic signature.
  final String? signature;

  /// Timestamp when integrity was computed.
  final DateTime timestamp;

  const BundleIntegrity({
    required this.checksum,
    this.signature,
    required this.timestamp,
  });
}

/// Output of the bundle build workflow.
class BundleBuildOutput {
  /// Generated bundle identifier.
  final String bundleId;

  /// Bundle version.
  final String version;

  /// Assembled bundle artifact.
  final McpBundle bundle;

  /// Integrity information.
  final BundleIntegrity integrity;

  /// Where the bundle was published (null if not published).
  final String? publishedTo;

  const BundleBuildOutput({
    required this.bundleId,
    required this.version,
    required this.bundle,
    required this.integrity,
    this.publishedTo,
  });
}

// ---------------------------------------------------------------------------
// Workflow definition
// ---------------------------------------------------------------------------

/// Workflow for assembling and publishing bundles.
///
/// Stages:
/// 1. resolve_components - Resolve all bundle components from the manifest
/// 2. validate_dependencies - Validate component dependencies
/// 3. dependency_gate - Quality gate: check dependency validity
/// 4. collect_skills - Collect skill artifacts
/// 5. collect_profiles - Collect profile artifacts
/// 6. collect_assets - Collect additional assets
/// 7. assemble_bundle - Assemble the final bundle
/// 8. validate_bundle - Validate assembled bundle
/// 9. validation_gate - Quality gate: check bundle validity
/// 10. philosophy_compliance - Check philosophy compliance (conditional)
/// 11. generate_integrity - Generate integrity checksums
/// 12. human_approval - Request human approval (conditional)
/// 13. publish - Publish the bundle (conditional)
class BundleBuildWorkflow extends Workflow<BundleBuildInput, BundleBuildOutput> {
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

  BundleBuildWorkflow({
    String? id,
    this.name = 'Bundle Build Workflow',
    this.version = '1.0.0',
    this.description = 'Assembles and publishes MCP bundles from component manifests.',
    WorkflowConfig? config,
  })  : id = id ?? 'bundle_build',
        config = config ?? const WorkflowConfig();

  // -------------------------------------------------------------------------
  // Stages
  // -------------------------------------------------------------------------

  @override
  List<WorkflowStage> get stages => _stages;

  static final List<WorkflowStage> _stages = [
    const WorkflowStage(
      id: 'resolve_components',
      name: 'Resolve Components',
      description: 'Resolve all bundle components from the manifest.',
      handler: 'bundle.resolveComponents',
      type: WorkflowStageType.task,
      order: 1,
    ),
    const WorkflowStage(
      id: 'validate_dependencies',
      name: 'Validate Dependencies',
      description: 'Validate component dependencies for conflicts and missing items.',
      handler: 'bundle.validateDependencies',
      type: WorkflowStageType.task,
      order: 2,
    ),
    const WorkflowStage(
      id: 'dependency_gate',
      name: 'Dependency Gate',
      description: 'Quality gate that checks dependency validity.',
      handler: 'workflow.checkGate',
      type: WorkflowStageType.gate,
      order: 3,
      config: {'gateId': 'deps_valid'},
    ),
    const WorkflowStage(
      id: 'collect_skills',
      name: 'Collect Skills',
      description: 'Collect skill artifacts for bundling.',
      handler: 'bundle.collectSkills',
      type: WorkflowStageType.task,
      order: 4,
    ),
    const WorkflowStage(
      id: 'collect_profiles',
      name: 'Collect Profiles',
      description: 'Collect profile artifacts for bundling.',
      handler: 'bundle.collectProfiles',
      type: WorkflowStageType.task,
      order: 5,
    ),
    const WorkflowStage(
      id: 'collect_assets',
      name: 'Collect Assets',
      description: 'Collect additional assets for bundling.',
      handler: 'bundle.collectAssets',
      type: WorkflowStageType.task,
      order: 6,
    ),
    const WorkflowStage(
      id: 'assemble_bundle',
      name: 'Assemble Bundle',
      description: 'Assemble collected components into the final bundle.',
      handler: 'bundle.assemble',
      type: WorkflowStageType.task,
      order: 7,
    ),
    const WorkflowStage(
      id: 'validate_bundle',
      name: 'Validate Bundle',
      description: 'Validate the assembled bundle for schema and integrity.',
      handler: 'bundle.validate',
      type: WorkflowStageType.task,
      order: 8,
    ),
    const WorkflowStage(
      id: 'validation_gate',
      name: 'Validation Gate',
      description: 'Quality gate that checks bundle validity and size.',
      handler: 'workflow.checkGate',
      type: WorkflowStageType.gate,
      order: 9,
      config: {'gateId': 'bundle_valid'},
    ),
    const WorkflowStage(
      id: 'philosophy_compliance',
      name: 'Philosophy Compliance',
      description: 'Check bundle compliance with philosophy prohibitions.',
      handler: 'philosophy.checkProhibitions',
      type: WorkflowStageType.task,
      order: 10,
      condition: 'ports.philosophy != null',
    ),
    const WorkflowStage(
      id: 'generate_integrity',
      name: 'Generate Integrity',
      description: 'Generate integrity checksums and optional signatures.',
      handler: 'bundle.generateIntegrity',
      type: WorkflowStageType.task,
      order: 11,
    ),
    const WorkflowStage(
      id: 'human_approval',
      name: 'Human Approval',
      description: 'Request human approval for production deployments.',
      handler: 'approval.requestApproval',
      type: WorkflowStageType.approval,
      order: 12,
      condition: "input.publishTarget == 'production'",
      timeout: Duration(hours: 48),
    ),
    const WorkflowStage(
      id: 'publish',
      name: 'Publish',
      description: 'Publish the bundle to the configured target.',
      handler: 'bundle.publish',
      type: WorkflowStageType.task,
      order: 13,
      condition: 'config.publishOnSuccess',
    ),
  ];

  // -------------------------------------------------------------------------
  // Quality Gates
  // -------------------------------------------------------------------------

  @override
  List<Gate> get gates => _gates;

  static final List<Gate> _gates = [
    const Gate(
      id: 'deps_valid',
      name: 'Dependency Validation Gate',
      afterStage: 'validate_dependencies',
      conditions: [
        GateCondition(
          type: ConditionType.expression,
          expression: 'missingDependencies.isEmpty',
        ),
        GateCondition(
          type: ConditionType.expression,
          expression: 'circularDependencies.isEmpty',
        ),
        GateCondition(
          type: ConditionType.expression,
          expression: 'versionConflicts.isEmpty',
        ),
      ],
      onFailure: GateFailure.block,
    ),
    const Gate(
      id: 'bundle_valid',
      name: 'Bundle Validation Gate',
      afterStage: 'validate_bundle',
      conditions: [
        GateCondition(
          type: ConditionType.expression,
          expression: 'schemaValid',
        ),
        GateCondition(
          type: ConditionType.expression,
          expression: 'integrityValid',
        ),
        GateCondition(
          type: ConditionType.threshold,
          metric: 'bundleSizeMb',
          operator: '<=',
          value: 100.0,
        ),
      ],
      onFailure: GateFailure.block,
    ),
  ];

  // -------------------------------------------------------------------------
  // Execution
  // -------------------------------------------------------------------------

  @override
  Future<WorkflowResult<BundleBuildOutput>> run(
    BundleBuildInput input,
    WorkflowContext context,
  ) async {
    // Declarative stub — see SkillBuildWorkflow.run for rationale.
    return WorkflowResult.success(
      output: BundleBuildOutput(
        bundleId: generateId('bundle', separator: '-'),
        version: version,
        bundle: const McpBundle(
          id: '',
          version: '',
          path: '',
        ),
        integrity: BundleIntegrity(
          checksum: '',
          timestamp: DateTime.now(),
        ),
      ),
      stages: const [],
      metrics: WorkflowMetrics.empty(),
    );
  }
}
