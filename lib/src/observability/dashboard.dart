/// Dashboard - Dashboard configuration models for observability.
///
/// Provides data models for configuring monitoring dashboards
/// with panels, queries, variables, and layout positioning.
library;

/// Panel display type.
enum PanelType {
  /// Line chart panel.
  lineChart,

  /// Bar chart panel.
  barChart,

  /// Single value / stat panel.
  stat,

  /// Table panel.
  table,

  /// Heatmap panel.
  heatmap,

  /// Log viewer panel.
  logs,
}

/// Grid position for a dashboard panel.
class PanelPosition {
  /// Column offset (0-based).
  final int x;

  /// Row offset (0-based).
  final int y;

  /// Width in grid units.
  final int width;

  /// Height in grid units.
  final int height;

  const PanelPosition({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
}

/// Query definition for a dashboard panel.
class PanelQuery {
  /// Metric name or query expression.
  final String expression;

  /// Legend label for this query in charts.
  final String? legend;

  /// Aggregation function (e.g. 'sum', 'avg', 'max', 'min', 'count').
  final String? aggregation;

  /// Group-by label keys.
  final List<String>? groupBy;

  const PanelQuery({
    required this.expression,
    this.legend,
    this.aggregation,
    this.groupBy,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'expression': expression,
        if (legend != null) 'legend': legend,
        if (aggregation != null) 'aggregation': aggregation,
        if (groupBy != null && groupBy!.isNotEmpty) 'groupBy': groupBy,
      };
}

/// A single panel on a dashboard.
class DashboardPanel {
  /// Panel identifier.
  final String id;

  /// Panel title.
  final String title;

  /// Panel type.
  final PanelType type;

  /// Grid position and size.
  final PanelPosition position;

  /// Data queries for this panel.
  final List<PanelQuery> queries;

  /// Optional description.
  final String? description;

  const DashboardPanel({
    required this.id,
    required this.title,
    required this.type,
    required this.position,
    required this.queries,
    this.description,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'position': position.toJson(),
        'queries': queries.map((q) => q.toJson()).toList(),
        if (description != null) 'description': description,
      };
}

/// Dashboard variable for dynamic filtering.
class DashboardVariable {
  /// Variable name.
  final String name;

  /// Display label.
  final String label;

  /// Variable type ('query', 'constant', 'interval').
  final String type;

  /// Default value.
  final String? defaultValue;

  /// Allowed values (for constant type).
  final List<String>? options;

  const DashboardVariable({
    required this.name,
    required this.label,
    required this.type,
    this.defaultValue,
    this.options,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'name': name,
        'label': label,
        'type': type,
        if (defaultValue != null) 'defaultValue': defaultValue,
        if (options != null && options!.isNotEmpty) 'options': options,
      };
}

/// Dashboard configuration model.
///
/// Defines a monitoring dashboard with panels, variables,
/// and metadata for rendering and management.
class Dashboard {
  /// Dashboard identifier.
  final String id;

  /// Dashboard title.
  final String title;

  /// Optional description.
  final String? description;

  /// Panels on this dashboard.
  final List<DashboardPanel> panels;

  /// Template variables for dynamic filtering.
  final List<DashboardVariable> variables;

  /// Auto-refresh interval.
  final Duration? refreshInterval;

  /// Time range for queries (e.g. last 1 hour).
  final Duration? timeRange;

  const Dashboard({
    required this.id,
    required this.title,
    this.description,
    required this.panels,
    this.variables = const [],
    this.refreshInterval,
    this.timeRange,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (description != null) 'description': description,
        'panels': panels.map((p) => p.toJson()).toList(),
        if (variables.isNotEmpty)
          'variables': variables.map((v) => v.toJson()).toList(),
        if (refreshInterval != null)
          'refreshIntervalMs': refreshInterval!.inMilliseconds,
        if (timeRange != null) 'timeRangeMs': timeRange!.inMilliseconds,
      };
}
