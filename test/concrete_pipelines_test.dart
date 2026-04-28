/// Tests for concrete pipeline definitions: Ingest, Curation,
/// SummaryRefresh, PatternMining, and IndexRebuild.
///
/// Per REDESIGN-PLAN.md Phase 7 (no-legacy), concrete pipelines are
/// declarative specs with no direct port fields. These tests verify
/// construction, id/name/version metadata, stage counts, and typed
/// input DTO defaults.
import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  group('IngestPipeline', () {
    test('construction with no args', () {
      final pipeline = IngestPipeline();

      expect(pipeline.id, equals('ingest_pipeline'));
      expect(pipeline.name, equals('Ingest Pipeline'));
      expect(pipeline.version, equals('1.0.0'));
    });

    test('stages getter returns non-empty list', () {
      final pipeline = IngestPipeline();

      expect(pipeline.stages, isNotEmpty);
      expect(pipeline.stages.length, greaterThanOrEqualTo(5));
    });

    test('custom id is accepted', () {
      final pipeline = IngestPipeline(id: 'custom_ingest');

      expect(pipeline.id, equals('custom_ingest'));
    });

    test('IngestInput creation with defaults', () {
      const input = IngestInput(content: 'test content');

      expect(input.content, equals('test content'));
      expect(input.sourceType, equals('text'));
      expect(input.mimeType, isNull);
      expect(input.metadata, isEmpty);
    });

    test('IngestInput creation with all fields', () {
      const input = IngestInput(
        content: 'test content',
        sourceType: 'url',
        mimeType: 'text/html',
        metadata: {'key': 'value'},
        autoPromote: true,
        autoPromoteThreshold: 0.9,
      );

      expect(input.sourceType, equals('url'));
      expect(input.mimeType, equals('text/html'));
      expect(input.autoPromote, isTrue);
      expect(input.autoPromoteThreshold, equals(0.9));
    });
  });

  group('CurationPipeline', () {
    test('construction with no args', () {
      final pipeline = CurationPipeline();

      expect(pipeline.id, equals('curation_pipeline'));
      expect(pipeline.name, equals('Curation Pipeline'));
      expect(pipeline.version, equals('1.0.0'));
    });

    test('stages getter returns non-empty list', () {
      final pipeline = CurationPipeline();

      expect(pipeline.stages, isNotEmpty);
    });

    test('CurationInput creation with defaults', () {
      const input = CurationInput();

      expect(input.maxCandidates, equals(100));
      expect(input.strategy, equals(CurationStrategy.priorityFirst));
      expect(input.confidenceThreshold, equals(0.7));
      expect(input.autoConfirm, isFalse);
      expect(input.filters, isNull);
    });

    test('CurationInput with filters', () {
      const input = CurationInput(
        maxCandidates: 50,
        strategy: CurationStrategy.confidenceFirst,
        confidenceThreshold: 0.8,
        filters: CurationFilters(
          domains: ['tech'],
          minConfidence: 0.5,
        ),
      );

      expect(input.maxCandidates, equals(50));
      expect(input.filters, isNotNull);
      expect(input.filters!.domains, contains('tech'));
    });
  });

  group('SummaryRefreshPipeline', () {
    test('construction with no args', () {
      final pipeline = SummaryRefreshPipeline();

      expect(pipeline.id, equals('summary_refresh_pipeline'));
      expect(pipeline.name, equals('Summary Refresh Pipeline'));
      expect(pipeline.version, equals('1.0.0'));
    });

    test('stages getter returns non-empty list', () {
      final pipeline = SummaryRefreshPipeline();

      expect(pipeline.stages, isNotEmpty);
    });

    test('SummaryRefreshInput creation with defaults', () {
      const input = SummaryRefreshInput();

      expect(input.staleness, equals(const Duration(hours: 24)));
      expect(input.maxRefresh, equals(50));
      expect(input.cascadeEnabled, isTrue);
    });
  });

  group('PatternMiningPipeline', () {
    test('construction with no args', () {
      final pipeline = PatternMiningPipeline();

      expect(pipeline.id, equals('pattern_mining_pipeline'));
      expect(pipeline.name, equals('Pattern Mining Pipeline'));
      expect(pipeline.version, equals('1.0.0'));
    });

    test('stages getter returns non-empty list', () {
      final pipeline = PatternMiningPipeline();

      expect(pipeline.stages, isNotEmpty);
    });

    test('PatternMiningInput creation', () {
      const input = PatternMiningInput(
        scope: PatternScope.signals,
        timeWindow: Duration(days: 7),
        minOccurrences: 3,
        minConfidence: 0.8,
      );

      expect(input.scope, equals(PatternScope.signals));
      expect(input.timeWindow, equals(const Duration(days: 7)));
      expect(input.minOccurrences, equals(3));
      expect(input.minConfidence, equals(0.8));
    });
  });

  group('IndexRebuildPipeline', () {
    test('construction with no args', () {
      final pipeline = IndexRebuildPipeline();

      expect(pipeline.id, equals('index_rebuild_pipeline'));
      expect(pipeline.name, equals('Index Rebuild Pipeline'));
      expect(pipeline.version, equals('1.0.0'));
    });

    test('stages getter returns non-empty list', () {
      final pipeline = IndexRebuildPipeline();

      expect(pipeline.stages, isNotEmpty);
    });

    test('IndexRebuildInput creation with defaults', () {
      const input = IndexRebuildInput();

      expect(input.indexes, isNull);
      expect(input.mode, equals(IndexRebuildMode.full));
      expect(input.since, isNull);
    });

    test('IndexRebuildInput with all fields', () {
      final input = IndexRebuildInput(
        indexes: ['facts', 'embeddings'],
        mode: IndexRebuildMode.incremental,
        since: DateTime(2024, 1, 1),
      );

      expect(input.indexes, hasLength(2));
      expect(input.mode, equals(IndexRebuildMode.incremental));
      expect(input.since, isNotNull);
    });
  });
}
