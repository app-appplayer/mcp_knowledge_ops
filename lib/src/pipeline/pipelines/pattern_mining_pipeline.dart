/// Pattern Mining Pipeline - Declarative stage spec for pattern mining.
///
/// Per REDESIGN-PLAN.md Phase 7 (no-legacy), this class holds no direct
/// references to `FactGraphPort`, `SkillPort`, or `ProfilePort`. Handlers
/// reach the standard ports (`FactsPort`, `SkillRuntimePort`,
/// `AppraisalPort`, `DecisionPort`, `MetricsPort`, `PhilosophyPort`) via
/// `HandlerContext.ports`.
library;

import '../pipeline.dart';

/// Pipeline for mining patterns from facts.
class PatternMiningPipeline
    implements Pipeline<PatternMiningInput, PatternMiningOutput> {
  @override
  final String id;

  @override
  final String name;

  @override
  final String version;

  @override
  final String? description;

  @override
  final List<PipelineStage> stages;

  @override
  final PipelineConfig config;

  PatternMiningPipeline({
    String? id,
    this.name = 'Pattern Mining Pipeline',
    this.version = '1.0.0',
    this.description = 'Discover patterns in accumulated facts',
    PipelineConfig? config,
  })  : id = id ?? 'pattern_mining_pipeline',
        stages = _buildStages(),
        config = config ??
            const PipelineConfig(
              maxConcurrency: 2,
              onError: OnErrorStrategy.fail,
              timeout: Duration(minutes: 30),
            );

  static List<PipelineStage> _buildStages() {
    return [
      const PipelineStage(
        id: 'collect_signals',
        name: 'Collect Signals',
        order: 1,
        handler: 'mining.collectSignals',
        description: 'Gather signals via FactsPort.queryFacts within time window',
      ),
      const PipelineStage(
        id: 'preprocess',
        name: 'Preprocess Data',
        order: 2,
        handler: 'mining.preprocess',
        inputMapping: {'signals': 'collect_signals'},
        description: 'Normalize collected data (pure)',
      ),
      const PipelineStage(
        id: 'cluster_signals',
        name: 'Cluster Signals',
        order: 3,
        handler: 'mining.cluster',
        inputMapping: {'preprocessed': 'preprocess'},
        description: 'Group similar signals using Clustering.kmeans (pure)',
      ),
      const PipelineStage(
        id: 'extract_patterns',
        name: 'Extract Patterns',
        order: 4,
        handler: 'mining.extract',
        inputMapping: {'clusters': 'cluster_signals'},
        description: 'Identify recurring patterns from clusters',
      ),
      const PipelineStage(
        id: 'validate_patterns',
        name: 'Validate Patterns',
        order: 5,
        handler: 'mining.validate',
        inputMapping: {'patterns': 'extract_patterns'},
        description: 'Validate patterns via AppraisalPort.appraise',
      ),
      const PipelineStage(
        id: 'philosophy_validate',
        name: 'Philosophy Validate',
        order: 6,
        handler: 'philosophy.checkProhibitions',
        inputMapping: {'validatedPatterns': 'validate_patterns'},
        condition: 'ports.philosophy != null',
        description:
            'Validate patterns via PhilosophyPort.checkProhibitions',
      ),
      const PipelineStage(
        id: 'generate_skill_candidates',
        name: 'Generate Skill Candidates',
        order: 7,
        handler: 'mining.generateSkillCandidates',
        inputMapping: {'validatedPatterns': 'philosophy_validate'},
        condition:
            "config.generateSkills && pattern.type in ['procedure', 'workflow']",
        description:
            'Generate candidate skills via SkillRuntimePort.executeSkill',
      ),
      const PipelineStage(
        id: 'generate_profile_candidates',
        name: 'Generate Profile Candidates',
        order: 8,
        handler: 'mining.generateProfileCandidates',
        inputMapping: {'validatedPatterns': 'philosophy_validate'},
        condition:
            "config.generateProfiles && pattern.type in ['evaluation', 'decision']",
        description:
            'Generate candidate profiles via AppraisalPort.appraise + DecisionPort.decide',
      ),
      const PipelineStage(
        id: 'store_patterns',
        name: 'Store Patterns',
        order: 9,
        handler: 'mining.storePattern',
        inputMapping: {'patterns': 'philosophy_validate'},
        description:
            'Store patterns as facts via FactsPort.writeFacts (type: pattern)',
      ),
      const PipelineStage(
        id: 'emit_notifications',
        name: 'Emit Notifications',
        order: 10,
        handler: 'ops.notify',
        inputMapping: {'storedPatterns': 'store_patterns'},
        condition: 'config.notifyOnDiscovery',
        description: 'Notify stakeholders via NotificationPort (optional)',
      ),
    ];
  }

  @override
  Future<PipelineResult<PatternMiningOutput>> run(
    PatternMiningInput input,
    PipelineContext context,
  ) async {
    return PipelineResult.success(
      output: PatternMiningOutput(
        patternsDiscovered: const [],
        candidateSkills: const [],
        candidateProfiles: const [],
        statistics: const MiningStatistics(
          signalsAnalyzed: 0,
          clustersFound: 0,
          patternsExtracted: 0,
          duration: Duration.zero,
        ),
      ),
      stages: const [],
      metrics: PipelineMetrics.empty(),
    );
  }
}

