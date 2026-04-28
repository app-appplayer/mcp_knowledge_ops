/// Ingest Pipeline - Declarative stage specification for the ingest flow.
///
/// Per REDESIGN-PLAN.md Phase 7 (no-legacy), the pipeline class holds no
/// direct reference to consumer-sliced ports. Stages reference
/// capability-named handlers registered in `HandlerRegistry`, and the
/// engine injects a full `OpsPorts` into `HandlerContext` at runtime.
library;

import '../pipeline.dart';

/// Pipeline for ingesting content into the fact graph.
class IngestPipeline implements Pipeline<IngestInput, IngestOutput> {
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
  final IngestConfig config;

  IngestPipeline({
    String? id,
    this.name = 'Ingest Pipeline',
    this.version = '1.0.0',
    this.description = 'Ingest raw content into the fact graph',
    IngestConfig? config,
  })  : id = id ?? 'ingest_pipeline',
        stages = _buildStages(),
        config = config ?? const IngestConfig();

  static List<PipelineStage> _buildStages() {
    return [
      const PipelineStage(
        id: 'validate',
        name: 'Validate Input',
        order: 1,
        handler: 'ingest.validate',
        description: 'Validate ingest input content and metadata',
      ),
      const PipelineStage(
        id: 'store_evidence',
        name: 'Store Evidence',
        order: 2,
        handler: 'ingest.storeEvidence',
        inputMapping: {'validated': 'validate'},
        description:
            'Persist evidence via FactsPort.writeFacts (type: evidence)',
        retryConfig: RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(seconds: 1),
        ),
      ),
      const PipelineStage(
        id: 'extract_fragments',
        name: 'Extract Fragments',
        order: 3,
        handler: 'ingest.extractFragments',
        inputMapping: {'evidenceId': 'store_evidence'},
        description:
            'Extract fragments via EvidencePort.extractFragments (optional)',
      ),
      const PipelineStage(
        id: 'classify_fragments',
        name: 'Classify Fragments',
        order: 4,
        handler: 'ingest.classify',
        inputMapping: {'fragments': 'extract_fragments'},
        description: 'Classify extracted fragments by type and domain',
      ),
      const PipelineStage(
        id: 'philosophy_screen',
        name: 'Philosophy Screen',
        order: 5,
        handler: 'philosophy.intervene.preGeneration',
        inputMapping: {'fragments': 'classify_fragments'},
        condition: 'ports.philosophy != null',
        description: 'Screen ingested content against prohibitions',
      ),
      const PipelineStage(
        id: 'create_candidates',
        name: 'Create Candidates',
        order: 6,
        handler: 'ingest.createCandidates',
        inputMapping: {'fragments': 'philosophy_screen'},
        description:
            'Create fact candidates via ClaimsPort.writeClaims',
      ),
      const PipelineStage(
        id: 'link_entities',
        name: 'Link Entities',
        order: 7,
        handler: 'ingest.linkEntities',
        inputMapping: {'candidates': 'create_candidates'},
        description:
            'Link candidates to existing entities via FactsPort.queryFacts',
      ),
      const PipelineStage(
        id: 'auto_promote',
        name: 'Auto Promote',
        order: 8,
        handler: 'ingest.autoPromote',
        inputMapping: {'candidates': 'link_entities'},
        condition: 'config.autoPromote == true',
        description:
            'Validate + promote high-confidence candidates via '
            'ClaimsPort.validateClaims + FactsPort.writeFacts',
      ),
      const PipelineStage(
        id: 'queue_unresolved',
        name: 'Queue Unresolved',
        order: 9,
        handler: 'ingest.queueUnresolved',
        inputMapping: {'promoted': 'auto_promote'},
        description: 'Queue candidates via KvStoragePort.set',
      ),
      const PipelineStage(
        id: 'update_summaries',
        name: 'Update Summaries',
        order: 10,
        handler: 'ingest.markSummariesStale',
        inputMapping: {'promoted': 'auto_promote'},
        description:
            'Mark affected summaries stale via FactsPort.queryFacts + '
            'FactsPort.writeFacts',
      ),
    ];
  }

  /// Execute the pipeline.
  ///
  /// In the no-legacy rewrite, concrete pipelines are declarative specs.
  /// The canonical execution path is [ExecutionEngine.executePipeline]
  /// which resolves each stage handler via [HandlerRegistry] and invokes
  /// them with a full [OpsPorts] on [HandlerContext]. Direct invocation of
  /// [run] returns an empty success placeholder so callers that construct
  /// a pipeline for inspection (stage count, id, etc.) still compile.
  @override
  Future<PipelineResult<IngestOutput>> run(
    IngestInput input,
    PipelineContext context,
  ) async {
    return PipelineResult.success(
      output: const IngestOutput(
        evidenceId: '',
        fragmentCount: 0,
        candidateCount: 0,
        promotedCount: 0,
        unresolvedCount: 0,
      ),
      stages: const [],
      metrics: PipelineMetrics.empty(),
    );
  }
}

