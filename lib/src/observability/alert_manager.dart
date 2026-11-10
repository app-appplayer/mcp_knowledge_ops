/// Alert Manager - Alerting for observability.
///
/// Provides alert rule management and evaluation for pipeline and workflow execution.
library;

import 'metrics_collector.dart';

/// Alert severity.
enum AlertSeverity {
  info,
  warning,
  critical,
  emergency,
}

/// Alert state.
enum AlertState {
  pending,
  firing,
  acknowledged,
  resolved,
}

/// Alert condition type.
enum AlertConditionType {
  metric,
  log,
  expression,
}

/// Alert action type.
enum AlertActionType {
  notify,
  webhook,
  email,
  slack,
  pagerduty,
  runbook,
}

/// Alert condition definition.
class AlertCondition {
  /// Condition type.
  final AlertConditionType type;

  /// Metric name (for metric conditions).
  final String? metric;

  /// Comparison operator (e.g. '>', '<', '>=', '<=', '==', '!=').
  final String? operator;

  /// Threshold value (for metric conditions).
  final double? threshold;

  /// Aggregation function (e.g. 'avg', 'sum', 'max', 'min', 'count').
  final String? aggregation;

  /// Time window for aggregation.
  final Duration? window;

  /// Log query string (for log conditions).
  final String? logQuery;

  /// Count threshold (for log conditions).
  final int? countThreshold;

  /// Expression string (for expression conditions).
  final String? expression;

  const AlertCondition({
    required this.type,
    this.metric,
    this.operator,
    this.threshold,
    this.aggregation,
    this.window,
    this.logQuery,
    this.countThreshold,
    this.expression,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (metric != null) 'metric': metric,
        if (operator != null) 'operator': operator,
        if (threshold != null) 'threshold': threshold,
        if (aggregation != null) 'aggregation': aggregation,
        if (window != null) 'window': window!.inMilliseconds,
        if (logQuery != null) 'logQuery': logQuery,
        if (countThreshold != null) 'countThreshold': countThreshold,
        if (expression != null) 'expression': expression,
      };
}

/// Alert action definition.
class AlertAction {
  /// Action type.
  final AlertActionType type;

  /// Action configuration.
  final Map<String, dynamic> config;

  /// Delay before executing action.
  final Duration? delay;

  /// Interval between repeated actions.
  final Duration? repeatInterval;

  const AlertAction({
    required this.type,
    this.config = const {},
    this.delay,
    this.repeatInterval,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (config.isNotEmpty) 'config': config,
        if (delay != null) 'delay': delay!.inMilliseconds,
        if (repeatInterval != null)
          'repeatInterval': repeatInterval!.inMilliseconds,
      };
}

/// Alert rule definition.
class AlertRule {
  /// Rule ID.
  final String id;

  /// Rule name.
  final String name;

  /// Rule description.
  final String description;

  /// Alert condition.
  final AlertCondition condition;

  /// Alert severity.
  final AlertSeverity severity;

  /// Duration the condition must be true before firing.
  final Duration? forDuration;

  /// Evaluation interval.
  final Duration? interval;

  /// Actions to execute when alert fires.
  final List<AlertAction> actions;

  /// Labels for the alert.
  final Map<String, String>? labels;

  /// Annotations for the alert.
  final Map<String, String>? annotations;

  /// Whether the rule is enabled.
  final bool enabled;

  const AlertRule({
    required this.id,
    required this.name,
    this.description = '',
    required this.condition,
    this.severity = AlertSeverity.warning,
    this.forDuration,
    this.interval,
    this.actions = const [],
    this.labels,
    this.annotations,
    this.enabled = true,
  });

  /// Create a copy with updated fields.
  AlertRule copyWith({
    String? id,
    String? name,
    String? description,
    AlertCondition? condition,
    AlertSeverity? severity,
    Duration? forDuration,
    Duration? interval,
    List<AlertAction>? actions,
    Map<String, String>? labels,
    Map<String, String>? annotations,
    bool? enabled,
  }) {
    return AlertRule(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      condition: condition ?? this.condition,
      severity: severity ?? this.severity,
      forDuration: forDuration ?? this.forDuration,
      interval: interval ?? this.interval,
      actions: actions ?? this.actions,
      labels: labels ?? this.labels,
      annotations: annotations ?? this.annotations,
      enabled: enabled ?? this.enabled,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description.isNotEmpty) 'description': description,
        'condition': condition.toJson(),
        'severity': severity.name,
        if (forDuration != null) 'forDuration': forDuration!.inMilliseconds,
        if (interval != null) 'interval': interval!.inMilliseconds,
        if (actions.isNotEmpty)
          'actions': actions.map((a) => a.toJson()).toList(),
        if (labels != null && labels!.isNotEmpty) 'labels': labels,
        if (annotations != null && annotations!.isNotEmpty)
          'annotations': annotations,
        'enabled': enabled,
      };
}

/// Alert instance.
class Alert {
  /// Alert ID.
  final String id;

