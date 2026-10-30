/// Pipeline Port Adapter - Implements `PipelinePort` over the package's
/// internal pipeline registry.
///
/// See REDESIGN-PLAN.md Phase 7 §3.1 and docs/03_DDD/core-runtime.md §3.2.
library;

import 'package:mcp_bundle/src/ports/pipeline_port.dart';

import '../pipeline/pipeline.dart';
import '../id_generator.dart';

/// Decoder from a map input to a pipeline's typed `TInput`.
typedef PipelineInputDecoder = dynamic Function(Map<String, dynamic> input);

/// Factory for building a concrete pipeline on demand.
typedef PipelineFactory = Pipeline<dynamic, dynamic> Function();

/// Adapter exposing internal pipelines via the standard [PipelinePort]
/// contract.
class PipelinePortAdapter implements PipelinePort {
  /// Pipeline id → factory.
  final Map<String, PipelineFactory> registry;

  /// Pipeline id → map-to-typed-input decoder.
  final Map<String, PipelineInputDecoder> decoders;

  /// Run id → completed handle.
  final Map<String, PipelineRunHandle> _runs = {};

  PipelinePortAdapter({
    required this.registry,
    this.decoders = const {},
  });

  @override
  Future<PipelineRunHandle> runPipeline(
    String id,
    Map<String, dynamic> input,
  ) async {
    final factory = registry[id];
    final startedAt = DateTime.now();
    final runId = generateId('pipe', separator: '-');

    if (factory == null) {
      final handle = PipelineRunHandle(
        runId: runId,
        pipelineId: id,
        status: 'failed',
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        error: 'Unknown pipeline: $id',
      );
      _runs[runId] = handle;
      return handle;
    }

    try {
      final pipeline = factory();
      final decoded = decoders[id]?.call(input) ?? input;
      final ctx = PipelineContext(
        runId: runId,
        workspaceId: (input['workspaceId'] as String?) ?? 'default',
        asOf: startedAt,
        config: pipeline.config,
      );

      final result = await pipeline.run(decoded, ctx);

      final handle = PipelineRunHandle(
        runId: runId,
        pipelineId: id,
        status: result.success ? 'succeeded' : 'failed',
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        output: _toMap(result.output),
        error: result.error?.message,
      );
      _runs[runId] = handle;
      return handle;
    } catch (e) {
      final handle = PipelineRunHandle(
        runId: runId,
        pipelineId: id,
        status: 'failed',
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        error: e.toString(),
      );
      _runs[runId] = handle;
      return handle;
    }
  }

  @override
  Future<PipelineRunHandle?> getPipelineRun(String runId) async =>
      _runs[runId];

  Map<String, dynamic>? _toMap(Object? value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    try {
      final dyn = value as dynamic;
      final result = dyn.toJson();
      if (result is Map<String, dynamic>) return result;
    } catch (_) {
      // fall through
    }
    return {'value': value.toString()};
  }
}
