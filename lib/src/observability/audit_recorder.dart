/// Audit Recorder - Audit trail recording for observability.
///
/// Provides structured audit event recording for pipeline, workflow,
/// and administrative operations with query and export capabilities.
library;

import 'dart:convert';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Outcome of an audited operation.
enum AuditOutcome {
  success,
  failure,
  denied,
}

/// Type of actor performing an audited operation.
enum ActorType {
  user,
  system,
  service,
  schedule,
}

/// Export format for audit data.
enum ExportFormat {
  json,
  csv,
  parquet,
}

// ---------------------------------------------------------------------------
// Value classes
// ---------------------------------------------------------------------------

/// Actor who performed the audited operation.
class AuditActor {
  /// Actor type.
  final ActorType type;

  /// Actor identifier.
  final String id;

  /// Human-readable name.
  final String? name;

  /// IP address of the actor.
  final String? ip;

  /// User agent string.
  final String? userAgent;

  const AuditActor({
    required this.type,
    required this.id,
    this.name,
    this.ip,
    this.userAgent,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        if (name != null) 'name': name,
        if (ip != null) 'ip': ip,
        if (userAgent != null) 'userAgent': userAgent,
      };

  /// Deserialize from JSON.
  factory AuditActor.fromJson(Map<String, dynamic> json) => AuditActor(
        type: ActorType.values.byName(json['type'] as String),
        id: json['id'] as String,
        name: json['name'] as String?,
        ip: json['ip'] as String?,
        userAgent: json['userAgent'] as String?,
      );
}

/// Resource targeted by the audited operation.
class AuditResource {
  /// Resource type (e.g. "pipeline", "workflow", "schedule").
  final String type;

  /// Resource identifier.
  final String id;

  /// Human-readable name.
  final String? name;

  /// Additional attributes describing the resource.
  final Map<String, dynamic>? attributes;

  const AuditResource({
    required this.type,
    required this.id,
    this.name,
    this.attributes,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        if (name != null) 'name': name,
        if (attributes != null && attributes!.isNotEmpty)
          'attributes': attributes,
      };

  /// Deserialize from JSON.
  factory AuditResource.fromJson(Map<String, dynamic> json) => AuditResource(
        type: json['type'] as String,
        id: json['id'] as String,
        name: json['name'] as String?,
        attributes: json['attributes'] != null
            ? Map<String, dynamic>.from(json['attributes'] as Map)
            : null,
      );
}

/// Contextual information for an audit event.
class AuditContext {
  /// Workspace identifier.
  final String workspaceId;

  /// Project identifier.
  final String? projectId;

  /// Distributed trace identifier.
  final String? traceId;

  /// Request identifier.
  final String? requestId;

  /// Session identifier.
  final String? sessionId;

