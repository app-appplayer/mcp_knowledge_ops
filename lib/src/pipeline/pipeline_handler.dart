/// Pipeline Handler - Handler interface and registry.
///
/// Defines the handler interface and registry for pipeline stage execution.
library;

/// Base interface for pipeline stage handlers.
abstract class PipelineHandler<TInput, TOutput> {
  /// Unique handler identifier.
  String get id;

  /// Human-readable name.
  String get name;

  /// Handler version.
  String get version;

  /// Required capabilities/dependencies.
  List<String> get requires;

  /// Execute the handler.
  Future<TOutput> execute(TInput input, HandlerContext context);

  /// Validate input before execution.
  ValidationResult? validateInput(TInput input) => null;

  /// Cleanup resources after execution.
  Future<void> cleanup(HandlerContext context) async {}
}

/// Context for handler execution.
class HandlerContext {
  /// Run identifier.
  final String runId;

  /// Stage identifier.
  final String stageId;

  /// Pipeline identifier.
  final String pipelineId;

  /// Trace identifier.
  final String? traceId;

  /// Point in time for execution.
  final DateTime asOf;

  /// Handler configuration.
  final Map<String, dynamic> config;

  const HandlerContext({
    required this.runId,
    required this.stageId,
    required this.pipelineId,
    this.traceId,
    required this.asOf,
    this.config = const {},
  });
}

/// Validation result.
class ValidationResult {
  /// Whether validation passed.
  final bool valid;

  /// Validation errors.
  final List<String> errors;

  /// Validation warnings.
  final List<String> warnings;

  const ValidationResult({
    required this.valid,
    this.errors = const [],
    this.warnings = const [],
  });

  factory ValidationResult.valid() => const ValidationResult(valid: true);

  factory ValidationResult.invalid(List<String> errors) {
    return ValidationResult(valid: false, errors: errors);
  }
}

/// Registry for pipeline handlers.
class PipelineHandlerRegistry {
  final Map<String, PipelineHandler<dynamic, dynamic>> _handlers = {};

  /// Register a handler.
  void register(PipelineHandler<dynamic, dynamic> handler) {
    _handlers[handler.id] = handler;
  }

  /// Unregister a handler.
  void unregister(String handlerId) {
    _handlers.remove(handlerId);
  }

  /// Get handler by ID.
  PipelineHandler<dynamic, dynamic>? get(String handlerId) {
    return _handlers[handlerId];
  }

  /// Check if handler exists.
  bool has(String handlerId) {
    return _handlers.containsKey(handlerId);
  }

  /// List all registered handlers.
  List<HandlerInfo> list({HandlerFilter? filter}) {
    var handlers = _handlers.values;

    if (filter != null) {
      if (filter.namespace != null) {
        handlers = handlers.where(
          (h) => h.id.startsWith('${filter.namespace}.'),
        );
      }
    }

    return handlers.map((h) => HandlerInfo(
      id: h.id,
      name: h.name,
      version: h.version,
      namespace: h.id.split('.').first,
      requires: h.requires,
    )).toList();
  }

  /// Find handlers by pattern.
  List<PipelineHandler<dynamic, dynamic>> findByPattern(String pattern) {
    final regex = RegExp(
      pattern.replaceAll('*', '.*').replaceAll('?', '.'),
    );
    return _handlers.values
        .where((h) => regex.hasMatch(h.id))
        .toList();
  }

  /// Clear all handlers.
  void clear() {
    _handlers.clear();
  }
}

/// Handler filter criteria.
class HandlerFilter {
  /// Namespace filter.
  final String? namespace;

  /// Required capabilities filter.
  final List<String>? capabilities;

  /// Version filter.
  final String? version;

  const HandlerFilter({
    this.namespace,
    this.capabilities,
    this.version,
  });
}

/// Handler information.
class HandlerInfo {
  /// Handler identifier.
  final String id;

  /// Handler name.
  final String name;

  /// Handler version.
  final String version;

  /// Handler namespace.
  final String namespace;

  /// Required dependencies.
  final List<String> requires;

  const HandlerInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.namespace,
    this.requires = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'namespace': namespace,
        if (requires.isNotEmpty) 'requires': requires,
      };
}

/// Simple function-based handler wrapper.
class FunctionHandler<TInput, TOutput>
    implements PipelineHandler<TInput, TOutput> {
  @override
  final String id;
  @override
  final String name;
  @override
  final String version;
  @override
  final List<String> requires;

  final Future<TOutput> Function(TInput input, HandlerContext context) _fn;

  FunctionHandler({
    required this.id,
    required this.name,
    this.version = '1.0.0',
    this.requires = const [],
    required Future<TOutput> Function(TInput input, HandlerContext context) fn,
  }) : _fn = fn;

  @override
  Future<TOutput> execute(TInput input, HandlerContext context) {
    return _fn(input, context);
  }

  @override
  ValidationResult? validateInput(TInput input) => null;

  @override
  Future<void> cleanup(HandlerContext context) async {}
}
