/// Priority Calculator - Scoring algorithms for curation queue ordering.
///
/// Implements the four priority algorithms defined in the pipelines spec
/// section 4.1 for the CurationPipeline's prioritize stage.
library;

import 'dart:math';

/// Available priority calculation algorithms per spec section 4.1.
enum PriorityAlgorithm {
  /// High-priority items first with recency and urgency bonuses.
  priorityFirst,

  /// FIFO ordering by creation time (oldest first).
  oldestFirst,

  /// Highest confidence items first with verification bonuses.
  confidenceFirst,

  /// Group by domain bucket, then sort by confidence within each group.
  domainGrouped,
}

/// Scoring functions for curation queue item ordering.
///
/// Each method computes a numeric score used to sort queue items.
/// Higher scores are processed first (except oldest_first which uses
/// negative timestamps so that the oldest item has the lowest score).
class PriorityCalculator {
  /// Priority-first scoring per spec section 4.1.
  ///
  /// Formula: score = (base_priority * 10) + recency_bonus + urgency_factor
  ///
  /// Where:
  ///   recency_bonus = max(0, 50 - hours_since_creation)
  ///   urgency_factor = min(50, days_in_queue * 2)
  static double priorityFirst({
    required int priority,
    required Duration age,
  }) {
    final hoursSinceCreation = age.inHours;
    final daysSinceCreation = age.inDays;

    final recencyBonus = max(0, 50 - hoursSinceCreation);
    final urgencyFactor = min(50, daysSinceCreation * 2);

    return priority * 10.0 + recencyBonus + urgencyFactor;
  }

  /// Oldest-first scoring (FIFO) per spec section 4.1.
  ///
  /// Formula: score = -1 * creation_timestamp_millis
  ///
  /// Lower (more negative) scores correspond to older items, which
  /// should be processed first when sorting ascending.
  static double oldestFirst({
    required int priority,
    required Duration age,
  }) {
    // Negate the age in hours so older items have lower scores.
    // When sorted ascending, older items come first.
    return -1.0 * age.inMilliseconds;
  }

  /// Confidence-first scoring per spec section 4.1.
  ///
  /// Formula: score = (confidence * 100) + verification_bonus + (source_trust * 20)
  ///
  /// Where:
  ///   verification_bonus = has_verification ? 30 : 0
  ///   source_trust = trust_score (default 0.5)
  static double confidenceFirst({
    required double confidence,
    required int priority,
    bool hasVerification = false,
    double sourceTrust = 0.5,
  }) {
    final verificationBonus = hasVerification ? 30 : 0;
    return confidence * 100 + verificationBonus + sourceTrust * 20;
  }

  /// Domain-grouped scoring per spec section 4.1.
  ///
  /// Formula: score = (domain_bucket * 1000) + (confidence * 100)
  ///
  /// Where:
  ///   domain_bucket = hash(domain) % num_buckets
  static double domainGrouped({
    required String domain,
    required int priority,
    required Duration age,
    double confidence = 0.5,
    int numBuckets = 100,
  }) {
    final domainBucket = domain.hashCode.abs() % numBuckets;
    return domainBucket * 1000.0 + confidence * 100;
  }

  /// Select and compute the score for a queue item based on the algorithm.
  static double computeScore({
    required PriorityAlgorithm algorithm,
    required int priority,
    required Duration age,
    double confidence = 0.5,
    String domain = '',
    bool hasVerification = false,
    double sourceTrust = 0.5,
    int numBuckets = 100,
  }) {
    switch (algorithm) {
      case PriorityAlgorithm.priorityFirst:
        return priorityFirst(priority: priority, age: age);
      case PriorityAlgorithm.oldestFirst:
        return oldestFirst(priority: priority, age: age);
      case PriorityAlgorithm.confidenceFirst:
        return confidenceFirst(
          confidence: confidence,
          priority: priority,
          hasVerification: hasVerification,
          sourceTrust: sourceTrust,
        );
      case PriorityAlgorithm.domainGrouped:
        return domainGrouped(
          domain: domain,
          priority: priority,
          age: age,
          confidence: confidence,
          numBuckets: numBuckets,
        );
    }
  }
}
