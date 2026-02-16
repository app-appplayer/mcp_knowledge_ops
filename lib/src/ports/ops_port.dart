/// Ops Ports - Abstract interfaces for knowledge ops dependencies.
///
/// Defines contracts for integrating with fact_graph, skill, profile, and bundle.
library;

/// Port for fact graph operations.
abstract class FactGraphPort {
  /// Create evidence from raw content.
  Future<String> createEvidence(EvidenceInput input);

  /// Extract fragments from evidence.
  Future<List<String>> extractFragments(String evidenceId);

  /// Create candidates from fragments.
  Future<List<String>> createCandidates(List<String> fragmentIds);

  /// Confirm a candidate.
  Future<String?> confirmCandidate(String candidateId);

  /// Get pending candidates.
  Future<List<CandidateSummary>> getPendingCandidates({int? limit});

  /// Mark summaries as stale.
  Future<void> markSummariesStale(List<String> eventIds);

  /// Refresh a summary.
  Future<void> refreshSummary(String summaryId);

  /// Get stale summaries.
  Future<List<String>> getStaleSummaries({Duration? staleness});

  /// Store pattern.
  Future<String> storePattern(PatternInput pattern);
}

/// Evidence input.
class EvidenceInput {
  /// Raw content.
  final String content;

  /// Source type.
  final String sourceType;

  /// MIME type.
  final String? mimeType;

  /// Metadata.
  final Map<String, dynamic> metadata;

  /// Source information.
  final SourceInfo? source;

  const EvidenceInput({
    required this.content,
    required this.sourceType,
    this.mimeType,
    this.metadata = const {},
    this.source,
  });
}

/// Source information.
class SourceInfo {
  /// Source URI.
  final String? uri;

  /// Author.
  final String? author;

  /// Timestamp.
  final DateTime? timestamp;

  const SourceInfo({
    this.uri,
    this.author,
    this.timestamp,
  });
}

/// Candidate summary.
class CandidateSummary {
  /// Candidate ID.
  final String candidateId;

  /// Object type.
  final String objectType;

  /// Confidence score.
  final double confidence;

  /// Unresolved issue count.
  final int unresolvedCount;

  /// Created at.
  final DateTime createdAt;

  const CandidateSummary({
    required this.candidateId,
    required this.objectType,
    required this.confidence,
    required this.unresolvedCount,
    required this.createdAt,
  });
}

/// Pattern input.
class PatternInput {
  /// Pattern type.
  final String type;

  /// Pattern criteria.
  final Map<String, dynamic> criteria;

  /// Confidence.
  final double confidence;

  /// Metadata.
  final Map<String, dynamic> metadata;

  const PatternInput({
    required this.type,
    required this.criteria,
    required this.confidence,
    this.metadata = const {},
  });
}

/// Port for skill operations.
abstract class SkillPort {
  /// Execute a skill.
  Future<SkillResult> executeSkill(
    String skillId,
    Map<String, dynamic> inputs,
  );

  /// Get available skills.
  Future<List<SkillInfo>> getAvailableSkills();

  /// Build skill from pattern.
  Future<String> buildSkillFromPattern(String patternId);
}

/// Skill execution result.
class SkillResult {
  /// Whether execution succeeded.
  final bool success;

  /// Output value.
  final dynamic output;

  /// Error message if failed.
  final String? error;

  /// Execution duration.
  final Duration duration;

  const SkillResult({
    required this.success,
    this.output,
    this.error,
    required this.duration,
  });
}

/// Skill information.
class SkillInfo {
  /// Skill ID.
  final String skillId;

  /// Skill name.
  final String name;

  /// Description.
  final String? description;

  /// Version.
  final String version;

  const SkillInfo({
    required this.skillId,
    required this.name,
    this.description,
    required this.version,
  });
}

/// Port for profile operations.
abstract class ProfilePort {
  /// Apply profile to context.
  Future<ProfileOutput> applyProfile(
    String profileId,
    Map<String, dynamic> context,
  );

  /// Build profile from pattern.
  Future<String> buildProfileFromPattern(String patternId);

  /// Evaluate output against profile.
  Future<EvaluationOutput> evaluate(
    String profileId,
    String content,
  );
}

/// Profile application output.
class ProfileOutput {
  /// Rendered prompt.
  final String prompt;

  /// Enabled capabilities.
  final List<String> capabilities;

  /// Metadata.
  final Map<String, dynamic> metadata;

  const ProfileOutput({
    required this.prompt,
    required this.capabilities,
    this.metadata = const {},
  });
}

/// Evaluation output.
class EvaluationOutput {
  /// Overall score.
  final double score;

  /// Dimension scores.
  final Map<String, double> dimensions;

  /// Issues found.
  final List<String> issues;

  const EvaluationOutput({
    required this.score,
    required this.dimensions,
    this.issues = const [],
  });
}

/// Port for bundle operations.
abstract class BundlePort {
  /// Create a bundle.
  Future<String> createBundle(BundleInput input);

  /// Sign a bundle.
  Future<SignedBundle> signBundle(String bundleId);

  /// Validate a bundle.
  Future<BundleValidation> validateBundle(String bundleId);
}

/// Bundle input.
class BundleInput {
  /// Bundle name.
  final String name;

  /// Bundle version.
  final String version;

  /// Skill IDs to include.
  final List<String> skillIds;

  /// Profile IDs to include.
  final List<String> profileIds;

  /// Asset paths.
  final List<String> assetPaths;

  /// Metadata.
  final Map<String, dynamic> metadata;

  const BundleInput({
    required this.name,
    required this.version,
    this.skillIds = const [],
    this.profileIds = const [],
    this.assetPaths = const [],
    this.metadata = const {},
  });
}

/// Signed bundle.
class SignedBundle {
  /// Bundle ID.
  final String bundleId;

  /// Signature.
  final String signature;

  /// Signed at.
  final DateTime signedAt;

  const SignedBundle({
    required this.bundleId,
    required this.signature,
    required this.signedAt,
  });
}

/// Bundle validation result.
class BundleValidation {
  /// Whether bundle is valid.
  final bool valid;

  /// Validation errors.
  final List<String> errors;

  /// Validation warnings.
  final List<String> warnings;

  const BundleValidation({
    required this.valid,
    this.errors = const [],
    this.warnings = const [],
  });
}

/// Port for LLM operations in orchestration.
abstract class OpsLlmPort {
  /// Complete a prompt.
  Future<LlmCompletion> complete(OpsLlmRequest request);

  /// Generate embeddings.
  Future<List<double>> embed(String text);
}

/// LLM request.
class OpsLlmRequest {
  /// System prompt.
  final String? systemPrompt;

  /// User prompt.
  final String prompt;

  /// Maximum tokens.
  final int? maxTokens;

  /// Temperature.
  final double? temperature;

  const OpsLlmRequest({
    this.systemPrompt,
    required this.prompt,
    this.maxTokens,
    this.temperature,
  });
}

/// LLM completion.
class LlmCompletion {
  /// Response content.
  final String content;

  /// Token usage.
  final int? tokensUsed;

  const LlmCompletion({
    required this.content,
    this.tokensUsed,
  });
}
