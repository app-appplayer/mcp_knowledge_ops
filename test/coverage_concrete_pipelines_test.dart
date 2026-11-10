// The declarative pipelines' placeholder `run`, and their value classes.

import 'package:mcp_knowledge_ops/src/pipeline/pipeline.dart'
    show PipelineConfig, PipelineContext;
import 'package:mcp_knowledge_ops/src/pipeline/pipelines/curation_pipeline.dart';
import 'package:mcp_knowledge_ops/src/pipeline/pipelines/index_rebuild_pipeline.dart';
import 'package:mcp_knowledge_ops/src/pipeline/pipelines/ingest_pipeline.dart';
import 'package:mcp_knowledge_ops/src/pipeline/pipelines/pattern_mining_pipeline.dart';
import 'package:mcp_knowledge_ops/src/pipeline/pipelines/summary_refresh_pipeline.dart';
import 'package:test/test.dart';

PipelineContext _ctx() => PipelineContext(
    runId: 'r', workspaceId: 'w', config: const PipelineConfig());

void main() {
  test('declarative pipelines return an empty success when run directly',
      () async {
    final summary =
        await SummaryRefreshPipeline().run(const SummaryRefreshInput(), _ctx());
    expect(summary.success, isTrue);
    expect(summary.output!.checked, 0);
    final mining =
        await PatternMiningPipeline().run(const PatternMiningInput(), _ctx());
    expect(mining.output!.patternsDiscovered, isEmpty);
    expect(mining.output!.statistics.signalsAnalyzed, 0);
    final index =
        await IndexRebuildPipeline().run(const IndexRebuildInput(), _ctx());
    expect(index.output!.documentsIndexed, 0);
    final ingest =
        await IngestPipeline().run(const IngestInput(content: 'x'), _ctx());
    expect(ingest.output!.evidenceId, '');
    final curation =
        await CurationPipeline().run(const CurationInput(), _ctx());
    expect(curation.success, isTrue);
  });

  test('value classes keep what they are given', () {
    final candidate = ValidatedCandidate(candidateId: 'c', isValid: true);
    expect(candidate.newConfidence, 0.0);
    expect(candidate.validationErrors, isEmpty);

    final summary =
        PatternSummary(id: 'p', type: 't', frequency: 3, confidence: 0.5);
    expect(summary.examples, isEmpty);
    expect(
        SkillCandidate(
                patternId: 'p',
                suggestedName: 'n',
                estimatedAccuracy: 0.9,
                skillId: 's')
            .skillId,
        's');
    expect(
        ProfileCandidate(
                patternId: 'p',
                suggestedName: 'n',
                estimatedRelevance: 0.8,
                profileId: 'pr')
            .profileId,
        'pr');
    final stats = MiningStatistics(
        signalsAnalyzed: 1,
        clustersFound: 2,
        patternsExtracted: 3,
        duration: Duration.zero);
    final out = PatternMiningOutput(
        patternsDiscovered: [summary],
        candidateSkills: const [],
        candidateProfiles: const [],
        statistics: stats);
    expect(out.statistics.clustersFound, 2);
    expect(FeatureVector(factId: 'f', values: const [1.0]).metadata, isEmpty);
    expect(
        Cluster(
                id: 'c',
                members: const ['a'],
                centroid: const [0.5],
                cohesion: 0.9)
            .label,
        isNull);

    expect(IngestSourceInfo(name: 'n').uri, isNull);
    expect(FragmentSummary(id: 'f', sourceId: 's', type: 't').id, 'f');
    expect(
        CandidateSummaryInfo(id: 'c', fragmentId: 'f', confidence: 0.5)
            .confidence,
        0.5);
    expect(FactSummary(id: 'f', type: 't', confidence: 0.5).type, 't');
    expect(UnresolvedItem(fragmentId: 'f', reason: 'r').reason, 'r');
  });
}
