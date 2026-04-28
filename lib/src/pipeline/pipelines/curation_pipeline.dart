/// Curation Pipeline - Declarative stage spec for the curation flow.
///
/// Per REDESIGN-PLAN.md Phase 7 (no-legacy), the pipeline is a stage
/// specification. Data-plane operations happen via handlers that use
/// `FactsPort`, `ClaimsPort`, `AppraisalPort`, and `PhilosophyPort`
/// through `HandlerContext.ports`.
library;

import '../pipeline.dart';

/// Pipeline for curating candidates into facts.
class CurationPipeline implements Pipeline<CurationInput, CurationOutput> {
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

  CurationPipeline({
    String? id,
    this.name = 'Curation Pipeline',
    this.version = '1.0.0',
    this.description = 'Review and confirm candidates for fact creation',
    PipelineConfig? config,
  })  : id = id ?? 'curation_pipeline',
        stages = _buildStages(),
        config = config ??
            const PipelineConfig(
              maxConcurrency: 5,
              onError: OnErrorStrategy.skip,
            );

  static List<PipelineStage> _buildStages() {
    return [
      const PipelineStage(
        id: 'fetch_candidates',
        name: 'Fetch Queue Items',
        order: 1,
        handler: 'curation.fetchCandidates',
        description: 'Fetch pending claims via ClaimsPort.queryClaims',
      ),
      const PipelineStage(
        id: 'prioritize',
        name: 'Prioritize',
        order: 2,
        handler: 'curation.prioritize',
        inputMapping: {'candidates': 'fetch_candidates'},
        description: 'Sort candidates by priority (pure via PriorityCalculator)',
      ),
      const PipelineStage(
        id: 'enrich_context',
        name: 'Enrich Context',
        order: 3,
        handler: 'curation.enrichContext',
        inputMapping: {'candidates': 'prioritize'},
        description: 'Fetch related facts via FactsPort.queryFacts',
      ),
      const PipelineStage(
        id: 'philosophy_intervene',
        name: 'Philosophy Pre-Evaluation',
        order: 4,
        handler: 'philosophy.intervene.preGeneration',
        inputMapping: {'candidates': 'enrich_context'},
        condition: 'ports.philosophy != null',
        description:
            'Filter/rank candidates based on value priorities and prohibitions',
      ),
      const PipelineStage(
        id: 'evaluate_candidates',
        name: 'Evaluate Candidates',
        order: 5,
        handler: 'curation.evaluateCandidates',
        inputMapping: {'candidates': 'philosophy_intervene'},
        description: 'Re-evaluate confidence via AppraisalPort.appraise',
      ),
      const PipelineStage(
        id: 'auto_resolve',
        name: 'Auto Resolve',
        order: 6,
        handler: 'curation.autoResolve',
        inputMapping: {'candidates': 'evaluate_candidates'},
        condition: 'item.newConfidence >= config.autoResolveThreshold',
        description:
            'Auto-resolve via ClaimsPort.updateClaimStatus + FactsPort.writeFacts',
      ),
      const PipelineStage(
        id: 'merge_duplicates',
        name: 'Merge Duplicates',
        order: 7,
        handler: 'curation.mergeDuplicates',
        inputMapping: {'confirmed': 'auto_resolve'},
        description:
            'Merge duplicates via FactsPort.queryFacts + FactsPort.deleteFacts',
      ),
      const PipelineStage(
        id: 'update_queue',
        name: 'Update Queue',
        order: 8,
        handler: 'curation.updateQueue',
        inputMapping: {'confirmed': 'merge_duplicates'},
        description: 'Update the candidate queue via KvStoragePort.set',
      ),
      const PipelineStage(
        id: 'emit_signals',
        name: 'Emit Signals',
        order: 9,
        handler: 'curation.emitSignals',
        inputMapping: {'queued': 'update_queue'},
        description:
            'Emit signals via EventPort.publish (optional) for downstream consumers',
      ),
    ];
  }

  @override
  Future<PipelineResult<CurationOutput>> run(
    CurationInput input,
    PipelineContext context,
  ) async {
    return PipelineResult.success(
      output: const CurationOutput(
        processed: 0,
        confirmedCount: 0,
        rejectedCount: 0,
        deferredCount: 0,
        merged: 0,
      ),
      stages: const [],
      metrics: PipelineMetrics.empty(),
    );
  }
}

/// Input for curation pipeline.
class CurationInput {
  final int maxCandidates;
  final CurationStrategy strategy;
  final double confidenceThreshold;
  final bool autoConfirm;
  final CurationFilters? filters;

  const CurationInput({
    this.maxCandidates = 100,
    this.strategy = CurationStrategy.priorityFirst,
    this.confidenceThreshold = 0.7,
    this.autoConfirm = false,
    this.filters,
  });
}

/// Filters for narrowing the curation scope.
class CurationFilters {
  final List<String>? domains;
  final double? minConfidence;
  final double? maxConfidence;
  final List<String>? reasonCodes;
  final DateTime? createdAfter;
  final DateTime? createdBefore;

  const CurationFilters({
    this.domains,
    this.minConfidence,
    this.maxConfidence,
    this.reasonCodes,
    this.createdAfter,
    this.createdBefore,
  });
}

/// Output of curation pipeline.
class CurationOutput {
  final int processed;
  final int confirmedCount;
  final int rejectedCount;
  final int deferredCount;
  final int merged;
  final List<String> confirmedIds;
  final List<String> rejectedIds;

  const CurationOutput({
    required this.processed,
    required this.confirmedCount,
    required this.rejectedCount,
    required this.deferredCount,
    required this.merged,
    this.confirmedIds = const [],
    this.rejectedIds = const [],
  });
}

/// Curation strategy.
enum CurationStrategy {
  priorityFirst,
  oldestFirst,
  confidenceFirst,
  domainGrouped,
}

/// Validated candidate with re-evaluated confidence.
class ValidatedCandidate {
  final String candidateId;
  final bool isValid;
  final double newConfidence;
  final List<String> validationErrors;

  const ValidatedCandidate({
    required this.candidateId,
    required this.isValid,
    this.newConfidence = 0.0,
    this.validationErrors = const [],
  });
}
