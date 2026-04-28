/// Summary Refresh Pipeline - Declarative stage spec for summary refresh.
///
/// Per REDESIGN-PLAN.md Phase 7 (no-legacy), data-plane operations happen
/// through standard ports (`FactsPort`, `LlmPort`, `PhilosophyPort`) via
/// `HandlerContext.ports` — not direct port fields on the pipeline class.
library;

import '../pipeline.dart';

/// Pipeline for refreshing stale summaries with cascade support.
class SummaryRefreshPipeline
    implements Pipeline<SummaryRefreshInput, SummaryRefreshOutput> {
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

  SummaryRefreshPipeline({
    String? id,
    this.name = 'Summary Refresh Pipeline',
    this.version = '1.0.0',
    this.description =
        'Detect and refresh stale summaries with cascade support',
    PipelineConfig? config,
  })  : id = id ?? 'summary_refresh_pipeline',
        stages = _buildStages(),
        config = config ??
            const PipelineConfig(
              maxConcurrency: 3,
              onError: OnErrorStrategy.skip,
            );

  static List<PipelineStage> _buildStages() {
    return [
      const PipelineStage(
        id: 'detect_stale',
        name: 'Detect Stale Summaries',
        order: 1,
        handler: 'summary.detectStale',
        description:
            'Find stale summaries via FactsPort.queryFacts with period filter',
      ),
      const PipelineStage(
        id: 'prioritize',
        name: 'Prioritize Refresh',
        order: 2,
        handler: 'summary.prioritize',
        inputMapping: {'summaries': 'detect_stale'},
        description: 'Order by impact/dependency (pure)',
      ),
      const PipelineStage(
        id: 'philosophy_filter',
        name: 'Philosophy Filter',
        order: 3,
        handler: 'philosophy.intervene.preGeneration',
        inputMapping: {'prioritized': 'prioritize'},
        condition: 'ports.philosophy != null',
        description: 'Filter summaries through philosophy intervention',
      ),
      const PipelineStage(
        id: 'build_dependency_graph',
        name: 'Build Dependency Graph',
        order: 4,
        handler: 'summary.buildDependencyGraph',
        inputMapping: {'prioritized': 'philosophy_filter'},
        description:
            'Determine refresh order via FactsPort.queryFacts relationships',
      ),
      const PipelineStage(
        id: 'refresh_summaries',
        name: 'Refresh Summaries',
        order: 5,
        handler: 'summary.refresh',
        inputMapping: {'orderedSummaries': 'build_dependency_graph'},
        description:
            'Regenerate summary content via LlmPort.complete + FactsPort.writeFacts',
      ),
      const PipelineStage(
        id: 'cascade_refresh',
        name: 'Cascade Refresh',
        order: 6,
        handler: 'summary.cascadeRefresh',
        inputMapping: {'refreshed': 'refresh_summaries'},
        condition: 'config.cascadeEnabled',
        description:
            'BFS over dependent summaries via FactsPort.queryFacts + FactsPort.writeFacts',
      ),
      const PipelineStage(
        id: 'update_indexes',
        name: 'Update Indexes',
        order: 7,
        handler: 'summary.updateIndexes',
        inputMapping: {'refreshed': 'cascade_refresh'},
        description: 'Update search index metadata via FactsPort.writeFacts',
      ),
    ];
  }

  @override
  Future<PipelineResult<SummaryRefreshOutput>> run(
    SummaryRefreshInput input,
    PipelineContext context,
  ) async {
    return PipelineResult.success(
      output: const SummaryRefreshOutput(
        checked: 0,
        refreshed: 0,
        failed: 0,
        cascaded: 0,
      ),
      stages: const [],
      metrics: PipelineMetrics.empty(),
    );
  }
}

/// Scope for summary refresh.
enum SummaryScope { workspace, project, entity, domain }

/// Priority strategy for summary refresh ordering.
enum RefreshPriority { highImpactFirst, oldestFirst, cascadeOrder }

/// Input for summary refresh pipeline.
class SummaryRefreshInput {
  final SummaryScope? scope;
  final Duration staleness;
  final int maxRefresh;
  final RefreshPriority priority;
  final bool cascadeEnabled;

  const SummaryRefreshInput({
    this.scope,
    this.staleness = const Duration(hours: 24),
    this.maxRefresh = 50,
    this.priority = RefreshPriority.highImpactFirst,
    this.cascadeEnabled = true,
  });
}

/// Output of summary refresh pipeline.
class SummaryRefreshOutput {
  final int checked;
  final int refreshed;
  final int failed;
  final int cascaded;
  final List<String> refreshedIds;
  final List<String> failedIds;

  const SummaryRefreshOutput({
    required this.checked,
    required this.refreshed,
    required this.failed,
    required this.cascaded,
    this.refreshedIds = const [],
    this.failedIds = const [],
  });
}
