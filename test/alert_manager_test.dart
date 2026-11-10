/// Alert Manager Tests - Tests for AlertManager, AlertRule, AlertCondition,
/// and related alert classes.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // AlertManager
  // ═══════════════════════════════════════════════════════════════

  group('AlertManager', () {
    late InMemoryMetricSink metricSink;
    late MetricsCollector metrics;
    late AlertManager manager;

    setUp(() {
      metricSink = InMemoryMetricSink();
      metrics = MetricsCollector(sink: metricSink);
      manager = AlertManager(metrics: metrics);
    });

    test('addRule() adds alert rule', () {
      final rule = AlertRule(
        id: 'rule-1',
        name: 'High Error Rate',
        condition: const AlertCondition(
          type: AlertConditionType.metric,
          metric: 'error_rate',
          operator: '>',
          threshold: 0.5,
        ),
        severity: AlertSeverity.critical,
      );

      manager.addRule(rule);

      expect(manager.rules.length, equals(1));
      expect(manager.rules.first.id, equals('rule-1'));
    });

    test('removeRule() removes rule by ID', () {
      final rule = AlertRule(
        id: 'rule-1',
        name: 'Test Rule',
        condition: const AlertCondition(
          type: AlertConditionType.metric,
          metric: 'test',
          operator: '>',
          threshold: 1.0,
        ),
      );

      manager.addRule(rule);
      expect(manager.rules.length, equals(1));

      manager.removeRule('rule-1');
      expect(manager.rules, isEmpty);
    });

    test('updateRule() replaces existing rule', () {
      final original = AlertRule(
        id: 'rule-1',
        name: 'Original Name',
        condition: const AlertCondition(
          type: AlertConditionType.metric,
          metric: 'test',
          operator: '>',
          threshold: 1.0,
        ),
      );
      manager.addRule(original);

      final updated = original.copyWith(name: 'Updated Name');
      manager.updateRule(updated);

      expect(manager.rules.length, equals(1));
      expect(manager.rules.first.name, equals('Updated Name'));
    });

    test('evaluate() fires alert when metric threshold exceeded', () async {
      // Record a high error rate metric
      metrics.gauge('error_rate', 0.8);

      final rule = AlertRule(
        id: 'rule-1',
        name: 'High Error Rate',
        condition: const AlertCondition(
          type: AlertConditionType.metric,
          metric: 'error_rate',
          operator: '>',
          threshold: 0.5,
        ),
        severity: AlertSeverity.critical,
      );
      manager.addRule(rule);

      final alerts = await manager.evaluate();

      expect(alerts.length, equals(1));
      expect(alerts.first.ruleId, equals('rule-1'));
      expect(alerts.first.severity, equals(AlertSeverity.critical));
      expect(alerts.first.state, equals(AlertState.firing));
      expect(alerts.first.value, equals(0.8));
    });

    test('evaluate() does not fire when below threshold', () async {
      metrics.gauge('error_rate', 0.3);

      final rule = AlertRule(
        id: 'rule-1',
        name: 'High Error Rate',
        condition: const AlertCondition(
          type: AlertConditionType.metric,
          metric: 'error_rate',
          operator: '>',
          threshold: 0.5,
        ),
      );
      manager.addRule(rule);

      final alerts = await manager.evaluate();
      expect(alerts, isEmpty);
    });

    test('evaluate() does not duplicate existing firing alert', () async {
      metrics.gauge('error_rate', 0.8);

      final rule = AlertRule(
        id: 'rule-1',
        name: 'High Error Rate',
        condition: const AlertCondition(
          type: AlertConditionType.metric,
          metric: 'error_rate',
          operator: '>',
          threshold: 0.5,
        ),
      );
      manager.addRule(rule);

      // First evaluation fires alert
      final first = await manager.evaluate();
      expect(first.length, equals(1));

      // Second evaluation should not create duplicate
      final second = await manager.evaluate();
      expect(second, isEmpty);
    });

    test('evaluate() skips disabled rules', () async {
      metrics.gauge('error_rate', 0.8);

      final rule = AlertRule(
        id: 'rule-1',
        name: 'Disabled Rule',
        condition: const AlertCondition(
          type: AlertConditionType.metric,
          metric: 'error_rate',
          operator: '>',
          threshold: 0.5,
        ),
        enabled: false,
      );
      manager.addRule(rule);

      final alerts = await manager.evaluate();
      expect(alerts, isEmpty);
    });

    test('evaluate() with various operators', () async {
      metrics.gauge('value', 50.0);

      // Test >= operator
      manager.addRule(AlertRule(
        id: 'gte',
        name: 'GTE',
        condition: const AlertCondition(
          type: AlertConditionType.metric,
          metric: 'value',
          operator: '>=',
          threshold: 50.0,
        ),
      ));

      // Test < operator (should not fire)
      manager.addRule(AlertRule(
        id: 'lt',
        name: 'LT',
        condition: const AlertCondition(
          type: AlertConditionType.metric,
          metric: 'value',
          operator: '<',
          threshold: 50.0,
        ),
      ));

      // Test == operator
      manager.addRule(AlertRule(
        id: 'eq',
        name: 'EQ',
        condition: const AlertCondition(
          type: AlertConditionType.metric,
          metric: 'value',
          operator: '==',
          threshold: 50.0,
        ),
      ));

      final alerts = await manager.evaluate();
      final firedIds = alerts.map((a) => a.ruleId).toSet();

      expect(firedIds.contains('gte'), isTrue);
      expect(firedIds.contains('lt'), isFalse);
      expect(firedIds.contains('eq'), isTrue);
    });

    test('evaluate() resolves alert when condition clears', () async {
      metrics.gauge('error_rate', 0.8);

      final rule = AlertRule(
        id: 'rule-1',
        name: 'High Error Rate',
        condition: const AlertCondition(
          type: AlertConditionType.metric,
          metric: 'error_rate',
          operator: '>',
          threshold: 0.5,
        ),
      );
      manager.addRule(rule);

      // Fire the alert
      await manager.evaluate();
      var active = await manager.getActiveAlerts();
      expect(active.length, equals(1));

      // Clear the condition
      metrics.gauge('error_rate', 0.2);
      await manager.evaluate();

      active = await manager.getActiveAlerts();
      expect(active, isEmpty);
    });

    test('acknowledgeAlert() changes state', () async {
      metrics.gauge('error_rate', 0.8);

      final rule = AlertRule(
        id: 'rule-1',
        name: 'High Error Rate',
        condition: const AlertCondition(
          type: AlertConditionType.metric,
          metric: 'error_rate',
          operator: '>',
          threshold: 0.5,
        ),
      );
      manager.addRule(rule);

      final alerts = await manager.evaluate();
      final alertId = alerts.first.id;

      await manager.acknowledgeAlert(alertId, 'user-1');

      final active = await manager.getActiveAlerts();
      expect(active.length, equals(1));
      expect(active.first.state, equals(AlertState.acknowledged));
      expect(active.first.acknowledgedBy, equals('user-1'));
      expect(active.first.acknowledgedAt, isNotNull);
    });

    test('resolveAlert() changes state', () async {
      metrics.gauge('error_rate', 0.8);

      final rule = AlertRule(
        id: 'rule-1',
        name: 'High Error Rate',
        condition: const AlertCondition(
          type: AlertConditionType.metric,
          metric: 'error_rate',
          operator: '>',
          threshold: 0.5,
        ),
      );
      manager.addRule(rule);

      final alerts = await manager.evaluate();
      final alertId = alerts.first.id;

      await manager.resolveAlert(alertId);

      final active = await manager.getActiveAlerts();
      expect(active, isEmpty);
    });

    test('getActiveAlerts() returns non-resolved alerts', () async {
      metrics.gauge('metric_a', 100.0);
      metrics.gauge('metric_b', 200.0);

      manager.addRule(AlertRule(
        id: 'rule-a',
        name: 'Rule A',
        condition: const AlertCondition(
          type: AlertConditionType.metric,
          metric: 'metric_a',
          operator: '>',
          threshold: 50.0,
        ),
      ));
      manager.addRule(AlertRule(
        id: 'rule-b',
        name: 'Rule B',
        condition: const AlertCondition(
          type: AlertConditionType.metric,
          metric: 'metric_b',
          operator: '>',
          threshold: 100.0,
        ),
      ));

      final alerts = await manager.evaluate();
      expect(alerts.length, equals(2));

      // Resolve one
      await manager.resolveAlert(alerts.first.id);

      final active = await manager.getActiveAlerts();
      expect(active.length, equals(1));
    });

    test('evaluate() with expression condition', () async {
      metrics.gauge('cpu_usage', 95.0);

      final rule = AlertRule(
        id: 'expr-rule',
        name: 'Expression Rule',
        condition: const AlertCondition(
          type: AlertConditionType.expression,
          expression: 'cpu_usage > 90',
        ),
      );
      manager.addRule(rule);

      final alerts = await manager.evaluate();
      expect(alerts.length, equals(1));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // AlertRule
  // ═══════════════════════════════════════════════════════════════

  group('AlertRule', () {
    test('copyWith() creates modified copy', () {
      const original = AlertRule(
        id: 'rule-1',
        name: 'Original',
        condition: AlertCondition(
          type: AlertConditionType.metric,
          metric: 'test',
          operator: '>',
          threshold: 1.0,
        ),
        severity: AlertSeverity.warning,
      );

      final updated = original.copyWith(
        name: 'Updated',
        severity: AlertSeverity.critical,
      );

      expect(updated.id, equals('rule-1'));
      expect(updated.name, equals('Updated'));
      expect(updated.severity, equals(AlertSeverity.critical));
    });

    test('toJson() serializes correctly', () {
      const rule = AlertRule(
        id: 'rule-1',
        name: 'Test Rule',
        description: 'A test alert rule',
        condition: AlertCondition(
          type: AlertConditionType.metric,
          metric: 'error_rate',
          operator: '>',
          threshold: 0.5,
        ),
        severity: AlertSeverity.critical,
        labels: {'team': 'platform'},
        annotations: {'runbook': 'https://example.com'},
        enabled: true,
      );

      final json = rule.toJson();
      expect(json['id'], equals('rule-1'));
      expect(json['name'], equals('Test Rule'));
      expect(json['description'], equals('A test alert rule'));
      expect(json['severity'], equals('critical'));
      expect(json['labels'], equals({'team': 'platform'}));
      expect(json['annotations'], equals({'runbook': 'https://example.com'}));
      expect(json['enabled'], isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // AlertCondition
  // ═══════════════════════════════════════════════════════════════

  group('AlertCondition', () {
    test('toJson() for metric condition', () {
      const condition = AlertCondition(
        type: AlertConditionType.metric,
        metric: 'latency',
        operator: '>',
        threshold: 100.0,
        aggregation: 'avg',
        window: Duration(minutes: 5),
      );

      final json = condition.toJson();
      expect(json['type'], equals('metric'));
      expect(json['metric'], equals('latency'));
      expect(json['operator'], equals('>'));
      expect(json['threshold'], equals(100.0));
      expect(json['aggregation'], equals('avg'));
    });

    test('toJson() for log condition', () {
      const condition = AlertCondition(
        type: AlertConditionType.log,
        logQuery: 'error',
        countThreshold: 10,
      );

      final json = condition.toJson();
      expect(json['type'], equals('log'));
      expect(json['logQuery'], equals('error'));
      expect(json['countThreshold'], equals(10));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Alert
  // ═══════════════════════════════════════════════════════════════

  group('Alert', () {
    test('toJson() serializes correctly', () {
      final alert = Alert(
        id: 'alert-1',
        ruleId: 'rule-1',
        ruleName: 'Test Alert',
        severity: AlertSeverity.warning,
        state: AlertState.firing,
        firedAt: DateTime(2024, 1, 1),
        labels: {'team': 'ops'},
        value: 0.95,
      );

      final json = alert.toJson();
      expect(json['id'], equals('alert-1'));
      expect(json['ruleId'], equals('rule-1'));
      expect(json['ruleName'], equals('Test Alert'));
      expect(json['severity'], equals('warning'));
      expect(json['state'], equals('firing'));
      expect(json['labels'], equals({'team': 'ops'}));
      expect(json['value'], equals(0.95));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Enums
  // ═══════════════════════════════════════════════════════════════

  group('Alert enums', () {
    test('AlertSeverity has all values', () {
      expect(
          AlertSeverity.values,
          containsAll([
            AlertSeverity.info,
            AlertSeverity.warning,
            AlertSeverity.critical,
            AlertSeverity.emergency
          ]));
    });

    test('AlertState has all values', () {
      expect(
          AlertState.values,
          containsAll([
            AlertState.pending,
            AlertState.firing,
            AlertState.acknowledged,
            AlertState.resolved
          ]));
    });

    test('AlertConditionType has all values', () {
      expect(
          AlertConditionType.values,
          containsAll([
            AlertConditionType.metric,
            AlertConditionType.log,
            AlertConditionType.expression
          ]));
    });
  });
}
