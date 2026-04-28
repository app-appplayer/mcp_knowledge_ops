/// Handler Registry - Registry of stage handlers.
///
/// Manages registration and lookup of stage handlers for pipeline execution.
library;

import '../models/execution_context.dart';
import '../ports/ops_port.dart';

/// Registry of stage handlers.
class HandlerRegistry {
  final Map<String, StageHandler<dynamic, dynamic>> _handlers = {};

  /// Register a handler.
  void register(String name, StageHandler<dynamic, dynamic> handler) {
    _handlers[name] = handler;
  }

  /// Unregister a handler.
  void unregister(String name) {
    _handlers.remove(name);
  }

  /// Get a handler by name.
  StageHandler<dynamic, dynamic>? get(String name) => _handlers[name];

  /// Check if a handler exists.
  bool has(String name) => _handlers.containsKey(name);

  /// List all registered handlers with metadata.
  List<HandlerInfo> listHandlers() => _handlers.entries
      .map((e) => HandlerInfo(
            name: e.key,
            id: e.value.id,
            version: e.value.version,
            inputSchema: e.value.inputSchema,
            outputSchema: e.value.outputSchema,
            requires: e.value.requires,
          ))
      .toList();

  /// Clear all handlers.
  void clear() => _handlers.clear();

  /// Register multiple handlers.
  void registerAll(Map<String, StageHandler<dynamic, dynamic>> handlers) {
    _handlers.addAll(handlers);
  }

  /// Find handlers matching a pattern.
  List<HandlerInfo> findByPattern(String pattern) {
    final regex = RegExp(pattern.replaceAll('*', '.*'));
    return _handlers.entries
        .where((e) => regex.hasMatch(e.key))
        .map((e) => HandlerInfo(
              name: e.key,
              id: e.value.id,
              version: e.value.version,
              inputSchema: e.value.inputSchema,
              outputSchema: e.value.outputSchema,
              requires: e.value.requires,
            ))
        .toList();
  }

  /// Validate that all required handlers for a pipeline are registered.
  List<String> validate(List<String> requiredHandlers) {
    return requiredHandlers.where((h) => !_handlers.containsKey(h)).toList();
  }
}

/// Handler metadata information.
class HandlerInfo {
  /// Handler registered name.
  final String name;

  /// Handler identifier.
  final String id;

  /// Handler version.
  final String version;

  /// Input schema descriptor.
  final Map<String, dynamic>? inputSchema;

  /// Output schema descriptor.
  final Map<String, dynamic>? outputSchema;

  /// Required port/capability names.
  final List<String> requires;

  const HandlerInfo({
    required this.name,
    required this.id,
    required this.version,
    this.inputSchema,
    this.outputSchema,
    this.requires = const [],
  });
}

/// Filter for querying handlers.
class HandlerFilter {
  /// Pattern match on handler name.
  final String? namePattern;

  /// Required version.
  final String? version;

  /// Required capabilities.
  final List<String>? requires;

  const HandlerFilter({
    this.namePattern,
    this.version,
    this.requires,
  });
}

/// Base stage handler interface.
abstract class StageHandler<TInput, TOutput> {
  /// Execute the handler.
  Future<TOutput> execute(TInput input, HandlerContext context);

  /// Handler name.
  String get name;

  /// Handler identifier.
  String get id => name;

  /// Handler version.
  String get version => '1.0.0';

  /// Input schema descriptor.
  Map<String, dynamic>? get inputSchema => null;

  /// Output schema descriptor.
  Map<String, dynamic>? get outputSchema => null;

  /// Required port/capability names.
  List<String> get requires => const [];

  /// Validate input before execution.
  List<String> validateInput(TInput input) => const [];

  /// Cleanup resources after execution.
  Future<void> cleanup() async {}
}

/// Context provided to handlers.
///
/// Includes access to OpsPorts for port composition pattern.
class HandlerContext {
  /// Execution run ID.
  final String runId;

  /// Stage ID.
  final String stageId;

  /// Pipeline ID.
  final String? pipelineId;

  /// Trace ID.
  final String traceId;

  /// Execution timestamp.
  final DateTime asOf;

  /// Stage configuration.
  final Map<String, dynamic> config;

  /// Aggregated ports for handler port composition.
  final OpsPorts? ports;

  /// Event emission callback.
  final void Function(String eventType, Map<String, dynamic> data)? emit;

  /// Checkpoint callback.
  final Future<void> Function(dynamic state)? checkpoint;

  /// Execution context reference.
  final ExecutionContext? executionContext;

  const HandlerContext({
    required this.runId,
    required this.stageId,
    this.pipelineId,
    required this.traceId,
    required this.asOf,
    this.config = const {},
    this.ports,
    this.emit,
    this.checkpoint,
    this.executionContext,
  });

  /// Get configuration value.
  T? getConfig<T>(String key) => config[key] as T?;
}

/// Function-based handler for simple cases.
class FunctionHandler extends StageHandler<dynamic, dynamic> {
  @override
  final String name;

  final Future<dynamic> Function(dynamic input, HandlerContext context)
      _handler;

  FunctionHandler({
    required this.name,
    required Future<dynamic> Function(dynamic input, HandlerContext context)
        handler,
  }) : _handler = handler;

  @override
  Future<dynamic> execute(dynamic input, HandlerContext context) {
    return _handler(input, context);
  }
}
