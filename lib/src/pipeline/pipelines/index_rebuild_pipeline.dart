/// Index Rebuild Pipeline - Declarative stage spec for index rebuild.
///
/// Per REDESIGN-PLAN.md Phase 7 (no-legacy), handlers reach `FactsPort`
/// and `KvStoragePort` via `HandlerContext.ports`. IndexRebuildPipeline
/// has no philosophy stage (FR-CPIPE-008) because it performs no
/// value-directed decisions.
library;

import '../pipeline.dart';

/// Pipeline for rebuilding search indexes.
class IndexRebuildPipeline
    implements Pipeline<IndexRebuildInput, IndexRebuildOutput> {
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

  IndexRebuildPipeline({
    String? id,
    this.name = 'Index Rebuild Pipeline',
    this.version = '1.0.0',
    this.description = 'Rebuild search indexes from fact graph data',
    PipelineConfig? config,
  })  : id = id ?? 'index_rebuild_pipeline',
        stages = _buildStages(),
        config = config ??
            const PipelineConfig(
              maxConcurrency: 1,
              onError: OnErrorStrategy.fail,
              timeout: Duration(hours: 1),
            );

  static List<PipelineStage> _buildStages() {
    return [
      const PipelineStage(
        id: 'snapshot',
        name: 'Snapshot',
        order: 1,
        handler: 'index.snapshot',
        description: 'Create rollback snapshot via FactsPort.queryFacts',
      ),
      const PipelineStage(
        id: 'rebuild_segments',
        name: 'Rebuild Segments',
        order: 2,
        handler: 'index.rebuild',
        inputMapping: {'snapshot': 'snapshot'},
        description: 'Rebuild index segments via FactsPort.queryFacts',
      ),
      const PipelineStage(
        id: 'verify',
        name: 'Verify',
        order: 3,
        handler: 'index.verify',
        inputMapping: {'rebuilt': 'rebuild_segments'},
        description: 'Verify index integrity via FactsPort.queryFacts',
      ),
      const PipelineStage(
        id: 'swap',
        name: 'Swap',
        order: 4,
        handler: 'index.swap',
        inputMapping: {'verified': 'verify'},
        description: 'Atomic index swap via KvStoragePort.set',
      ),
      const PipelineStage(
        id: 'cleanup',
        name: 'Cleanup',
        order: 5,
        handler: 'index.cleanup',
        inputMapping: {'swapped': 'swap'},
        description: 'Remove old segments via KvStoragePort.remove',
      ),
    ];
  }

  @override
  Future<PipelineResult<IndexRebuildOutput>> run(
    IndexRebuildInput input,
    PipelineContext context,
  ) async {
    return PipelineResult.success(
      output: const IndexRebuildOutput(
        indexesRebuilt: [],
        documentsIndexed: 0,
        duration: Duration.zero,
      ),
      stages: const [],
      metrics: PipelineMetrics.empty(),
    );
  }
}

/// Input for the index rebuild pipeline.
class IndexRebuildInput {
  final List<String>? indexes;
  final IndexRebuildMode mode;
  final DateTime? since;

  const IndexRebuildInput({
    this.indexes,
    this.mode = IndexRebuildMode.full,
    this.since,
  });
}

/// Output of the index rebuild pipeline.
class IndexRebuildOutput {
  final List<String> indexesRebuilt;
  final int documentsIndexed;
  final Duration duration;

  const IndexRebuildOutput({
    required this.indexesRebuilt,
    required this.documentsIndexed,
    required this.duration,
  });
}

/// Index rebuild mode.
enum IndexRebuildMode { full, incremental }
