/// Audit Port Adapter - Implements `AuditPort` over the internal
/// [AuditRecorder].
///
/// See REDESIGN-PLAN.md Phase 7 §3.1 and docs/03_DDD/core-runtime.md §3.4.
///
/// Notes on type clashes: the internal `AuditEvent`/`AuditFilter` defined
/// in `observability/audit_recorder.dart` use a richer shape (actor,
/// resource, outcome, context) than the standard `mcp_bundle` types,
/// which use a flat `(type, actorId, workspaceId, payload, occurredAt)`
/// shape. This adapter converts between the two. To avoid symbol
/// ambiguity the `mcp_bundle` types are imported with a prefix and the
/// internal types are imported normally.
library;

import 'package:mcp_bundle/src/ports/audit_port.dart' as port;

import '../observability/audit_recorder.dart';

/// Adapter wrapping an internal [AuditRecorder] to expose the standard
/// [port.AuditPort] contract.
class AuditPortAdapter implements port.AuditPort {
  final AuditRecorder recorder;

  AuditPortAdapter({required this.recorder});

  @override
  Future<void> record(port.AuditEvent event) async {
    await recorder.record(_toInternal(event));
  }

  @override
  Future<List<port.AuditEvent>> query(port.AuditFilter filter) async {
    final internal = await recorder.query(_toInternalFilter(filter));
    final mapped = internal.map(_fromInternal).toList(growable: false);
    final limit = filter.limit;
    if (limit != null && mapped.length > limit) {
      return mapped.sublist(0, limit);
    }
    return mapped;
  }

  /// Convert a standard [port.AuditEvent] to the internal [AuditEvent].
  AuditEvent _toInternal(port.AuditEvent event) {
    return AuditEvent(
      id: event.id,
      timestamp: event.occurredAt,
      actor: AuditActor(
        type: ActorType.system,
        id: event.actorId ?? 'system',
      ),
      action: event.type,
      resource: AuditResource(
        type: (event.payload['resourceType'] as String?) ?? 'generic',
        id: (event.payload['resourceId'] as String?) ?? event.id,
      ),
      outcome: _parseOutcome(event.payload['outcome']),
      context: AuditContext(
        workspaceId: event.workspaceId ?? 'default',
      ),
      details: event.payload,
    );
  }

  /// Convert an internal [AuditEvent] back to the standard shape.
  port.AuditEvent _fromInternal(AuditEvent e) {
    return port.AuditEvent(
      id: e.id,
      type: e.action,
      actorId: e.actor.id,
      workspaceId: e.context.workspaceId,
      payload: {
        if (e.details != null) ...e.details!,
        'resourceType': e.resource.type,
        'resourceId': e.resource.id,
        'outcome': e.outcome.name,
        if (e.reason != null) 'reason': e.reason,
        if (e.error != null) 'error': e.error,
      },
      occurredAt: e.timestamp,
    );
  }

  /// Convert a standard filter to the internal filter shape.
  AuditFilter _toInternalFilter(port.AuditFilter filter) {
    return AuditFilter(
      startTime: filter.since,
      endTime: filter.until,
      actors: filter.actorId != null ? [filter.actorId!] : null,
      actions: filter.types,
      workspaceId: filter.workspaceId,
    );
  }

  AuditOutcome _parseOutcome(Object? value) {
    if (value is String) {
      return AuditOutcome.values.firstWhere(
        (o) => o.name == value,
        orElse: () => AuditOutcome.success,
      );
    }
    return AuditOutcome.success;
  }
}
