/// Curation Pipeline - Pipeline for reviewing and confirming candidates.
///
/// Handles the curation workflow from candidate review to fact confirmation.
library;

import '../pipeline.dart';
import '../../ports/ops_port.dart';

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

  /// Fact graph port.
  final FactGraphPort factGraph;

  CurationPipeline({
    String? id,
    this.name = 'Curation Pipeline',
    this.version = '1.0.0',
    this.description = 'Review and confirm candidates for fact creation',
    PipelineConfig? config,
    required this.factGraph,
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
        name: 'Fetch Candidates',
        order: 1,
        handler: 'curation.fetch_candidates',
        description: 'Fetch pending candidates for review',
      ),
      const PipelineStage(
        id: 'prioritize',
        name: 'Prioritize',
        order: 2,
        handler: 'curation.prioritize',
        inputMapping: {'candidates': 'fetch_candidates'},
        description: 'Sort candidates by priority',
      ),
      const PipelineStage(
        id: 'validate',
        name: 'Validate',
        order: 3,
        handler: 'curation.validate',
        inputMapping: {'candidates': 'prioritize'},
        description: 'Validate candidate quality',
      ),
      const PipelineStage(
        id: 'confirm',
        name: 'Confirm',
        order: 4,
        handler: 'curation.confirm',
        inputMapping: {'candidates': 'validate'},
        description: 'Confirm valid candidates',
      ),
      const PipelineStage(
        id: 'mark_stale',
        name: 'Mark Stale',
        order: 5,
        handler: 'curation.mark_stale',
        inputMapping: {'confirmed': 'confirm'},
        description: 'Mark affected summaries as stale',
      ),
    ];
  }

  @override
  Future<PipelineResult<CurationOutput>> run(
    CurationInput input,
    PipelineContext context,
  ) async {
    final startTime = DateTime.now();
    final stageResults = <StageResult>[];

    try {
      // Stage 1: Fetch candidates
      final candidates = await factGraph.getPendingCandidates(
        limit: input.maxCandidates,
      );

      stageResults.add(StageResult(
        stageId: 'fetch_candidates',
        status: StageStatus.completed,
        startedAt: startTime,
        completedAt: DateTime.now(),
        output: candidates,
      ));

      if (candidates.isEmpty) {
        return PipelineResult.success(
          output: CurationOutput(
            processedCount: 0,
            confirmedCount: 0,
            rejectedCount: 0,
            skippedCount: 0,
          ),
          stages: stageResults,
          metrics: _buildMetrics(stageResults, startTime),
        );
      }

      // Stage 2: Prioritize
      final prioritized = _prioritizeCandidates(candidates, input.strategy);
      stageResults.add(StageResult(
        stageId: 'prioritize',
        status: StageStatus.completed,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        output: prioritized,
      ));

      // Stage 3: Validate
      final validated = await _validateCandidates(prioritized);
      stageResults.add(StageResult(
        stageId: 'validate',
        status: StageStatus.completed,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        output: validated,
      ));

      // Stage 4: Confirm
      final confirmed = <String>[];
      final rejected = <String>[];

      for (final candidate in validated.where((c) => c.isValid)) {
        try {
          final factId = await factGraph.confirmCandidate(candidate.candidateId);
          if (factId != null) {
            confirmed.add(candidate.candidateId);
          } else {
            rejected.add(candidate.candidateId);
          }
        } catch (e) {
          rejected.add(candidate.candidateId);
        }
      }

      stageResults.add(StageResult(
        stageId: 'confirm',
        status: StageStatus.completed,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        output: {'confirmed': confirmed, 'rejected': rejected},
      ));

      // Stage 5: Mark affected summaries as stale
      if (confirmed.isNotEmpty) {
        await factGraph.markSummariesStale(confirmed);
      }

      stageResults.add(StageResult(
        stageId: 'mark_stale',
        status: StageStatus.completed,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
      ));

      return PipelineResult.success(
        output: CurationOutput(
          processedCount: candidates.length,
          confirmedCount: confirmed.length,
          rejectedCount: rejected.length,
          skippedCount: validated.where((c) => !c.isValid).length,
          confirmedIds: confirmed,
          rejectedIds: rejected,
        ),
        stages: stageResults,
        metrics: _buildMetrics(stageResults, startTime),
      );
    } catch (e) {
      return PipelineResult.failure(
        error: PipelineError(
          code: 'CURATION_ERROR',
          message: e.toString(),
        ),
        stages: stageResults,
        metrics: _buildMetrics(stageResults, startTime),
      );
    }
  }

  List<CandidateSummary> _prioritizeCandidates(
    List<CandidateSummary> candidates,
    CurationStrategy strategy,
  ) {
    final sorted = List<CandidateSummary>.from(candidates);

    switch (strategy) {
      case CurationStrategy.priorityFirst:
        // Higher confidence + lower unresolved count = higher priority
        sorted.sort((a, b) {
          final scoreA = a.confidence - (a.unresolvedCount * 0.1);
          final scoreB = b.confidence - (b.unresolvedCount * 0.1);
          return scoreB.compareTo(scoreA);
        });
        break;
      case CurationStrategy.oldestFirst:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case CurationStrategy.confidenceFirst:
        sorted.sort((a, b) => b.confidence.compareTo(a.confidence));
        break;
      case CurationStrategy.domainGrouped:
        sorted.sort((a, b) => a.objectType.compareTo(b.objectType));
        break;
    }

    return sorted;
  }

  Future<List<ValidatedCandidate>> _validateCandidates(
    List<CandidateSummary> candidates,
  ) async {
    return candidates.map((c) {
      // Basic validation: confidence threshold
      final isValid = c.confidence >= 0.7 && c.unresolvedCount == 0;
      return ValidatedCandidate(
        candidateId: c.candidateId,
        isValid: isValid,
        validationErrors: isValid
            ? []
            : [
                if (c.confidence < 0.7) 'Confidence below threshold',
                if (c.unresolvedCount > 0) 'Has unresolved issues',
              ],
      );
    }).toList();
  }

  PipelineMetrics _buildMetrics(
    List<StageResult> stageResults,
    DateTime startTime,
  ) {
    final stageDurations = <String, Duration>{};
    for (final result in stageResults) {
      if (result.duration != null) {
        stageDurations[result.stageId] = result.duration!;
      }
    }

    return PipelineMetrics(
      totalDuration: DateTime.now().difference(startTime),
      stageDurations: stageDurations,
      itemsProcessed: stageResults.length,
      itemsFailed: stageResults.where((r) => r.status == StageStatus.failed).length,
    );
  }
}

