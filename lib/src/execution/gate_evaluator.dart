/// Gate Evaluator - Evaluates quality gates between stages.
///
/// Handles threshold checks, expression evaluation, and approval conditions.
library;

import '../models/execution_context.dart';
import '../models/gate.dart';

/// Evaluates quality gates.
class GateEvaluator {
  /// Expression evaluator.
  final ExpressionEvaluator _expressionEvaluator;

  GateEvaluator({
    ExpressionEvaluator? expressionEvaluator,
  }) : _expressionEvaluator = expressionEvaluator ?? ExpressionEvaluator();

  /// Evaluate a gate.
  Future<GateResult> evaluate(
    Gate gate,
    ExecutionContext context,
  ) async {
    final startTime = DateTime.now();
    final conditionResults = <ConditionResult>[];

    for (var i = 0; i < gate.conditions.length; i++) {
      final condition = gate.conditions[i];
      final result = await _evaluateCondition(condition, i, context);
      conditionResults.add(result);

      // Early exit on failure if blocking
      if (!result.passed && gate.onFailure == GateFailure.block) {
        return GateResult(
          gateId: gate.id,
          passed: false,
          conditionResults: conditionResults,
          evaluatedAt: startTime,
          duration: DateTime.now().difference(startTime),
        );
      }
    }

    final allPassed = conditionResults.every((r) => r.passed);
    return GateResult(
      gateId: gate.id,
      passed: allPassed,
      conditionResults: conditionResults,
      evaluatedAt: startTime,
      duration: DateTime.now().difference(startTime),
    );
  }

  Future<ConditionResult> _evaluateCondition(
    GateCondition condition,
    int index,
    ExecutionContext context,
  ) async {
    // Generate condition ID from type and index
    final conditionId = '${condition.type.name}_$index';

    switch (condition.type) {
      case ConditionType.threshold:
        return _evaluateThreshold(condition, conditionId, context);
      case ConditionType.expression:
        return _evaluateExpression(condition, conditionId, context);
      case ConditionType.approval:
        return _checkApproval(condition, conditionId, context);
    }
  }

  ConditionResult _evaluateThreshold(
    GateCondition condition,
    String conditionId,
    ExecutionContext context,
  ) {
    if (condition.metric == null) {
      return ConditionResult.failed(
        conditionId,
        message: 'Threshold condition requires a metric',
      );
    }

    final actualValue = _expressionEvaluator.evaluateValue(
      condition.metric!,
      context,
    );

    if (actualValue == null) {
      return ConditionResult.failed(
        conditionId,
        message: 'Metric not found: ${condition.metric}',
      );
    }

    final numValue = actualValue is num
        ? actualValue.toDouble()
        : double.tryParse(actualValue.toString());

    if (numValue == null) {
      return ConditionResult.failed(
        conditionId,
        actual: actualValue,
        message: 'Metric value is not numeric',
      );
    }

    final threshold = condition.value is num
        ? (condition.value as num).toDouble()
        : double.tryParse(condition.value?.toString() ?? '') ?? 0;
    final operator = condition.operator ?? '>=';

    final passed = _compareThreshold(numValue, threshold, operator);

    return ConditionResult(
      conditionId: conditionId,
      passed: passed,
      actual: numValue,
      expected: threshold,
      message: passed ? null : 'Expected $operator $threshold, got $numValue',
    );
  }

  bool _compareThreshold(
    double value,
    double threshold,
    String operator,
  ) {
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
        return value >= threshold;
    }
  }

  ConditionResult _evaluateExpression(
    GateCondition condition,
    String conditionId,
    ExecutionContext context,
  ) {
    if (condition.expression == null) {
      return ConditionResult.failed(
        conditionId,
        message: 'Expression condition requires an expression',
      );
    }

    try {
      final result = _expressionEvaluator.evaluateCondition(
        condition.expression!,
        context,
      );

      return ConditionResult(
        conditionId: conditionId,
        passed: result,
        message: result ? null : 'Expression evaluated to false',
      );
    } catch (e) {
      return ConditionResult.failed(
        conditionId,
        message: 'Expression evaluation error: $e',
      );
    }
  }

  ConditionResult _checkApproval(
    GateCondition condition,
    String conditionId,
    ExecutionContext context,
  ) {
    // Check if approval is recorded in context state
    final approvalKey = 'approvals.$conditionId';
    final approval = context.getState<Map<String, dynamic>>(approvalKey);

    if (approval == null) {
      return ConditionResult.failed(
        conditionId,
        message: 'Approval not found',
      );
    }

    final approved = approval['approved'] as bool? ?? false;
    final approver = approval['approver'] as String?;

    // Check if approver is in allowed list
    if (approved && condition.approvers != null) {
      if (approver != null && !condition.approvers!.contains(approver)) {
        return ConditionResult.failed(
          conditionId,
          message: 'Approver $approver not in allowed list',
        );
      }
    }

    return ConditionResult(
      conditionId: conditionId,
      passed: approved,
      message: approved ? 'Approved by $approver' : 'Not approved',
    );
  }
}

