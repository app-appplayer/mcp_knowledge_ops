/// MCP tool definitions for scheduler operations.
///
/// Provides schema definitions for all scheduler-related MCP tools,
/// including schedule management, execution control, and queue monitoring.
library;

import 'scheduler.dart';

/// MCP tool schema definitions for scheduler operations.
class SchedulerMcpTools {
  /// Schema for listing all schedules.
  static Map<String, dynamic> listSchedulesSchema() => {
        'name': 'scheduler.listSchedules',
        'description': 'List all schedules',
        'input': {'status': 'String?', 'type': 'String?'},
        'output': {'schedules': 'Schedule[]'},
      };

  /// Schema for creating a new schedule.
  static Map<String, dynamic> createScheduleSchema() => {
        'name': 'scheduler.createSchedule',
        'description': 'Create a new schedule',
        'input': {
          'name': 'String',
          'type': 'String',
          'trigger': 'Map',
          'config': 'Map?',
        },
        'output': {'scheduleId': 'String'},
      };

  /// Schema for pausing a schedule.
  static Map<String, dynamic> pauseScheduleSchema() => {
        'name': 'scheduler.pauseSchedule',
        'description': 'Pause a schedule',
        'input': {'scheduleId': 'String'},
        'output': {'success': 'bool'},
      };

  /// Schema for resuming a paused schedule.
  static Map<String, dynamic> resumeScheduleSchema() => {
        'name': 'scheduler.resumeSchedule',
        'description': 'Resume a paused schedule',
        'input': {'scheduleId': 'String'},
        'output': {'success': 'bool'},
      };

  /// Schema for triggering immediate execution.
  static Map<String, dynamic> triggerNowSchema() => {
        'name': 'scheduler.triggerNow',
        'description': 'Trigger immediate execution',
        'input': {'scheduleId': 'String', 'input': 'Map?'},
        'output': {'executionId': 'String'},
      };

  /// Schema for getting execution status.
  static Map<String, dynamic> getExecutionStatusSchema() => {
        'name': 'scheduler.getExecutionStatus',
        'description': 'Get execution status',
        'input': {'executionId': 'String'},
        'output': {'execution': 'Execution'},
      };

  /// Schema for cancelling a running execution.
  static Map<String, dynamic> cancelExecutionSchema() => {
        'name': 'scheduler.cancelExecution',
        'description': 'Cancel a running execution',
        'input': {'executionId': 'String', 'reason': 'String?'},
        'output': {'success': 'bool'},
      };

  /// Schema for getting execution queue statistics.
  static Map<String, dynamic> getQueueStatsSchema() => {
        'name': 'scheduler.getQueueStats',
        'description': 'Get execution queue statistics',
        'input': <String, dynamic>{},
        'output': {'stats': 'QueueStats'},
      };

  /// All scheduler MCP tool schemas.
  static List<Map<String, dynamic>> allSchemas() => [
        listSchedulesSchema(),
        createScheduleSchema(),
        pauseScheduleSchema(),
        resumeScheduleSchema(),
        triggerNowSchema(),
        getExecutionStatusSchema(),
        cancelExecutionSchema(),
        getQueueStatsSchema(),
      ];

  /// Dispatch a tool call to the appropriate Scheduler method.
  ///
  /// Returns a result map or throws if the tool name is unknown.
  static Future<Map<String, dynamic>> dispatch(
    String toolName,
    Map<String, dynamic> input,
    Scheduler scheduler,
  ) async {
    switch (toolName) {
      case 'scheduler.listSchedules':
        final statusStr = input['status'] as String?;
        ScheduleStatus? status;
        if (statusStr != null) {
          status = ScheduleStatus.values
              .where((s) => s.name == statusStr)
              .firstOrNull;
        }
        final tasks = scheduler.listTasks(status: status);
        return {
          'schedules': tasks
              .map((t) => {
                    'id': t.id,
                    'name': t.name,
                    'status': t.status.name,
                    'priority': t.priority,
                  })
              .toList(),
        };

      case 'scheduler.pauseSchedule':
        final scheduleId = input['scheduleId'] as String;
        await scheduler.pause(scheduleId);
        return {'success': true};

      case 'scheduler.resumeSchedule':
        final scheduleId = input['scheduleId'] as String;
        await scheduler.resume(scheduleId);
        return {'success': true};

      case 'scheduler.triggerNow':
        final scheduleId = input['scheduleId'] as String;
        final triggerInput = input['input'] as Map<String, dynamic>?;
        final execution = await scheduler.triggerManually(
          scheduleId,
          data: triggerInput,
        );
        return {
          'executionId': execution.taskId,
          'status': execution.status.name,
        };

      case 'scheduler.getQueueStats':
        final stats = scheduler.queue.getStats();
        return {'stats': stats.toJson()};

      default:
        throw ArgumentError('Unknown scheduler tool: $toolName');
    }
  }
}
