/// Standard Runbooks - Pre-built operational runbook definitions.
///
/// Provides factory methods for common operational runbook patterns.
/// Concrete runbook definitions (daily ops, weekly review, incident recovery,
/// data migration) were removed in v0.2.0. This class serves as the
/// extension point for creating standard runbooks as needed.
library;

/// Factory class for creating standard operational runbooks.
///
/// Concrete runbook templates are defined externally as needed.
/// This class provides utility methods for common runbook patterns.
abstract final class StandardRunbooks {
  /// Philosophy alignment runbook definition.
  ///
  /// Provides steps for verifying and maintaining philosophy alignment
  /// across pipelines and workflows.
  static Map<String, dynamic> philosophyAlignmentRunbook() {
    return {
      'id': 'philosophy_alignment',
      'name': 'Philosophy Alignment Check',
      'description': 'Verify philosophy alignment across all pipelines '
          'and workflows. Run periodically or after ethos updates.',
      'steps': [
        {
          'id': 'check_ethos',
          'name': 'Verify Active Ethos',
          'action': 'philosophy.getEthos',
          'description': 'Retrieve and verify the currently active ethos.',
        },
        {
          'id': 'check_prohibitions',
          'name': 'Run Prohibition Checks',
          'action': 'philosophy.checkProhibitions',
          'description': 'Run prohibition checks against recent outputs.',
        },
        {
          'id': 'detect_tensions',
          'name': 'Detect Value Tensions',
          'action': 'philosophy.detectTensions',
          'description': 'Detect cross-layer value tensions in the system.',
        },
        {
          'id': 'review_interventions',
          'name': 'Review Recent Interventions',
          'action': 'observability.queryAuditLog',
          'parameters': {
            'category': 'philosophy',
            'timeWindow': 'P7D',
          },
          'description': 'Review philosophy interventions from the past week.',
        },
        {
          'id': 'generate_report',
          'name': 'Generate Alignment Report',
          'action': 'report.generate',
          'parameters': {
            'template': 'philosophy_alignment',
          },
          'description': 'Generate a summary report of philosophy alignment.',
        },
      ],
      'schedule': {
        'type': 'cron',
        'expression': '0 0 * * 0',
        'description': 'Weekly on Sunday at midnight',
      },
    };
  }
}