/// Input for the ingest pipeline.
class IngestInput {
  /// Raw content to ingest.
  final String content;

  /// Source type: "text" | "file" | "url" | "api".
  final String sourceType;

  /// MIME type of the content.
  final String? mimeType;

  /// Structured source metadata for provenance tracking.
  final IngestSourceInfo? source;

  /// Additional metadata.
  final Map<String, dynamic> metadata;

  /// Whether to auto-promote high-confidence candidates.
  final bool? autoPromote;

  /// Confidence threshold for auto-promotion.
  final double? autoPromoteThreshold;

  const IngestInput({
    required this.content,
    this.sourceType = 'text',
    this.mimeType,
    this.source,
    this.metadata = const {},
    this.autoPromote,
    this.autoPromoteThreshold,
  });
}

/// Output of the ingest pipeline.
class IngestOutput {
  final String evidenceId;
  final int fragmentCount;
  final int candidateCount;
  final int promotedCount;
  final int unresolvedCount;
  final bool skippedAsDuplicate;
  final IngestSourceInfo? source;
  final List<String> fragmentIds;
  final List<String> candidateIds;
  final List<String> promotedIds;
  final List<String> unresolvedIds;
  final List<FragmentSummary> fragments;
  final List<CandidateSummaryInfo> candidates;
  final List<FactSummary> facts;
  final List<UnresolvedItem> unresolved;

  const IngestOutput({
    required this.evidenceId,
    required this.fragmentCount,
    required this.candidateCount,
    required this.promotedCount,
    required this.unresolvedCount,
    this.skippedAsDuplicate = false,
    this.source,
    this.fragmentIds = const [],
    this.candidateIds = const [],
    this.promotedIds = const [],
    this.unresolvedIds = const [],
    this.fragments = const [],
    this.candidates = const [],
    this.facts = const [],
    this.unresolved = const [],
  });
}

/// Source metadata for ingest provenance tracking.
class IngestSourceInfo {
  final String name;
  final String? uri;
  final String? author;
  final DateTime? timestamp;

  const IngestSourceInfo({
    required this.name,
    this.uri,
    this.author,
    this.timestamp,
  });
}

/// Configuration for the ingest pipeline.
class IngestConfig extends PipelineConfig {
  final bool autoPromote;
  final double autoPromoteThreshold;
  final bool skipDuplicates;
  final String fragmentExtractor;
  final String entityLinkingStrategy;
  final Duration? duplicateCheckWindow;

  const IngestConfig({
    super.maxConcurrency = 1,
    super.timeout,
    super.retryPolicy,
    super.onError = OnErrorStrategy.fail,
    super.checkpointEnabled = false,
    super.extra = const {},
    this.autoPromote = true,
    this.autoPromoteThreshold = 0.85,
    this.skipDuplicates = false,
    this.fragmentExtractor = 'default',
    this.entityLinkingStrategy = 'strict',
    this.duplicateCheckWindow,
  });
}

/// Summary of an extracted fragment.
class FragmentSummary {
  final String id;
  final String sourceId;
  final String type;

  const FragmentSummary({
    required this.id,
    required this.sourceId,
    required this.type,
  });
}

/// Summary of a created candidate.
class CandidateSummaryInfo {
  final String id;
  final String fragmentId;
  final double confidence;

  const CandidateSummaryInfo({
    required this.id,
    required this.fragmentId,
    required this.confidence,
  });
}

/// Summary of a promoted fact.
class FactSummary {
  final String id;
  final String type;
  final double confidence;

  const FactSummary({
    required this.id,
    required this.type,
    required this.confidence,
  });
}

/// An unresolved item queued for review.
class UnresolvedItem {
  final String fragmentId;
  final String reason;

  const UnresolvedItem({
    required this.fragmentId,
    required this.reason,
  });
}
