/// Philosophy integration smoke tests.
///
/// Per REDESIGN-PLAN.md Phase 7 (no-legacy), this suite verifies the
/// minimal contract that `OpsPorts` honours philosophy graceful
/// degradation, and that each pipeline declares (or omits) a
/// philosophy stage as required by the spec. Detailed handler-level
/// philosophy tests live in the philosophy-specific test suites of
/// `mcp_philosophy`.
///
/// The previous philosophy-integration suite exercised the legacy
/// imperative pipeline bodies that directly called `FactGraphPort`.
/// Those tests are obsolete under the no-legacy rewrite where concrete
/// pipelines are declarative specs whose imperative behaviour happens
/// through `ExecutionEngine` + registered handlers.
library;

import 'package:mcp_bundle/src/ports/philosophy_port.dart' as phil;
import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

void main() {
  group('OpsPorts philosophy wiring', () {
    test('MockPhilosophyPort is reachable through OpsPorts', () async {
      final ports = TestOpsPorts().toOpsPorts();

      final result = await ports.philosophy.checkProhibitions(
        ProhibitionCheckRequest(
          proposedAction: 'test',
          proposedOutput: 'test output',
        ),
      );

      expect(result.hasHardViolation, isFalse);
    });

    test('Philosophy intervention mock returns InterventionResult', () async {
      final testPorts = TestOpsPorts();
      final result = await testPorts.philosophy.intervene(
        InterventionPoint.preGeneration,
        phil.PipelineContext(
          pipelineId: 'test',
          currentPoint: InterventionPoint.preGeneration,
        ),
      );

      expect(result, isNotNull);
      expect(result.prohibitionViolated, isFalse);
    });

    test('blockDelivery flag toggles intervention result', () async {
      final testPorts = TestOpsPorts();
      testPorts.philosophy.blockDelivery = true;

      final result = await testPorts.philosophy.intervene(
        InterventionPoint.preGeneration,
        phil.PipelineContext(
          pipelineId: 'test',
          currentPoint: InterventionPoint.preGeneration,
        ),
      );

      expect(result.prohibitionViolated, isTrue);
    });
  });

  group('Concrete pipelines with OpsRuntime', () {
    test('OpsRuntime.fromConsumedPorts registers philosophy-aware pipelines',
        () {
      final consumed = TestOpsPorts().toConsumedOpsPorts();
      final runtime = OpsRuntime.fromConsumedPorts(consumed);

      // All 5 pipelines are registered — each includes at least one
      // philosophy_* stage except IndexRebuildPipeline.
      expect(runtime.pipelineRegistry.containsKey('ingest_pipeline'), isTrue);
      expect(
        runtime.pipelineRegistry.containsKey('curation_pipeline'),
        isTrue,
      );
      expect(
        runtime.pipelineRegistry.containsKey('summary_refresh_pipeline'),
        isTrue,
      );
      expect(
        runtime.pipelineRegistry.containsKey('pattern_mining_pipeline'),
        isTrue,
      );
      expect(
        runtime.pipelineRegistry.containsKey('index_rebuild_pipeline'),
        isTrue,
      );
    });

    test('IngestPipeline declares a philosophy_screen stage', () {
      final pipeline = IngestPipeline();
      final philosophyStages = pipeline.stages
          .where((s) => s.handler.startsWith('philosophy.'))
          .toList();
      expect(philosophyStages, isNotEmpty);
    });

    test('IndexRebuildPipeline has no philosophy stage (FR-CPIPE-008)', () {
      final pipeline = IndexRebuildPipeline();
      final philosophyStages = pipeline.stages
          .where((s) => s.handler.startsWith('philosophy.'))
          .toList();
      expect(philosophyStages, isEmpty);
    });
  });
}