/// Scope for pattern mining analysis.
enum PatternScope { signals, skillRuns, decisions, all }

/// Clustering algorithm options.
enum ClusteringAlgorithm { dbscan, hdbscan, kmeans, hierarchical }

/// Input for pattern mining pipeline.
class PatternMiningInput {
  final PatternScope scope;
  final Duration timeWindow;
  final int minOccurrences;
  final double minConfidence;
  final List<String>? domains;
  final ClusteringAlgorithm clusteringAlgorithm;
  final bool generateSkills;
  final bool generateProfiles;
  final bool notifyOnDiscovery;

  const PatternMiningInput({
    this.scope = PatternScope.all,
    this.timeWindow = const Duration(days: 30),
    this.minOccurrences = 3,
    this.minConfidence = 0.7,
    this.domains,
    this.clusteringAlgorithm = ClusteringAlgorithm.hdbscan,
    this.generateSkills = true,
    this.generateProfiles = true,
    this.notifyOnDiscovery = true,
  });
}

/// Output of pattern mining pipeline.
class PatternMiningOutput {
  final List<PatternSummary> patternsDiscovered;
  final List<SkillCandidate> candidateSkills;
  final List<ProfileCandidate> candidateProfiles;
  final MiningStatistics statistics;

  const PatternMiningOutput({
    required this.patternsDiscovered,
    required this.candidateSkills,
    required this.candidateProfiles,
    required this.statistics,
  });
}

/// Summary of a discovered pattern.
class PatternSummary {
  final String id;
  final String type;
  final int frequency;
  final double confidence;
  final List<String> examples;

  const PatternSummary({
    required this.id,
    required this.type,
    required this.frequency,
    required this.confidence,
    this.examples = const [],
  });
}

/// Candidate skill generated from a pattern.
class SkillCandidate {
  final String patternId;
  final String suggestedName;
  final double estimatedAccuracy;
  final String skillId;

  const SkillCandidate({
    required this.patternId,
    required this.suggestedName,
    required this.estimatedAccuracy,
    required this.skillId,
  });
}

/// Candidate profile generated from a pattern.
class ProfileCandidate {
  final String patternId;
  final String suggestedName;
  final double estimatedRelevance;
  final String profileId;

  const ProfileCandidate({
    required this.patternId,
    required this.suggestedName,
    required this.estimatedRelevance,
    required this.profileId,
  });
}

/// Mining statistics.
class MiningStatistics {
  final int signalsAnalyzed;
  final int clustersFound;
  final int patternsExtracted;
  final Duration duration;

  const MiningStatistics({
    required this.signalsAnalyzed,
    required this.clustersFound,
    required this.patternsExtracted,
    required this.duration,
  });
}

/// Feature vector for pattern mining.
class FeatureVector {
  final String factId;
  final List<double> values;
  final Map<String, dynamic> metadata;

  const FeatureVector({
    required this.factId,
    required this.values,
    this.metadata = const {},
  });
}

/// A cluster of similar signals.
class Cluster {
  final String id;
  final List<String> members;
  final List<double> centroid;
  final double cohesion;
  final String? label;

  const Cluster({
    required this.id,
    required this.members,
    required this.centroid,
    required this.cohesion,
    this.label,
  });
}