/// Expression evaluator for conditions and mappings.
class ExpressionEvaluator {
  /// Evaluate a condition expression.
  bool evaluateCondition(String expression, ExecutionContext context) {
    final env = _buildEnvironment(context);
    final result = _evaluate(expression, env);
    return result == true;
  }

  /// Evaluate a value expression.
  dynamic evaluateValue(String expression, ExecutionContext context) {
    final env = _buildEnvironment(context);
    return _evaluate(expression, env);
  }

  /// Evaluate input/output mapping.
  Map<String, dynamic> evaluateMapping(
    Map<String, String> mapping,
    ExecutionContext context,
  ) {
    final result = <String, dynamic>{};
    final env = _buildEnvironment(context);

    for (final entry in mapping.entries) {
      result[entry.key] = _evaluate(entry.value, env);
    }

    return result;
  }

  Map<String, dynamic> _buildEnvironment(ExecutionContext context) {
    return {
      'input': context.getState('input'),
      'state': context.state,
      'stages': context.state['stages'] ?? {},
      'config': {
        'timeout': context.config.timeout.inSeconds,
        'dryRun': context.config.dryRun,
        'checkpointEnabled': context.config.checkpointEnabled,
      },
      'variables': context.variables,
      'context': {
        'runId': context.runId,
        'workspaceId': context.workspaceId,
        'userId': context.userId,
        'asOf': context.asOf.toIso8601String(),
      },
    };
  }

  dynamic _evaluate(String expression, Map<String, dynamic> env) {
    // Variable reference: ${path.to.value}
    if (expression.startsWith(r'${') && expression.endsWith('}')) {
      final path = expression.substring(2, expression.length - 1);
      return _resolvePath(path, env);
    }

    // Boolean expressions
    if (expression.contains('&&') || expression.contains('||')) {
      return _evaluateBoolean(expression, env);
    }

    // Comparison expressions
    if (expression.contains('==') ||
        expression.contains('!=') ||
        expression.contains('>') ||
        expression.contains('<')) {
      return _evaluateComparison(expression, env);
    }

    // Literal values
    if (expression == 'true') return true;
    if (expression == 'false') return false;
    if (expression == 'null') return null;

    final numValue = num.tryParse(expression);
    if (numValue != null) return numValue;

    // Try as path
    return _resolvePath(expression, env);
  }

  dynamic _resolvePath(String path, Map<String, dynamic> env) {
    final parts = path.split('.');
    dynamic current = env;

    for (final part in parts) {
      if (current is Map) {
        current = current[part];
      } else if (current is List && int.tryParse(part) != null) {
        final index = int.parse(part);
        if (index >= 0 && index < current.length) {
          current = current[index];
        } else {
          return null;
        }
      } else {
        return null;
      }
    }

    return current;
  }

  bool _evaluateBoolean(String expression, Map<String, dynamic> env) {
    // Handle OR
    if (expression.contains('||')) {
      final parts = expression.split('||');
      return parts.any((p) => _evaluate(p.trim(), env) == true);
    }

    // Only called for an expression with `||` or `&&`: AND.
    final parts = expression.split('&&');
    return parts.every((p) => _evaluate(p.trim(), env) == true);
  }

  bool _evaluateComparison(String expression, Map<String, dynamic> env) {
    // Parse comparison
    final operators = ['==', '!=', '>=', '<=', '>', '<'];
    for (final op in operators) {
      if (expression.contains(op)) {
        final parts = expression.split(op);
        if (parts.length == 2) {
          final left = _evaluate(parts[0].trim(), env);
          final right = _evaluate(parts[1].trim(), env);
          return _compare(left, right, op);
        }
      }
    }
    return false;
  }

  bool _compare(dynamic left, dynamic right, String operator) {
    switch (operator) {
      case '==':
        return left == right;
      case '!=':
        return left != right;
      case '>':
        return (left as num) > (right as num);
      case '>=':
        return (left as num) >= (right as num);
      case '<':
        return (left as num) < (right as num);
      default: // '<='
        return (left as num) <= (right as num);
    }
  }
}