  /// Rule ID that generated this alert.
  final String ruleId;

  /// Rule name.
  final String ruleName;

  /// Alert severity.
  final AlertSeverity severity;

  /// Alert state.
  AlertState state;

  /// Timestamp when alert was fired.
  final DateTime firedAt;

  /// Timestamp when alert was resolved.
  DateTime? resolvedAt;

  /// Timestamp when alert was acknowledged.
  DateTime? acknowledgedAt;

  /// User who acknowledged the alert.
  String? acknowledgedBy;

  /// Labels.
  final Map<String, String> labels;

  /// Annotations.
  final Map<String, String> annotations;

  /// Metric value that triggered the alert.
  final double? value;

  Alert({
    required this.id,
    required this.ruleId,
    required this.ruleName,
    required this.severity,
    this.state = AlertState.pending,
    required this.firedAt,
    this.resolvedAt,
    this.acknowledgedAt,
    this.acknowledgedBy,
    this.labels = const {},
    this.annotations = const {},
    this.value,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'ruleId': ruleId,
        'ruleName': ruleName,
        'severity': severity.name,
        'state': state.name,
        'firedAt': firedAt.toIso8601String(),
        if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
        if (acknowledgedAt != null)
          'acknowledgedAt': acknowledgedAt!.toIso8601String(),
        if (acknowledgedBy != null) 'acknowledgedBy': acknowledgedBy,
        if (labels.isNotEmpty) 'labels': labels,
        if (annotations.isNotEmpty) 'annotations': annotations,
        if (value != null) 'value': value,
      };
}

/// Alert manager for managing alert rules and evaluating alerts.
class AlertManager {
  /// Alert rules.
  final List<AlertRule> _rules = [];

  /// Active alerts.
  final List<Alert> _activeAlerts = [];

  /// Metrics collector for evaluation.
  final MetricsCollector _metrics;

  /// Alert ID counter for generating unique IDs.
  int _alertIdCounter = 0;

  AlertManager({
    required MetricsCollector metrics,
  }) : _metrics = metrics;

  /// Get registered rules.
  List<AlertRule> get rules => List.unmodifiable(_rules);

  /// Get metrics collector.
  MetricsCollector get metrics => _metrics;

  /// Add an alert rule.
  void addRule(AlertRule rule) {
    _rules.add(rule);
  }

  /// Remove an alert rule by ID.
  void removeRule(String ruleId) {
    _rules.removeWhere((r) => r.id == ruleId);
    _activeAlerts.removeWhere((a) => a.ruleId == ruleId);
  }

  /// Update an alert rule.
  void updateRule(AlertRule rule) {
    final index = _rules.indexWhere((r) => r.id == rule.id);
    if (index >= 0) {
      _rules[index] = rule;
    }
  }

  /// Evaluate all enabled rules against current metrics.
  Future<List<Alert>> evaluate() async {
    final newAlerts = <Alert>[];

    for (final rule in _rules) {
      if (!rule.enabled) continue;

      final triggered = _evaluateCondition(rule.condition);
      final existingAlert = _activeAlerts
          .where((a) => a.ruleId == rule.id && a.state != AlertState.resolved)
          .firstOrNull;

      if (triggered) {
        if (existingAlert == null) {
          final alert = Alert(
            id: _generateAlertId(),
            ruleId: rule.id,
            ruleName: rule.name,
            severity: rule.severity,
            state: AlertState.firing,
            firedAt: DateTime.now(),
            labels: rule.labels ?? {},
            annotations: rule.annotations ?? {},
            value: _getMetricValue(rule.condition),
          );
          _activeAlerts.add(alert);
          newAlerts.add(alert);
        }
      } else {
        if (existingAlert != null && existingAlert.state == AlertState.firing) {
          existingAlert.state = AlertState.resolved;
          existingAlert.resolvedAt = DateTime.now();
        }
      }
    }

    return newAlerts;
  }

