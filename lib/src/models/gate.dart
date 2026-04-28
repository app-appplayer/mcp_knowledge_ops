/// Gate - Quality gate models for workflow execution.
///
/// Defines gate structure, conditions, and evaluation results.
library;

/// Quality gate definition.
class Gate {
  /// Gate identifier.
  final String id;

  /// Gate name.
  final String name;

  /// Stage after which this gate is evaluated.
  final String afterStage;

  /// Conditions to evaluate.
  final List<GateCondition> conditions;

  /// Failure handling strategy.
  final GateFailure onFailure;

  /// Gate configuration.
  final Map<String, dynamic> config;

  const Gate({
    required this.id,
    required this.name,
    required this.afterStage,
    required this.conditions,
    this.onFailure = GateFailure.block,
    this.config = const {},
  });
}

/// Gate condition.
class GateCondition {
  /// Condition type.
  final ConditionType type;

  /// Metric name (for threshold conditions).
  final String? metric;

  /// Comparison operator (for threshold conditions).
  final String? operator;

  /// Target value.
  final dynamic value;

  /// Condition expression or configuration.
  final String? expression;

  /// Required approvers (for approval conditions).
  final List<String>? approvers;

  const GateCondition({
    required this.type,
    this.metric,
    this.operator,
    this.value,
    this.expression,
    this.approvers,
  });
}

/// Condition types.
enum ConditionType {
  /// Numeric threshold condition.
  threshold,

  /// Expression evaluation.
  expression,

  /// Human approval required.
  approval,
}

/// Gate failure handling strategy.
enum GateFailure {
  /// Block execution.
  block,

  /// Log warning and continue.
  warn,

  /// Log only.
  log,
}

/// Gate evaluation result.
class GateResult {
  /// Gate identifier.
  final String gateId;

  /// Whether gate passed.
  final bool passed;

  /// Individual condition results.
  final List<ConditionResult> conditionResults;

  /// When evaluation started.
  final DateTime evaluatedAt;

  /// Evaluation duration.
  final Duration? duration;

  const GateResult({
    required this.gateId,
    required this.passed,
    required this.conditionResults,
    required this.evaluatedAt,
    this.duration,
  });

  /// Create a passed result.
  factory GateResult.passed(String gateId, List<ConditionResult> results) {
    return GateResult(
      gateId: gateId,
      passed: true,
      conditionResults: results,
      evaluatedAt: DateTime.now(),
    );
  }

  /// Create a failed result.
  factory GateResult.failed(String gateId, List<ConditionResult> results) {
    return GateResult(
      gateId: gateId,
      passed: false,
      conditionResults: results,
      evaluatedAt: DateTime.now(),
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'gateId': gateId,
        'passed': passed,
        'conditionResults': conditionResults.map((r) => r.toJson()).toList(),
        'evaluatedAt': evaluatedAt.toIso8601String(),
        if (duration != null) 'durationMs': duration!.inMilliseconds,
      };
}

/// Individual condition evaluation result.
class ConditionResult {
  /// Condition identifier.
  final String conditionId;

  /// Whether condition passed.
  final bool passed;

  /// Actual value (for threshold conditions).
  final dynamic actual;

  /// Expected value or threshold.
  final dynamic expected;

  /// Explanation message.
  final String? message;

  const ConditionResult({
    required this.conditionId,
    required this.passed,
    this.actual,
    this.expected,
    this.message,
  });

  /// Create a passed result.
  factory ConditionResult.passed(String conditionId, {String? message}) {
    return ConditionResult(
      conditionId: conditionId,
      passed: true,
      message: message,
    );
  }

  /// Create a failed result.
  factory ConditionResult.failed(
    String conditionId, {
    dynamic actual,
    dynamic expected,
    String? message,
  }) {
    return ConditionResult(
      conditionId: conditionId,
      passed: false,
      actual: actual,
      expected: expected,
      message: message,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'conditionId': conditionId,
        'passed': passed,
        if (actual != null) 'actual': actual,
        if (expected != null) 'expected': expected,
        if (message != null) 'message': message,
      };
}
