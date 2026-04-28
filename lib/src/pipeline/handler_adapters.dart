/// Handler Adapters - Built-in handler adapters and registration service.
///
/// Provides adapter implementations that wrap standard capability-named
/// ports (McpPort, LlmPort, PhilosophyPort) as `StageHandler` instances
/// so pipelines can reuse them declaratively via `HandlerRegistry`.
///
/// Per REDESIGN-PLAN.md Phase 7 (no-legacy) this module does not
/// reference `FactGraphPort`, `SkillPort`, `ProfilePort`, or `BundlePort`.
library;

import 'package:mcp_bundle/src/ports/philosophy_port.dart' as phil;

import '../execution/handler_registry.dart';
import '../ports/ops_port.dart';

/// Service for registering and managing stage handlers.
///
/// Provides a higher-level API over [HandlerRegistry] with support for
/// handler lookup and lifecycle management.
class HandlerRegistrationService {
  final Map<String, StageHandler<dynamic, dynamic>> _handlers = {};

  /// Register a handler for a stage type.
  void register(String handlerName, StageHandler<dynamic, dynamic> handler) {
    _handlers[handlerName] = handler;
  }

  /// Unregister a handler.
  void unregister(String handlerName) {
    _handlers.remove(handlerName);
  }

  /// Get handler by name.
  StageHandler<dynamic, dynamic>? getHandler(String handlerName) =>
      _handlers[handlerName];

  /// List registered handler names.
  List<String> listHandlers() => _handlers.keys.toList();

  /// Check if a handler is registered.
  bool has(String handlerName) => _handlers.containsKey(handlerName);

  /// Clear all registered handlers.
  void clear() => _handlers.clear();
}

/// Adapter that invokes an MCP tool via the standard [McpPort].
///
/// Handler name convention: `mcp.<toolName>`.
class McpToolHandlerAdapter
    extends StageHandler<Map<String, dynamic>, Map<String, dynamic>> {
  @override
  final String name;

  /// MCP tool name to invoke.
  final String toolName;

  /// Default parameters merged with the stage input.
  final Map<String, dynamic>? defaultParams;

  /// Optional server id routing.
  final String? serverId;

  /// Ports for accessing MCP capabilities.
  final OpsPorts? _ports;

  McpToolHandlerAdapter({
    required this.toolName,
    this.defaultParams,
    this.serverId,
    OpsPorts? ports,
    String? name,
  })  : _ports = ports,
        name = name ?? 'mcp.$toolName';

  @override
  List<String> get requires => ['mcp'];

  @override
  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> input,
    HandlerContext context,
  ) async {
    final ports = context.ports ?? _ports;
    final mcp = ports?.mcp;
    if (mcp == null) {
      throw StateError('McpPort required for tool: $toolName');
    }

    final args = {...?defaultParams, ...input};
    final result = await mcp.callTool(toolName, args, serverId: serverId);
    return {
      'toolName': toolName,
      'content': result.content,
      'isError': result.isError,
      if (result.errorMessage != null) 'errorMessage': result.errorMessage,
    };
  }
}

/// Adapter that invokes the [LlmPort] with a prompt template.
///
/// Handler name convention: `llm.<purpose>`.
class LlmHandlerAdapter
    extends StageHandler<Map<String, dynamic>, Map<String, dynamic>> {
  @override
  final String name;

  /// Prompt template (uses `{{key}}` placeholders).
  final String prompt;

  /// Model identifier (optional).
  final String? model;

  /// Additional LLM configuration.
  final Map<String, dynamic>? config;

  /// Ports for accessing LLM capabilities.
  final OpsPorts? _ports;

  LlmHandlerAdapter({
    required this.prompt,
    this.model,
    this.config,
    OpsPorts? ports,
    String? name,
  })  : _ports = ports,
        name = name ?? 'llm.complete';

  @override
  List<String> get requires => ['llm'];

  @override
  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> input,
    HandlerContext context,
  ) async {
    final ports = context.ports ?? _ports;
    final llm = ports?.llm;
    if (llm == null) {
      throw StateError('LlmPort required for LLM handler');
    }

    // Interpolate input variables into prompt template.
    var resolvedPrompt = prompt;
    for (final entry in input.entries) {
      resolvedPrompt =
          resolvedPrompt.replaceAll('{{${entry.key}}}', '${entry.value}');
    }

    final response = await llm.complete(LlmRequest(
      prompt: resolvedPrompt,
      model: model,
      options: config,
    ));

    return {
      'response': response.content,
      'model': model,
      'prompt': resolvedPrompt,
    };
  }
}