/// Input for curation pipeline.
class CurationInput {
  /// Maximum candidates to process.
  final int maxCandidates;

  /// Curation strategy.
  final CurationStrategy strategy;

  /// Confidence threshold.
  final double confidenceThreshold;

  /// Whether to auto-confirm high-confidence candidates.
  final bool autoConfirm;

  const CurationInput({
    this.maxCandidates = 100,
    this.strategy = CurationStrategy.priorityFirst,
    this.confidenceThreshold = 0.7,
    this.autoConfirm = false,
  });
}

/// Output of curation pipeline.
class CurationOutput {
  /// Total candidates processed.
  final int processedCount;

  /// Candidates confirmed.
  final int confirmedCount;

  /// Candidates rejected.
  final int rejectedCount;

  /// Candidates skipped.
  final int skippedCount;

  /// IDs of confirmed candidates.
  final List<String> confirmedIds;

  /// IDs of rejected candidates.
  final List<String> rejectedIds;

  const CurationOutput({
    required this.processedCount,
    required this.confirmedCount,
    required this.rejectedCount,
    required this.skippedCount,
    this.confirmedIds = const [],
    this.rejectedIds = const [],
  });
}

/// Curation strategy.
enum CurationStrategy {
  /// Process high-priority candidates first.
  priorityFirst,

  /// Process oldest candidates first.
  oldestFirst,

  /// Process highest confidence first.
  confidenceFirst,

  /// Group by domain before processing.
  domainGrouped,
}

/// Validated candidate.
class ValidatedCandidate {
  /// Candidate ID.
  final String candidateId;

  /// Whether candidate is valid.
  final bool isValid;

  /// Validation errors.
  final List<String> validationErrors;

  const ValidatedCandidate({
    required this.candidateId,
    required this.isValid,
    this.validationErrors = const [],
  });
}