  /// Get all active (non-resolved) alerts.
  Future<List<Alert>> getActiveAlerts() async {
    return _activeAlerts.where((a) => a.state != AlertState.resolved).toList();
  }

  /// Acknowledge an alert.
  Future<void> acknowledgeAlert(String alertId, String userId) async {
    final alert = _activeAlerts.where((a) => a.id == alertId).firstOrNull;
    if (alert != null && alert.state == AlertState.firing) {
      alert.state = AlertState.acknowledged;
      alert.acknowledgedAt = DateTime.now();
      alert.acknowledgedBy = userId;
    }
  }

  /// Resolve an alert.
  Future<void> resolveAlert(String alertId) async {
    final alert = _activeAlerts.where((a) => a.id == alertId).firstOrNull;
    if (alert != null && alert.state != AlertState.resolved) {
      alert.state = AlertState.resolved;
      alert.resolvedAt = DateTime.now();
    }
  }

  /// Evaluate a single alert condition against metrics.
  bool _evaluateCondition(AlertCondition condition) {
    switch (condition.type) {
      case AlertConditionType.metric:
        return _evaluateMetricCondition(condition);
      case AlertConditionType.log:
        return _evaluateLogCondition(condition);
      case AlertConditionType.expression:
        return _evaluateExpressionCondition(condition);
    }
  }

  /// Evaluate a metric-based condition.
  bool _evaluateMetricCondition(AlertCondition condition) {
    if (condition.metric == null ||
        condition.operator == null ||
        condition.threshold == null) {
      return false;
    }

    final metricValue = _getMetricValue(condition);
    if (metricValue == null) return false;

    return _compareValues(
      metricValue,
      condition.operator!,
      condition.threshold!,
    );
  }

  /// Get the current metric value for a condition.
  double? _getMetricValue(AlertCondition condition) {
    if (condition.metric == null) return null;

    final sink = _getMetricSink();
    if (sink == null) return null;

    return sink.latestValue(condition.metric!);
  }

  /// Get the in-memory metric sink from the collector (if available).
  InMemoryMetricSink? _getMetricSink() {
    final sink = _metrics.sink;
    if (sink is InMemoryMetricSink) return sink;
    return null;
  }

  /// Evaluate a log-based condition.
  ///
  /// Checks if the metric sink has a count metric matching the log query name
  /// that exceeds the count threshold.
  bool _evaluateLogCondition(AlertCondition condition) {
    if (condition.logQuery == null || condition.countThreshold == null) {
      return false;
    }

    // Use metric-based proxy: look for a counter named after the log query
    final sink = _getMetricSink();
    if (sink == null) return false;

    final count = sink.sum('log.${condition.logQuery}');
    return count >= condition.countThreshold!;
  }

  /// Evaluate an expression-based condition.
  ///
  /// Currently supports simple metric comparison expressions
  /// in the form "metric_name > threshold".
  bool _evaluateExpressionCondition(AlertCondition condition) {
    if (condition.expression == null) return false;

    // Parse simple expressions of the form: "metric_name operator value"
    final match = RegExp(r'^(\S+)\s*(>=|<=|>|<|==|!=)\s*(\S+)$')
        .firstMatch(condition.expression!);
    if (match == null) return false;

    final metricName = match.group(1)!;
    final op = match.group(2)!;
    final thresholdStr = match.group(3)!;
    final threshold = double.tryParse(thresholdStr);
    if (threshold == null) return false;

    final sink = _getMetricSink();
    if (sink == null) return false;

    final value = sink.latestValue(metricName);
    if (value == null) return false;

    return _compareValues(value, op, threshold);
  }

  /// Compare a metric value against a threshold using an operator.
  bool _compareValues(double value, String operator, double threshold) {
    switch (operator) {
      case '>':
        return value > threshold;
      case '>=':
        return value >= threshold;
      case '<':
        return value < threshold;
      case '<=':
        return value <= threshold;
      case '==':
        return value == threshold;
      case '!=':
        return value != threshold;
      default:
        return false;
    }
  }

  /// Generate a unique alert ID.
  String _generateAlertId() {
    _alertIdCounter++;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'alert_${timestamp}_$_alertIdCounter';
  }
}