/// Adapter for expression-based handlers.
///
/// Evaluates a simple expression against the input data. Supports
/// dot-path access, binary comparisons, and null-coalescing.
class ExpressionHandlerAdapter
    extends StageHandler<Map<String, dynamic>, Map<String, dynamic>> {
  @override
  final String name;

  /// Expression to evaluate.
  final String expression;

  ExpressionHandlerAdapter({
    required this.expression,
    String? name,
  }) : name = name ?? 'expression_handler';

  @override
  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> input,
    HandlerContext context,
  ) async {
    final result = _evaluateExpression(expression, input);
    return {'result': result, 'expression': expression};
  }

  dynamic _evaluateExpression(String expr, Map<String, dynamic> data) {
    if (expr.contains('??')) {
      final parts = expr.split('??').map((p) => p.trim()).toList();
      final value = _resolvePath(parts[0], data);
      return value ?? (parts.length > 1 ? parts[1] : null);
    }

    for (final op in ['>=', '<=', '!=', '==', '>', '<']) {
      if (expr.contains(op)) {
        final parts = expr.split(op).map((p) => p.trim()).toList();
        if (parts.length == 2) {
          final left = _resolveValue(parts[0], data);
          final right = _resolveValue(parts[1], data);
          if (left is num && right is num) {
            return _compare(left, op, right);
          }
          if (op == '==') return left == right;
          if (op == '!=') return left != right;
        }
      }
    }

    return _resolvePath(expr, data);
  }

  dynamic _resolvePath(String path, Map<String, dynamic> data) {
    final parts = path.split('.');
    dynamic current = data;
    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  dynamic _resolveValue(String value, Map<String, dynamic> data) {
    final num_ = num.tryParse(value);
    if (num_ != null) return num_;

    if (value == 'true') return true;
    if (value == 'false') return false;

    if ((value.startsWith("'") && value.endsWith("'")) ||
        (value.startsWith('"') && value.endsWith('"'))) {
      return value.substring(1, value.length - 1);
    }

    return _resolvePath(value, data);
  }

  bool _compare(num left, String op, num right) {
    switch (op) {
      case '>':
        return left > right;
      case '>=':
        return left >= right;
      case '<':
        return left < right;
      case '<=':
        return left <= right;
      case '==':
        return left == right;
      case '!=':
        return left != right;
      default:
        return false;
    }
  }
}

/// Adapter that invokes [PhilosophyPort.intervene] as a stage handler.
class PhilosophyInterventionHandlerAdapter
    extends StageHandler<Map<String, dynamic>, Map<String, dynamic>> {
  @override
  final String name;

  /// Intervention point for this handler.
  final InterventionPoint interventionPoint;

  PhilosophyInterventionHandlerAdapter({
    this.interventionPoint = InterventionPoint.preGeneration,
    String? name,
  }) : name = name ?? 'philosophy.intervene.${interventionPoint.name}';

  @override
  List<String> get requires => ['philosophy'];

  @override
  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> input,
    HandlerContext context,
  ) async {
    final philosophy = context.ports?.philosophy;
    if (philosophy == null) {
      return {'status': 'skipped', 'reason': 'Philosophy port not available'};
    }

    final pipelineId = context.pipelineId ?? context.stageId;
    final result = await philosophy.intervene(
      interventionPoint,
      phil.PipelineContext(
        pipelineId: pipelineId,
        currentPoint: interventionPoint,
        knowledgeRetrieved: input,
      ),
    );

    return {
      'blocksDelivery': result.blocksDelivery,
      'modifications': result.modifications,
      'status': result.blocksDelivery ? 'blocked' : 'passed',
    };
  }
}

/// Adapter that invokes [PhilosophyPort.checkProhibitions] as a stage handler.
class PhilosophyProhibitionHandlerAdapter
    extends StageHandler<Map<String, dynamic>, Map<String, dynamic>> {
  @override
  final String name;

  PhilosophyProhibitionHandlerAdapter({
    String? name,
  }) : name = name ?? 'philosophy.checkProhibitions';

  @override
  List<String> get requires => ['philosophy'];

  @override
  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> input,
    HandlerContext context,
  ) async {
    final philosophy = context.ports?.philosophy;
    if (philosophy == null) {
      return {'status': 'skipped', 'reason': 'Philosophy port not available'};
    }

    final result = await philosophy.checkProhibitions(
      ProhibitionCheckRequest(
        proposedAction: input['action'] as String?,
        proposedOutput: input['output'] as String?,
        context: input,
      ),
    );

    return {
      'hasHardViolation': result.hasHardViolation,
      'hardViolationIds': result.hardViolationIds,
      'softViolationIds': result.softViolationIds,
      'checkCount': result.checks.length,
      'status': result.hasHardViolation ? 'violated' : 'passed',
    };
  }
}
