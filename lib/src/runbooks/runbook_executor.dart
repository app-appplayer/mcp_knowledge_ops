/// Runbook Executor - Executes operational runbooks.
///
/// Handles runbook execution with step management and variable resolution.
library;

import 'package:mcp_bundle/src/ports/approval_port.dart';

import '../models/execution_result.dart';
import '../execution/handler_registry.dart';
import 'runbook.dart';
import '../id_generator.dart';

/// Runbook executor.
class RunbookExecutor {
  /// Handler registry.
  final HandlerRegistry _handlers;

  /// Pipeline executor (injected).
  final PipelineExecutorFn? _pipelineExecutor;

  /// Workflow executor (injected).
  final WorkflowExecutorFn? _workflowExecutor;

  /// Approval port for approval steps.
  final ApprovalPort? _approvalPort;

  RunbookExecutor({
    required HandlerRegistry handlers,
    PipelineExecutorFn? pipelineExecutor,
    WorkflowExecutorFn? workflowExecutor,
    ApprovalPort? approvalPort,
  })  : _handlers = handlers,
        _pipelineExecutor = pipelineExecutor,
        _workflowExecutor = workflowExecutor,
        _approvalPort = approvalPort;

  /// Execute a runbook.
  Future<RunbookResult> execute(
    Runbook runbook,
    Map<String, dynamic> variables,
    RunbookContext context,
  ) async {
    final startTime = DateTime.now();
    final stepResults = <RunbookStepResult>[];

    // Merge default variables
    final mergedVariables = {
      ...runbook.getDefaultVariables(),
      ...variables,
    };

    // Validate variables
    final validationErrors = runbook.validateVariables(mergedVariables);
    if (validationErrors.isNotEmpty) {
      return RunbookResult(
        success: false,
        steps: stepResults,
        error: RunbookError(
          code: 'VALIDATION_ERROR',
          message: validationErrors.join(', '),
        ),
        metrics: RunbookMetrics(
          totalDuration: DateTime.now().difference(startTime),
        ),
      );
    }

    // Initialize context state
    context.state.addAll(mergedVariables);

    // Build step index for lookup by ID
    final stepIndex = <String, RunbookStep>{};
    for (final step in runbook.steps) {
      stepIndex[step.id] = step;
    }
    context.stepIndex = stepIndex;

    // Track completed step IDs for dependsOn checking
    final completedStepIds = <String>{};

    try {
      for (final step in runbook.steps) {
        // Check dependsOn: all dependencies must be completed
        if (step.dependsOn.isNotEmpty) {
          final unmet = step.dependsOn
              .where((dep) => !completedStepIds.contains(dep))
              .toList();
          if (unmet.isNotEmpty) {
            stepResults.add(RunbookStepResult(
              stepId: step.id,
              success: false,
              error: 'Unmet dependencies: ${unmet.join(', ')}',
              duration: Duration.zero,
            ));
            if (step.optional) continue;
            throw RunbookStepException(
              'Step ${step.id} has unmet dependencies: ${unmet.join(', ')}',
              stepId: step.id,
            );
          }
        }

        // Check condition
        if (step.condition != null) {
          if (!_evaluateCondition(step.condition!, context)) {
            stepResults.add(RunbookStepResult(
              stepId: step.id,
              success: true,
              duration: Duration.zero,
            ));
            completedStepIds.add(step.id);
            continue;
          }
        }

        // Run pre-checks
        if (step.preChecks.isNotEmpty) {
          final preCheckResults = _evaluateChecks(step.preChecks, context);
          final failedChecks = preCheckResults.where((r) => !r.passed).toList();
          if (failedChecks.isNotEmpty) {
            final hasFatalFailure = failedChecks.any((r) {
              final check = step.preChecks.firstWhere((c) => c.name == r.name);
              return check.severity == CheckSeverity.fail;
            });
            if (hasFatalFailure) {
              stepResults.add(RunbookStepResult(
                stepId: step.id,
                success: false,
                error:
                    'Pre-check failed: ${failedChecks.map((r) => r.name).join(', ')}',
                duration: Duration.zero,
              ));
              if (step.optional) continue;
              throw RunbookStepException(
                'Step ${step.id} pre-check failed',
                stepId: step.id,
              );
            }
          }
        }

        // Execute step
        final stepResult = await _executeStep(step, context);

        // Run post-checks on success
        if (stepResult.success && step.postChecks.isNotEmpty) {
          final postCheckResults = _evaluateChecks(step.postChecks, context);
          final failedChecks =
              postCheckResults.where((r) => !r.passed).toList();
          if (failedChecks.isNotEmpty) {
            final hasFatalFailure = failedChecks.any((r) {
              final check = step.postChecks.firstWhere((c) => c.name == r.name);
              return check.severity == CheckSeverity.fail;
            });
            if (hasFatalFailure) {
              stepResults.add(RunbookStepResult(
                stepId: step.id,
                success: false,
                error:
                    'Post-check failed: ${failedChecks.map((r) => r.name).join(', ')}',
                duration: stepResult.duration,
              ));
              if (step.optional) continue;
              throw RunbookStepException(
                'Step ${step.id} post-check failed',
                stepId: step.id,
              );
            }
          }
        }

        stepResults.add(stepResult);

        if (stepResult.success) {
          completedStepIds.add(step.id);
        } else {
          switch (step.onFailure) {
            case RunbookOnFailure.fail:
              throw RunbookStepException(
                'Step ${step.id} failed: ${stepResult.error}',
                stepId: step.id,
              );
            case RunbookOnFailure.continue_:
              completedStepIds.add(step.id);
              continue;
            case RunbookOnFailure.skip:
              continue;
            case RunbookOnFailure.rollback:
              await _rollback(stepResults, context, runbook.config);
              throw RunbookStepException(
                'Step ${step.id} failed, rolled back',
                stepId: step.id,
              );
          }
        }
      }

      return RunbookResult(
        success: true,
        steps: stepResults,
        output: context.state,
        metrics: RunbookMetrics(
          totalDuration: DateTime.now().difference(startTime),
          stepDurations: {
            for (final r in stepResults) r.stepId: r.duration,
          },
          automatedTime: DateTime.now().difference(startTime),
        ),
      );
    } catch (e) {
      // Auto-rollback if configured
      if (runbook.config?.autoRollback == true) {
        await _rollback(stepResults, context, runbook.config);
      }

      return RunbookResult(
        success: false,
        steps: stepResults,
        error: RunbookError(
          code: 'EXECUTION_ERROR',
          message: e.toString(),
          stepId: e is RunbookStepException ? e.stepId : null,
        ),
        metrics: RunbookMetrics(
          totalDuration: DateTime.now().difference(startTime),
          stepDurations: {
            for (final r in stepResults) r.stepId: r.duration,
          },
          automatedTime: DateTime.now().difference(startTime),
        ),
      );
    }
  }

