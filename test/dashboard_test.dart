/// Dashboard Tests - Tests for Dashboard, DashboardPanel, PanelPosition,
/// PanelQuery, DashboardVariable, and PanelType.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // Dashboard
  // ═══════════════════════════════════════════════════════════════

  group('Dashboard', () {
    test('creation and toJson', () {
      const dashboard = Dashboard(
        id: 'dash-1',
        title: 'Pipeline Overview',
        description: 'Overview of all pipeline operations',
        panels: [
          DashboardPanel(
            id: 'panel-1',
            title: 'Request Rate',
            type: PanelType.lineChart,
            position: PanelPosition(x: 0, y: 0, width: 12, height: 4),
            queries: [
              PanelQuery(
                expression: 'ops.pipeline.success.total',
                legend: 'Success',
                aggregation: 'sum',
              ),
            ],
          ),
        ],
        variables: [
          DashboardVariable(
            name: 'pipeline',
            label: 'Pipeline',
            type: 'query',
            defaultValue: 'all',
            options: ['all', 'ingest', 'curation'],
          ),
        ],
        refreshInterval: Duration(seconds: 30),
        timeRange: Duration(hours: 1),
      );

      final json = dashboard.toJson();

      expect(json['id'], equals('dash-1'));
      expect(json['title'], equals('Pipeline Overview'));
      expect(json['description'], equals('Overview of all pipeline operations'));
      expect((json['panels'] as List).length, equals(1));
      expect((json['variables'] as List).length, equals(1));
      expect(json['refreshIntervalMs'], equals(30000));
      expect(json['timeRangeMs'], equals(3600000));
    });

    test('toJson() omits null/empty optional fields', () {
      const dashboard = Dashboard(
        id: 'dash-2',
        title: 'Minimal Dashboard',
        panels: [],
      );

      final json = dashboard.toJson();

      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('variables'), isFalse);
      expect(json.containsKey('refreshIntervalMs'), isFalse);
      expect(json.containsKey('timeRangeMs'), isFalse);
    });

    test('creation with multiple panels', () {
      const dashboard = Dashboard(
        id: 'dash-3',
        title: 'Multi-Panel',
        panels: [
          DashboardPanel(
            id: 'p1',
            title: 'Panel 1',
            type: PanelType.stat,
            position: PanelPosition(x: 0, y: 0, width: 6, height: 3),
            queries: [
              PanelQuery(expression: 'metric_1'),
            ],
          ),
          DashboardPanel(
            id: 'p2',
            title: 'Panel 2',
            type: PanelType.table,
            position: PanelPosition(x: 6, y: 0, width: 6, height: 3),
            queries: [
              PanelQuery(expression: 'metric_2'),
            ],
          ),
          DashboardPanel(
            id: 'p3',
            title: 'Panel 3',
            type: PanelType.heatmap,
            position: PanelPosition(x: 0, y: 3, width: 12, height: 4),
            queries: [
              PanelQuery(expression: 'metric_3'),
            ],
          ),
        ],
      );

      expect(dashboard.panels.length, equals(3));

      final json = dashboard.toJson();
      expect((json['panels'] as List).length, equals(3));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // DashboardPanel
  // ═══════════════════════════════════════════════════════════════

  group('DashboardPanel', () {
    test('creation and toJson', () {
      const panel = DashboardPanel(
        id: 'panel-1',
        title: 'Error Rate',
        type: PanelType.lineChart,
        position: PanelPosition(x: 0, y: 0, width: 12, height: 4),
        queries: [
          PanelQuery(
            expression: 'ops.pipeline.failure.total',
            legend: 'Failures',
          ),
          PanelQuery(
            expression: 'ops.pipeline.success.total',
            legend: 'Successes',
          ),
        ],
        description: 'Shows error rate over time',
      );

      final json = panel.toJson();

      expect(json['id'], equals('panel-1'));
      expect(json['title'], equals('Error Rate'));
      expect(json['type'], equals('lineChart'));
      expect((json['queries'] as List).length, equals(2));
      expect(json['description'], equals('Shows error rate over time'));
    });

    test('toJson() omits null description', () {
      const panel = DashboardPanel(
        id: 'panel-2',
        title: 'Simple',
        type: PanelType.stat,
        position: PanelPosition(x: 0, y: 0, width: 4, height: 2),
        queries: [PanelQuery(expression: 'metric')],
      );

      final json = panel.toJson();
      expect(json.containsKey('description'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // PanelPosition
  // ═══════════════════════════════════════════════════════════════

  group('PanelPosition', () {
    test('toJson() serializes correctly', () {
      const position = PanelPosition(x: 3, y: 5, width: 8, height: 4);

      final json = position.toJson();

      expect(json['x'], equals(3));
      expect(json['y'], equals(5));
      expect(json['width'], equals(8));
      expect(json['height'], equals(4));
    });

    test('supports zero position', () {
      const position = PanelPosition(x: 0, y: 0, width: 1, height: 1);

      final json = position.toJson();
      expect(json['x'], equals(0));
      expect(json['y'], equals(0));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // PanelQuery
  // ═══════════════════════════════════════════════════════════════

  group('PanelQuery', () {
    test('toJson() with all fields', () {
      const query = PanelQuery(
        expression: 'ops.pipeline.duration',
        legend: 'Duration',
        aggregation: 'avg',
        groupBy: ['pipeline_name', 'stage'],
      );

      final json = query.toJson();

      expect(json['expression'], equals('ops.pipeline.duration'));
      expect(json['legend'], equals('Duration'));
      expect(json['aggregation'], equals('avg'));
      expect(json['groupBy'], equals(['pipeline_name', 'stage']));
    });

    test('toJson() omits null optional fields', () {
      const query = PanelQuery(expression: 'simple.metric');

      final json = query.toJson();

      expect(json['expression'], equals('simple.metric'));
      expect(json.containsKey('legend'), isFalse);
      expect(json.containsKey('aggregation'), isFalse);
      expect(json.containsKey('groupBy'), isFalse);
    });

    test('toJson() omits empty groupBy', () {
      const query = PanelQuery(
        expression: 'metric',
        groupBy: [],
      );

      final json = query.toJson();
      expect(json.containsKey('groupBy'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // DashboardVariable
  // ═══════════════════════════════════════════════════════════════

  group('DashboardVariable', () {
    test('with options toJson()', () {
      const variable = DashboardVariable(
        name: 'environment',
        label: 'Environment',
        type: 'constant',
        defaultValue: 'production',
        options: ['production', 'staging', 'development'],
      );

      final json = variable.toJson();

      expect(json['name'], equals('environment'));
      expect(json['label'], equals('Environment'));
      expect(json['type'], equals('constant'));
      expect(json['defaultValue'], equals('production'));
      expect(json['options'],
          equals(['production', 'staging', 'development']));
    });

    test('toJson() omits null optional fields', () {
      const variable = DashboardVariable(
        name: 'interval',
        label: 'Interval',
        type: 'interval',
      );

      final json = variable.toJson();

      expect(json['name'], equals('interval'));
      expect(json.containsKey('defaultValue'), isFalse);
      expect(json.containsKey('options'), isFalse);
    });

    test('query type variable', () {
      const variable = DashboardVariable(
        name: 'pipeline',
        label: 'Pipeline Name',
        type: 'query',
        defaultValue: 'all',
      );

      final json = variable.toJson();
      expect(json['type'], equals('query'));
      expect(json['defaultValue'], equals('all'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // PanelType
  // ═══════════════════════════════════════════════════════════════

  group('PanelType', () {
    test('has all expected values', () {
      expect(PanelType.values.length, equals(6));
      expect(PanelType.values,
          containsAll([PanelType.lineChart, PanelType.barChart,
              PanelType.stat, PanelType.table,
              PanelType.heatmap, PanelType.logs]));
    });

    test('enum names are correct', () {
      expect(PanelType.lineChart.name, equals('lineChart'));
      expect(PanelType.barChart.name, equals('barChart'));
      expect(PanelType.stat.name, equals('stat'));
      expect(PanelType.table.name, equals('table'));
      expect(PanelType.heatmap.name, equals('heatmap'));
      expect(PanelType.logs.name, equals('logs'));
    });
  });
}
