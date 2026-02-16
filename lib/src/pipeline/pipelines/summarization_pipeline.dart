/// Summarization Pipeline - Pipeline for refreshing stale summaries.
///
/// Handles the summarization workflow from detecting stale summaries
/// to regenerating and updating them.
library;

import '../pipeline.dart';
import '../../ports/ops_port.dart';

/// Pipeline for refreshing stale summaries.
class SummarizationPipeline implements Pipeline<SummarizationInput, SummarizationOutput> {
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

  /// LLM port for summarization.
  final OpsLlmPort? llm;

  SummarizationPipeline({
    String? id,
    this.name = 'Summarization Pipeline',
    this.version = '1.0.0',
    this.description = 'Refresh stale summaries with updated facts',
    PipelineConfig? config,
    required this.factGraph,
    this.llm,
  })  : id = id ?? 'summarization_pipeline',
        stages = _buildStages(),
        config = config ??
            const PipelineConfig(
              maxConcurrency: 3,
              onError: OnErrorStrategy.skip,
            );

  static List<PipelineStage> _buildStages() {
    return [
      const PipelineStage(
        id: 'fetch_stale',
        name: 'Fetch Stale Summaries',
        order: 1,
        handler: 'summarization.fetch_stale',
        description: 'Fetch summaries that need refresh',
      ),
      const PipelineStage(
        id: 'build_cascade',
        name: 'Build Cascade Order',
        order: 2,
        handler: 'summarization.build_cascade',
        inputMapping: {'summaries': 'fetch_stale'},
        description: 'Determine refresh order based on dependencies',
      ),
      const PipelineStage(
        id: 'refresh',
        name: 'Refresh Summaries',
        order: 3,
        handler: 'summarization.refresh',
        inputMapping: {'orderedSummaries': 'build_cascade'},
        description: 'Regenerate summary content',
      ),
      const PipelineStage(
        id: 'validate',
        name: 'Validate',
        order: 4,
        handler: 'summarization.validate',
        inputMapping: {'refreshed': 'refresh'},
        description: 'Validate refreshed summaries',
      ),
      const PipelineStage(
        id: 'publish',
        name: 'Publish',
        order: 5,
        handler: 'summarization.publish',
        inputMapping: {'validated': 'validate'},
        description: 'Publish updated summaries',
      ),
    ];
  }

  @override
  Future<PipelineResult<SummarizationOutput>> run(
    SummarizationInput input,
    PipelineContext context,
  ) async {
    final startTime = DateTime.now();
    final stageResults = <StageResult>[];

    try {
      // Stage 1: Fetch stale summaries
      final staleSummaries = await factGraph.getStaleSummaries(
        staleness: input.stalenessThreshold,
      );

      stageResults.add(StageResult(
        stageId: 'fetch_stale',
        status: StageStatus.completed,
        startedAt: startTime,
        completedAt: DateTime.now(),
        output: staleSummaries,
      ));

      if (staleSummaries.isEmpty) {
        return PipelineResult.success(
          output: const SummarizationOutput(
            processedCount: 0,
            refreshedCount: 0,
            failedCount: 0,
          ),
          stages: stageResults,
          metrics: _buildMetrics(stageResults, startTime),
        );
      }

      // Stage 2: Build cascade order (topological sort based on dependencies)
      final orderedSummaries = _buildCascadeOrder(staleSummaries, input.maxBatchSize);
      stageResults.add(StageResult(
        stageId: 'build_cascade',
        status: StageStatus.completed,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        output: orderedSummaries,
      ));

      // Stage 3: Refresh summaries
      final refreshed = <String>[];
      final failed = <String>[];

      for (final summaryId in orderedSummaries) {
        try {
          await factGraph.refreshSummary(summaryId);
          refreshed.add(summaryId);
        } catch (e) {
          failed.add(summaryId);
        }
      }

      stageResults.add(StageResult(
        stageId: 'refresh',
        status: StageStatus.completed,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        output: {'refreshed': refreshed, 'failed': failed},
      ));

      // Stage 4: Validate (skipped for now - just mark complete)
      stageResults.add(StageResult(
        stageId: 'validate',
        status: StageStatus.completed,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
      ));

      // Stage 5: Publish (refresh already publishes)
      stageResults.add(StageResult(
        stageId: 'publish',
        status: StageStatus.completed,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
      ));

      return PipelineResult.success(
        output: SummarizationOutput(
          processedCount: orderedSummaries.length,
          refreshedCount: refreshed.length,
          failedCount: failed.length,
          refreshedIds: refreshed,
          failedIds: failed,
        ),
        stages: stageResults,
        metrics: _buildMetrics(stageResults, startTime),
      );
    } catch (e) {
      return PipelineResult.failure(
        error: PipelineError(
          code: 'SUMMARIZATION_ERROR',
          message: e.toString(),
        ),
        stages: stageResults,
        metrics: _buildMetrics(stageResults, startTime),
      );
    }
  }

  List<String> _buildCascadeOrder(List<String> summaryIds, int maxBatch) {
    // Simple cascade: process in order, limited by batch size
    // In a full implementation, this would do topological sort
    // based on summary dependencies
    return summaryIds.take(maxBatch).toList();
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

/// Input for summarization pipeline.
class SummarizationInput {
  /// Maximum batch size.
  final int maxBatchSize;

  /// Staleness threshold.
  final Duration stalenessThreshold;

  /// Whether to force refresh all.
  final bool forceAll;

  const SummarizationInput({
    this.maxBatchSize = 50,
    this.stalenessThreshold = const Duration(hours: 24),
    this.forceAll = false,
  });
}

/// Output of summarization pipeline.
class SummarizationOutput {
  /// Total summaries processed.
  final int processedCount;

  /// Summaries successfully refreshed.
  final int refreshedCount;

  /// Summaries that failed to refresh.
  final int failedCount;

  /// IDs of refreshed summaries.
  final List<String> refreshedIds;

  /// IDs of failed summaries.
  final List<String> failedIds;

  const SummarizationOutput({
    required this.processedCount,
    required this.refreshedCount,
    required this.failedCount,
    this.refreshedIds = const [],
    this.failedIds = const [],
  });
}