  Future<RunbookStepResult> _executeStep(
    RunbookStep step,
    RunbookContext context,
  ) async {
    final startTime = DateTime.now();

    try {
      final output = await _executeAction(step.action, context);

      // Apply output mapping
      if (output != null && step.action.outputMapping.isNotEmpty) {
        if (output is Map<String, dynamic>) {
          for (final entry in step.action.outputMapping.entries) {
            if (output.containsKey(entry.key)) {
              context.state[entry.value] = output[entry.key];
            }
          }
        }
      }

      return RunbookStepResult(
        stepId: step.id,
        success: true,
        output: output,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return RunbookStepResult(
        stepId: step.id,
        success: false,
        error: e.toString(),
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  Future<dynamic> _executeAction(
    RunbookAction action,
    RunbookContext context,
  ) async {
    // Build input from mapping
    final input = <String, dynamic>{};
    for (final entry in action.inputMapping.entries) {
      if (context.state.containsKey(entry.value)) {
        input[entry.key] = context.state[entry.value];
      }
    }

    switch (action.type) {
      case RunbookStepType.pipeline:
        if (_pipelineExecutor == null) {
          throw Exception('Pipeline executor not configured');
        }
        return _pipelineExecutor!(
          action.pipelineId!,
          input.isEmpty ? context.state : input,
        );

      case RunbookStepType.workflow:
        if (_workflowExecutor == null) {
          throw Exception('Workflow executor not configured');
        }
        return _workflowExecutor!(
          action.workflowId!,
          input.isEmpty ? context.state : input,
        );

      case RunbookStepType.wait:
        final durationMs = action.config['duration'] as int? ?? 0;
        await Future.delayed(Duration(milliseconds: durationMs));
        return null;

      case RunbookStepType.approval:
        return _executeApproval(action, context);

      case RunbookStepType.decision:
        return _executeDecision(action, context);

      case RunbookStepType.parallel:
        return _executeParallel(action, context);

      case RunbookStepType.loop:
        return _executeLoop(action, context);

      case RunbookStepType.manual:
        return _executeManual(action, context);

      case RunbookStepType.notification:
        return _executeNotification(action, context);

      case RunbookStepType.script:
        return _executeScript(action, context, input);
    }
  }

  /// Execute a decision action by evaluating branches and running matching steps.
  Future<dynamic> _executeDecision(
    RunbookAction action,
    RunbookContext context,
  ) async {
    final branches = action.branches ?? [];

    // Evaluate each branch condition and execute the first match
    for (final branch in branches) {
      if (_evaluateCondition(branch.condition, context)) {
        final results = <String, dynamic>{};
        for (final stepId in branch.steps) {
          final step = context.stepIndex?[stepId];
          if (step != null) {
            final result = await _executeStep(step, context);
            results[stepId] = result.output;
          }
        }
        return {
          'branch': branch.condition,
          'results': results,
        };
      }
    }

    // Execute default branch if no condition matched
    if (action.defaultBranch != null) {
      final step = context.stepIndex?[action.defaultBranch];
      if (step != null) {
        final result = await _executeStep(step, context);
        return {
          'branch': 'default',
          'results': {action.defaultBranch: result.output},
        };
      }
    }

    return {'branch': 'none', 'results': <String, dynamic>{}};
  }

  /// Execute parallel steps concurrently using Future.wait.
  Future<dynamic> _executeParallel(
    RunbookAction action,
    RunbookContext context,
  ) async {
    final stepIds = action.parallelSteps ?? [];
    if (stepIds.isEmpty) return <String, dynamic>{};

    final futures = <Future<RunbookStepResult>>[];
    for (final stepId in stepIds) {
      final step = context.stepIndex?[stepId];
      if (step != null) {
        futures.add(_executeStep(step, context));
      }
    }

    final results = await Future.wait(
      futures,
      eagerError: action.failFast,
    );

    final output = <String, dynamic>{};
    for (final result in results) {
      output[result.stepId] = {
        'success': result.success,
        'output': result.output,
        if (result.error != null) 'error': result.error,
      };
    }

    return output;
  }

  /// Execute loop action by iterating over a collection variable.
  Future<dynamic> _executeLoop(
    RunbookAction action,
    RunbookContext context,
  ) async {
    final collectionKey = action.collection;
    final itemVar = action.itemVariable ?? 'item';
    final loopStepIds = action.loopSteps ?? [];

    if (collectionKey == null) {
      throw Exception('Loop action requires a collection variable');
    }

    final collection = context.state[collectionKey];
    if (collection is! List) {
      throw Exception(
        'Collection variable "$collectionKey" is not a List',
      );
    }

    final iterationResults = <Map<String, dynamic>>[];

    for (var i = 0; i < collection.length; i++) {
      // Set current item and index in context
      context.state[itemVar] = collection[i];
      context.state['${itemVar}_index'] = i;

      final stepResults = <String, dynamic>{};
      for (final stepId in loopStepIds) {
        final step = context.stepIndex?[stepId];
        if (step != null) {
          final result = await _executeStep(step, context);
          stepResults[stepId] = result.output;
        }
      }

      iterationResults.add({
        'index': i,
        'item': collection[i],
        'results': stepResults,
      });
    }

    // Clean up loop variables
    context.state.remove(itemVar);
    context.state.remove('${itemVar}_index');

    return {'iterations': iterationResults};
  }

  /// Execute a manual step by recording pending status and returning instructions.
  Future<dynamic> _executeManual(
    RunbookAction action,
    RunbookContext context,
  ) async {
    // Record that a manual step is pending in context
    final pendingManualSteps =
        (context.state['_pendingManualSteps'] as List<dynamic>?) ?? [];
    pendingManualSteps.add({
      'instructions': action.instructions,
      'checklist': action.checklist,
      'expectedDuration': action.expectedDuration?.inMilliseconds,
      'timestamp': DateTime.now().toIso8601String(),
    });
    context.state['_pendingManualSteps'] = pendingManualSteps;

    return {
      'status': 'pending_manual',
      'instructions': action.instructions,
      'checklist': action.checklist,
      'expectedDuration': action.expectedDuration?.inMilliseconds,
    };
  }

  /// Execute a notification action by returning notification data.
  ///
  /// Actual delivery is handled via the notification port.
  Future<dynamic> _executeNotification(
    RunbookAction action,
    RunbookContext context,
  ) async {
    return {
      'status': 'notification_queued',
      'channel': action.channel,
      'template': action.template,
      'recipients': action.recipients,
      'config': action.config,
    };
  }

  /// Execute a script action via the handler registry (script handlers).
  Future<dynamic> _executeScript(
    RunbookAction action,
    RunbookContext context,
    Map<String, dynamic> input,
  ) async {
    // Look up script handler by interpreter or use default 'script' handler
    final handlerName = action.interpreter ?? 'script';
    final handler = _handlers.get(handlerName);
    if (handler == null) {
      throw Exception('Script handler not found: $handlerName');
    }

    final scriptInput = <String, dynamic>{
      ...input.isEmpty ? context.state : input,
      '_script': action.script,
    };

    return handler.execute(
      scriptInput,
      HandlerContext(
        runId: context.runId,
        stageId: 'runbook_script',
        traceId: context.traceId ?? '',
        asOf: DateTime.now(),
        config: action.config,
      ),
    );
  }

  bool _evaluateCondition(String condition, RunbookContext context) {
    final trimmed = condition.trim();

    if (trimmed == 'true') return true;
    if (trimmed == 'false') return false;

    // Support equality check: variable == value
    if (trimmed.contains('==')) {
      final parts = trimmed.split('==').map((p) => p.trim()).toList();
      if (parts.length == 2) {
        final leftValue = context.state[parts[0]];
        final rightValue = parts[1];
        // Compare as strings after removing quotes
        final cleanRight = rightValue.replaceAll("'", '').replaceAll('"', '');
        return leftValue?.toString() == cleanRight;
      }
    }

    // Support inequality check: variable != value
    if (trimmed.contains('!=')) {
      final parts = trimmed.split('!=').map((p) => p.trim()).toList();
      if (parts.length == 2) {
        final leftValue = context.state[parts[0]];
        final rightValue = parts[1];
        final cleanRight = rightValue.replaceAll("'", '').replaceAll('"', '');
        return leftValue?.toString() != cleanRight;
      }
    }

    // Check state variable
    final value = context.state[trimmed];
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.isNotEmpty;
    if (value is num) return value != 0;
    return true;
  }

  /// Execute an approval action via the ApprovalPort.
  Future<dynamic> _executeApproval(
    RunbookAction action,
    RunbookContext context,
  ) async {
    if (_approvalPort == null) {
      // Fallback: auto-approve when no approval port configured
      return {'approved': true, 'method': 'auto'};
    }

    final approvers =
        (action.config['approvers'] as List<dynamic>?)?.cast<String>() ?? [];
    final requiredApprovals = action.config['requiredApprovals'] as int? ?? 1;
    final timeoutSeconds = action.config['timeout'] as int?;

    final result = await _approvalPort!.requestApproval(ApprovalRequest(
      requestId: generateId('${context.runId}_approval'),
      requestType: 'runbook_step',
      requesterId: context.workspaceId,
      description: action.config['description'] as String? ??
          'Runbook approval required',
      context: {
        'runId': context.runId,
        'workspaceId': context.workspaceId,
        'requiredApprovals': requiredApprovals,
      },
      approverIds: approvers,
      timeout:
          timeoutSeconds != null ? Duration(seconds: timeoutSeconds) : null,
    ));

    if (result.isRejected) {
      throw Exception(
          'Approval rejected: ${result.reason ?? 'no reason provided'}');
    }

    if (!result.isApproved) {
      throw Exception('Approval not granted: status=${result.status.name}');
    }

    return {
      'approved': true,
      'approvalId': result.approvalId,
      'approverId': result.approverId,
      'decidedAt': result.decidedAt?.toIso8601String(),
    };
  }

  /// Evaluate step pre/post checks against the current context state.
  List<CheckResult> _evaluateChecks(
    List<StepCheck> checks,
    RunbookContext context,
  ) {
    final results = <CheckResult>[];
    for (final check in checks) {
      bool passed;
      String? message;

      switch (check.type) {
        case CheckType.expression:
          final expr = check.config['expression'] as String?;
          if (expr != null) {
            passed = _evaluateCondition(expr, context);
            message = passed ? null : 'Expression "$expr" evaluated to false';
          } else {
            passed = false;
            message = 'No expression configured';
          }
        case CheckType.metric:
          final metricName = check.config['metric'] as String?;
          final threshold = check.config['threshold'] as num?;
          final op = check.config['operator'] as String? ?? '>=';
          if (metricName != null && threshold != null) {
            final value = context.state[metricName] as num?;
            if (value == null) {
              passed = false;
              message = 'Metric "$metricName" not found in context';
            } else {
              passed = switch (op) {
                '>=' => value >= threshold,
                '>' => value > threshold,
                '<=' => value <= threshold,
                '<' => value < threshold,
                '==' => value == threshold,
                _ => false,
              };
              message = passed
                  ? null
                  : 'Metric "$metricName" ($value) $op $threshold failed';
            }
          } else {
            passed = false;
            message = 'Metric check missing metric name or threshold';
          }
        case CheckType.command:
          // Command checks require external execution; mark as passed if result in state
          final resultKey = check.config['resultKey'] as String?;
          if (resultKey != null && context.state.containsKey(resultKey)) {
            final value = context.state[resultKey];
            passed = value == true || value == 'success' || value == 0;
          } else {
            passed = true;
            message = 'Command check skipped (no result available)';
          }
      }

      results.add(CheckResult(
        name: check.name,
        passed: passed,
        message: message,
      ));
    }
    return results;
  }

  /// Rollback completed steps, executing rollback steps if configured.
  Future<void> _rollback(
    List<RunbookStepResult> completedSteps,
    RunbookContext context,
    RunbookConfig? config,
  ) async {
    context.state['_rolledBack'] = true;

    final successfulStepIds =
        completedSteps.where((r) => r.success).map((r) => r.stepId).toList();
    context.state['_rollbackSteps'] = successfulStepIds;

    // Execute configured rollback steps if available
    if (config != null && config.rollbackSteps.isNotEmpty) {
      for (final rollbackStepId in config.rollbackSteps) {
        final step = context.stepIndex?[rollbackStepId];
        if (step != null) {
          try {
            await _executeStep(step, context);
          } catch (_) {
            // Best-effort rollback: continue even if a rollback step fails
          }
        }
      }
    }
  }
}

/// Pipeline executor function type.
typedef PipelineExecutorFn = Future<dynamic> Function(
  String pipelineId,
  Map<String, dynamic> input,
);

/// Workflow executor function type.
typedef WorkflowExecutorFn = Future<dynamic> Function(
  String workflowId,
  Map<String, dynamic> input,
);

/// Runbook execution context.
class RunbookContext {
  /// Run identifier.
  final String runId;

  /// Trace identifier.
  final String? traceId;

  /// Workspace identifier.
  final String workspaceId;

  /// Accumulated state.
  final Map<String, dynamic> state;

  /// Index of steps by ID for lookup during execution.
  Map<String, RunbookStep>? stepIndex;

  RunbookContext({
    required this.runId,
    this.traceId,
    required this.workspaceId,
    Map<String, dynamic>? state,
  }) : state = state ?? {};
}

/// Runbook step exception.
class RunbookStepException implements Exception {
  final String message;
  final String? stepId;

  RunbookStepException(this.message, {this.stepId});

  @override
  String toString() => 'RunbookStepException: $message';
}
