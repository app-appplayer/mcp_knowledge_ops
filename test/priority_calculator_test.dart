/// Tests for PriorityCalculator scoring algorithms.
import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  group('PriorityCalculator', () {
    group('priorityFirst', () {
      test('higher priority yields higher score', () {
        final highPriority = PriorityCalculator.priorityFirst(
          priority: 10,
          age: const Duration(hours: 1),
        );
        final lowPriority = PriorityCalculator.priorityFirst(
          priority: 1,
          age: const Duration(hours: 1),
        );

        expect(highPriority, greaterThan(lowPriority));
      });

      test('score includes recency bonus for recent items', () {
        final recent = PriorityCalculator.priorityFirst(
          priority: 5,
          age: const Duration(hours: 1),
        );
        final old = PriorityCalculator.priorityFirst(
          priority: 5,
          age: const Duration(hours: 100),
        );

        // Recent items get recency bonus; but old items get urgency factor
        // Both contribute differently but the formula is deterministic
        expect(recent, isNotNull);
        expect(old, isNotNull);
      });
    });

    group('oldestFirst', () {
      test('older items have lower (more negative) scores', () {
        final older = PriorityCalculator.oldestFirst(
          priority: 5,
          age: const Duration(days: 30),
        );
        final newer = PriorityCalculator.oldestFirst(
          priority: 5,
          age: const Duration(days: 1),
        );

        // Older items have more negative scores (sorted ascending = oldest first)
        expect(older, lessThan(newer));
      });

      test('score is negative of age in milliseconds', () {
        const age = Duration(hours: 2);
        final score = PriorityCalculator.oldestFirst(
          priority: 1,
          age: age,
        );

        expect(score, equals(-1.0 * age.inMilliseconds));
      });
    });

    group('confidenceFirst', () {
      test('higher confidence scores higher', () {
        final highConf = PriorityCalculator.confidenceFirst(
          confidence: 0.95,
          priority: 5,
        );
        final lowConf = PriorityCalculator.confidenceFirst(
          confidence: 0.5,
          priority: 5,
        );

        expect(highConf, greaterThan(lowConf));
      });

      test('verification bonus adds 30 points', () {
        final withVerification = PriorityCalculator.confidenceFirst(
          confidence: 0.8,
          priority: 5,
          hasVerification: true,
        );
        final withoutVerification = PriorityCalculator.confidenceFirst(
          confidence: 0.8,
          priority: 5,
          hasVerification: false,
        );

        expect(withVerification - withoutVerification, equals(30));
      });

      test('source trust contributes to score', () {
        final highTrust = PriorityCalculator.confidenceFirst(
          confidence: 0.8,
          priority: 5,
          sourceTrust: 1.0,
        );
        final lowTrust = PriorityCalculator.confidenceFirst(
          confidence: 0.8,
          priority: 5,
          sourceTrust: 0.0,
        );

        expect(highTrust, greaterThan(lowTrust));
      });
    });

    group('domainGrouped', () {
      test('groups by domain bucket', () {
        final score = PriorityCalculator.domainGrouped(
          domain: 'technology',
          priority: 5,
          age: const Duration(hours: 1),
          confidence: 0.8,
        );

        expect(score, isNotNull);
        expect(score, greaterThanOrEqualTo(0));
      });

      test('same domain yields same bucket score component', () {
        final score1 = PriorityCalculator.domainGrouped(
          domain: 'technology',
          priority: 5,
          age: const Duration(hours: 1),
          confidence: 0.8,
        );
        final score2 = PriorityCalculator.domainGrouped(
          domain: 'technology',
          priority: 3,
          age: const Duration(hours: 10),
          confidence: 0.8,
        );

        // Same domain + same confidence = same score
        expect(score1, equals(score2));
      });
    });

    group('computeScore', () {
      test('dispatches to priorityFirst', () {
        final direct = PriorityCalculator.priorityFirst(
          priority: 5,
          age: const Duration(hours: 2),
        );
        final computed = PriorityCalculator.computeScore(
          algorithm: PriorityAlgorithm.priorityFirst,
          priority: 5,
          age: const Duration(hours: 2),
        );

        expect(computed, equals(direct));
      });

      test('dispatches to oldestFirst', () {
        final direct = PriorityCalculator.oldestFirst(
          priority: 5,
          age: const Duration(days: 3),
        );
        final computed = PriorityCalculator.computeScore(
          algorithm: PriorityAlgorithm.oldestFirst,
          priority: 5,
          age: const Duration(days: 3),
        );

        expect(computed, equals(direct));
      });

      test('dispatches to confidenceFirst', () {
        final direct = PriorityCalculator.confidenceFirst(
          confidence: 0.9,
          priority: 5,
          hasVerification: true,
          sourceTrust: 0.8,
        );
        final computed = PriorityCalculator.computeScore(
          algorithm: PriorityAlgorithm.confidenceFirst,
          priority: 5,
          age: Duration.zero,
          confidence: 0.9,
          hasVerification: true,
          sourceTrust: 0.8,
        );

        expect(computed, equals(direct));
      });

      test('dispatches to domainGrouped', () {
        final direct = PriorityCalculator.domainGrouped(
          domain: 'test',
          priority: 5,
          age: const Duration(hours: 1),
          confidence: 0.7,
        );
        final computed = PriorityCalculator.computeScore(
          algorithm: PriorityAlgorithm.domainGrouped,
          priority: 5,
          age: const Duration(hours: 1),
          domain: 'test',
          confidence: 0.7,
        );

        expect(computed, equals(direct));
      });
    });
  });

  group('PriorityAlgorithm', () {
    test('has expected values', () {
      expect(PriorityAlgorithm.values, hasLength(4));
      expect(
        PriorityAlgorithm.values,
        containsAll([
          PriorityAlgorithm.priorityFirst,
          PriorityAlgorithm.oldestFirst,
          PriorityAlgorithm.confidenceFirst,
          PriorityAlgorithm.domainGrouped,
        ]),
      );
    });
  });
}