  const AuditContext({
    required this.workspaceId,
    this.projectId,
    this.traceId,
    this.requestId,
    this.sessionId,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'workspaceId': workspaceId,
        if (projectId != null) 'projectId': projectId,
        if (traceId != null) 'traceId': traceId,
        if (requestId != null) 'requestId': requestId,
        if (sessionId != null) 'sessionId': sessionId,
      };

  /// Deserialize from JSON.
  factory AuditContext.fromJson(Map<String, dynamic> json) => AuditContext(
        workspaceId: json['workspaceId'] as String,
        projectId: json['projectId'] as String?,
        traceId: json['traceId'] as String?,
        requestId: json['requestId'] as String?,
        sessionId: json['sessionId'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Audit event
// ---------------------------------------------------------------------------

/// A recorded audit event capturing an operation performed in the system.
class AuditEvent {
  /// Unique event identifier.
  final String id;

  /// Timestamp when the event occurred.
  final DateTime timestamp;

  /// Actor who performed the operation.
  final AuditActor actor;

  /// Action performed (e.g. "pipeline.start").
  final String action;

  /// Resource targeted by the operation.
  final AuditResource resource;

  /// Outcome of the operation.
  final AuditOutcome outcome;

  /// Contextual information.
  final AuditContext context;

  /// Additional structured details about the event.
  final Map<String, dynamic>? details;

  /// Human-readable reason for the action.
  final String? reason;

  /// Error description if the operation failed.
  final String? error;

  // -- Standard audit action constants --

  /// Pipeline lifecycle actions.
  static const pipelineActions = [
    'pipeline.start',
    'pipeline.complete',
    'pipeline.fail',
    'pipeline.cancel',
    'pipeline.retry',
    'pipeline.checkpoint',
  ];

  /// Workflow lifecycle and governance actions.
  static const workflowActions = [
    'workflow.start',
    'workflow.complete',
    'workflow.fail',
    'workflow.cancel',
    'workflow.gate_pass',
    'workflow.gate_fail',
    'workflow.review_request',
    'workflow.review_complete',
    'workflow.approval_request',
    'workflow.approval_grant',
    'workflow.approval_deny',
    'workflow.publish',
  ];

  /// Schedule and execution actions.
  static const scheduleActions = [
    'schedule.create',
    'schedule.update',
    'schedule.delete',
    'schedule.pause',
    'schedule.resume',
    'schedule.trigger',
    'execution.enqueue',
    'execution.start',
    'execution.complete',
    'execution.fail',
    'execution.cancel',
  ];

  /// Philosophy audit actions.
  static const philosophyActions = [
    'philosophy.evaluate',
    'philosophy.prohibition_check',
    'philosophy.prohibition_violated',
    'philosophy.intervene.pre_generation',
    'philosophy.intervene.during_generation',
    'philosophy.intervene.post_generation',
    'philosophy.tension_detected',
    'philosophy.evolution_proposed',
  ];

  /// Administrative actions.
  static const adminActions = [
    'config.update',
    'user.grant_access',
    'user.revoke_access',
    'data.export',
    'data.purge',
  ];

  const AuditEvent({
    required this.id,
    required this.timestamp,
    required this.actor,
    required this.action,
    required this.resource,
    required this.outcome,
    required this.context,
    this.details,
    this.reason,
    this.error,
  });

  /// Convenience factory that auto-generates [id] and [timestamp].
  factory AuditEvent.create({
    required AuditActor actor,
    required String action,
    required AuditResource resource,
    required AuditOutcome outcome,
    required AuditContext context,
    Map<String, dynamic>? details,
    String? reason,
    String? error,
  }) {
    final now = DateTime.now();
    final millis = now.millisecondsSinceEpoch;
    final random = millis.hashCode.abs() % 10000;
    return AuditEvent(
      id: 'audit_${millis}_$random',
      timestamp: now,
      actor: actor,
      action: action,
      resource: resource,
      outcome: outcome,
      context: context,
      details: details,
      reason: reason,
      error: error,
    );
  }

  /// Deserialize from JSON.
  factory AuditEvent.fromJson(Map<String, dynamic> json) => AuditEvent(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        actor: AuditActor.fromJson(json['actor'] as Map<String, dynamic>),
        action: json['action'] as String,
        resource:
            AuditResource.fromJson(json['resource'] as Map<String, dynamic>),
        outcome: AuditOutcome.values.byName(json['outcome'] as String),
        context:
            AuditContext.fromJson(json['context'] as Map<String, dynamic>),
        details: json['details'] != null
            ? Map<String, dynamic>.from(json['details'] as Map)
            : null,
        reason: json['reason'] as String?,
        error: json['error'] as String?,
      );

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'actor': actor.toJson(),
        'action': action,
        'resource': resource.toJson(),
        'outcome': outcome.name,
        'context': context.toJson(),
        if (details != null && details!.isNotEmpty) 'details': details,
        if (reason != null) 'reason': reason,
        if (error != null) 'error': error,
      };
}

// ---------------------------------------------------------------------------
// Audit filter
// ---------------------------------------------------------------------------

/// Filter criteria for querying audit events.
class AuditFilter {
  /// Inclusive start time boundary.
  final DateTime? startTime;

  /// Inclusive end time boundary.
  final DateTime? endTime;

  /// Filter by actor IDs.
  final List<String>? actors;

  /// Filter by action strings.
  final List<String>? actions;

  /// Filter by resource types.
  final List<String>? resourceTypes;

  /// Filter by resource IDs.
  final List<String>? resourceIds;

  /// Filter by outcomes.
  final List<AuditOutcome>? outcomes;

  /// Filter by workspace ID.
  final String? workspaceId;

  const AuditFilter({
    this.startTime,
    this.endTime,
    this.actors,
    this.actions,
    this.resourceTypes,
    this.resourceIds,
    this.outcomes,
    this.workspaceId,
  });

  /// Check whether the given [event] matches this filter.
  bool matches(AuditEvent event) {
    if (startTime != null && event.timestamp.isBefore(startTime!)) {
      return false;
    }
    if (endTime != null && event.timestamp.isAfter(endTime!)) {
      return false;
    }
    if (actors != null &&
        actors!.isNotEmpty &&
        !actors!.contains(event.actor.id)) {
      return false;
    }
    if (actions != null &&
        actions!.isNotEmpty &&
        !actions!.contains(event.action)) {
      return false;
    }
    if (resourceTypes != null &&
        resourceTypes!.isNotEmpty &&
        !resourceTypes!.contains(event.resource.type)) {
      return false;
    }
    if (resourceIds != null &&
        resourceIds!.isNotEmpty &&
        !resourceIds!.contains(event.resource.id)) {
      return false;
    }
    if (outcomes != null &&
        outcomes!.isNotEmpty &&
        !outcomes!.contains(event.outcome)) {
      return false;
    }
    if (workspaceId != null &&
        event.context.workspaceId != workspaceId) {
      return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------------------
// Audit recorder (abstract interface)
// ---------------------------------------------------------------------------

/// Abstract audit recorder interface.
///
/// Implementations are responsible for persisting audit events and
/// providing query and export capabilities.
abstract class AuditRecorder {
  /// Record a single audit event.
  Future<void> record(AuditEvent event);

  /// Query audit events matching the given [filter].
  Future<List<AuditEvent>> query(AuditFilter filter);

  /// Export audit events matching the given [filter] in the specified [format].
  ///
  /// Returns the exported data as raw bytes.
  Future<List<int>> export(AuditFilter filter, ExportFormat format);
}

// ---------------------------------------------------------------------------
// In-memory audit recorder (for testing)
// ---------------------------------------------------------------------------

/// In-memory audit recorder for testing.
///
/// Stores all events in memory and supports filtering and export.
class InMemoryAuditRecorder implements AuditRecorder {
  final List<AuditEvent> _events = [];

  /// Get all recorded events.
  List<AuditEvent> get events => List.unmodifiable(_events);

  /// Get the number of recorded events.
  int get length => _events.length;

  /// Clear all recorded events.
  void clear() => _events.clear();

  @override
  Future<void> record(AuditEvent event) async {
    _events.add(event);
  }

  @override
  Future<List<AuditEvent>> query(AuditFilter filter) async {
    return _events.where(filter.matches).toList();
  }

  @override
  Future<List<int>> export(AuditFilter filter, ExportFormat format) async {
    final filtered = _events.where(filter.matches).toList();

    switch (format) {
      case ExportFormat.json:
        return _exportJson(filtered);
      case ExportFormat.csv:
        return _exportCsv(filtered);
      case ExportFormat.parquet:
        // Parquet encoding requires a binary library; return JSON as
        // a placeholder in the in-memory implementation.
        return _exportJson(filtered);
    }
  }

  /// Export events as JSON-encoded UTF-8 bytes.
  List<int> _exportJson(List<AuditEvent> events) {
    final jsonList = events.map((e) => e.toJson()).toList();
    return utf8.encode(jsonEncode(jsonList));
  }

  /// Export events as CSV-encoded UTF-8 bytes.
  List<int> _exportCsv(List<AuditEvent> events) {
    final buffer = StringBuffer();

    // Header row
    buffer.writeln(
      'id,timestamp,actor_type,actor_id,actor_name,action,'
      'resource_type,resource_id,resource_name,outcome,'
      'workspace_id,project_id,trace_id,request_id,session_id,'
      'reason,error',
    );

    // Data rows
    for (final event in events) {
      buffer.writeln(
        '${_csvEscape(event.id)},'
        '${_csvEscape(event.timestamp.toIso8601String())},'
        '${_csvEscape(event.actor.type.name)},'
        '${_csvEscape(event.actor.id)},'
        '${_csvEscape(event.actor.name ?? '')},'
        '${_csvEscape(event.action)},'
        '${_csvEscape(event.resource.type)},'
        '${_csvEscape(event.resource.id)},'
        '${_csvEscape(event.resource.name ?? '')},'
        '${_csvEscape(event.outcome.name)},'
        '${_csvEscape(event.context.workspaceId)},'
        '${_csvEscape(event.context.projectId ?? '')},'
        '${_csvEscape(event.context.traceId ?? '')},'
        '${_csvEscape(event.context.requestId ?? '')},'
        '${_csvEscape(event.context.sessionId ?? '')},'
        '${_csvEscape(event.reason ?? '')},'
        '${_csvEscape(event.error ?? '')}',
      );
    }

    return utf8.encode(buffer.toString());
  }

  /// Escape a value for CSV output.
  ///
  /// Wraps the value in double quotes if it contains commas, double quotes,
  /// or newlines. Internal double quotes are escaped by doubling them.
  String _csvEscape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
