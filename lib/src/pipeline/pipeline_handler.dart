/// Pipeline Handler - Handler interface and registry.
///
/// Defines the handler interface and registry for pipeline stage execution.
library;

import '../execution/handler_registry.dart' show HandlerContext;

/// Re-export HandlerContext for consumers of this file.
export '../execution/handler_registry.dart' show HandlerContext;

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

  /// JSON Schema describing the expected input format.
  Map<String, dynamic> get inputSchema;

  /// JSON Schema describing the output format.
  Map<String, dynamic> get outputSchema;

  /// Execute the handler.
  Future<TOutput> execute(TInput input, HandlerContext context);

  /// Validate input before execution.
  ValidationResult? validateInput(TInput input) => null;

  /// Cleanup resources after execution.
  Future<void> cleanup(HandlerContext context) async {}
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

    return handlers
        .map((h) => HandlerInfo(
              id: h.id,
              name: h.name,
              version: h.version,
              namespace: h.id.split('.').first,
              requires: h.requires,
              inputSchema: h.inputSchema,
              outputSchema: h.outputSchema,
            ))
        .toList();
  }

  /// Validate that a handler exists and optionally check required fields.
  ValidationResult validate(String handlerId, {List<String>? required}) {
    final handler = _handlers[handlerId];
    if (handler == null) {
      return ValidationResult.invalid(
        ['Handler not found: $handlerId'],
      );
    }

    if (required != null && required.isNotEmpty) {
      final errors = <String>[];
      final schema = handler.inputSchema;
      final schemaProperties = schema['properties'] as Map<String, dynamic>?;
      for (final field in required) {
        if (schemaProperties == null || !schemaProperties.containsKey(field)) {
          errors.add(
              'Required field "$field" not found in input schema for $handlerId');
        }
      }
      if (errors.isNotEmpty) {
        return ValidationResult.invalid(errors);
      }
    }

    return ValidationResult.valid();
  }

  /// Find handlers by pattern.
  List<PipelineHandler<dynamic, dynamic>> findByPattern(String pattern) {
    final regex = RegExp(
      pattern.replaceAll('*', '.*').replaceAll('?', '.'),
    );
    return _handlers.values.where((h) => regex.hasMatch(h.id)).toList();
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

  /// JSON Schema describing the expected input format.
  final Map<String, dynamic> inputSchema;

  /// JSON Schema describing the output format.
  final Map<String, dynamic> outputSchema;

  const HandlerInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.namespace,
    this.requires = const [],
    this.inputSchema = const {},
    this.outputSchema = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'namespace': namespace,
        if (requires.isNotEmpty) 'requires': requires,
        if (inputSchema.isNotEmpty) 'inputSchema': inputSchema,
        if (outputSchema.isNotEmpty) 'outputSchema': outputSchema,
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
  @override
  final Map<String, dynamic> inputSchema;
  @override
  final Map<String, dynamic> outputSchema;

  final Future<TOutput> Function(TInput input, HandlerContext context) _fn;

  FunctionHandler({
    required this.id,
    required this.name,
    this.version = '1.0.0',
    this.requires = const [],
    this.inputSchema = const {},
    this.outputSchema = const {},
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
