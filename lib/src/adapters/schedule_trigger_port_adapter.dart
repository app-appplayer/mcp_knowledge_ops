/// Schedule Trigger Port Adapter - Implements `ScheduleTriggerPort` over
/// the internal [Scheduler].
///
/// See REDESIGN-PLAN.md Phase 7 §3.1 and docs/03_DDD/core-runtime.md §3.3.
library;

import 'package:mcp_bundle/src/ports/schedule_trigger_port.dart';

import '../scheduler/scheduler.dart';

/// Adapter exposing the internal [Scheduler] via the standard
/// [ScheduleTriggerPort] contract.
///
/// Maps [ScheduleTarget] payloads to a single scheduled action that the
/// host provides at construction time. The action receives the target
/// kind + id + parameters as the `data` map; the host decides how to
/// dispatch (typically via `PipelinePortAdapter.runPipeline` /
/// `WorkflowPortAdapter.runWorkflow` / `RunbookPortAdapter.runRunbook`).
class ScheduleTriggerPortAdapter implements ScheduleTriggerPort {
  /// The underlying scheduler.
  final Scheduler scheduler;

  /// Action invoked when a schedule fires.
  final ScheduledAction action;

  ScheduleTriggerPortAdapter({
    required this.scheduler,
    required this.action,
  });

  @override
  Future<String> schedule(String cron, ScheduleTarget target) async {
    final taskId =
        'sched-${DateTime.now().microsecondsSinceEpoch}-${target.kind}-${target.id}';
    await scheduler.register(
      taskId: taskId,
      trigger: CronTrigger(cron, id: taskId),
      action: (data) async {
        await action({
          'kind': target.kind,
          'id': target.id,
          'parameters': target.parameters,
          'event': data,
        });
      },
    );
    return taskId;
  }

  @override
  Future<void> trigger(
    ScheduleTarget target,
    Map<String, dynamic> event,
  ) async {
    await action({
      'kind': target.kind,
      'id': target.id,
      'parameters': target.parameters,
      'event': event,
    });
  }

  @override
  Future<void> unschedule(String scheduleId) async {
    await scheduler.unregister(scheduleId);
  }
}
