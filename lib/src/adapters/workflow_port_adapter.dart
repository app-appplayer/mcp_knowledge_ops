/// Workflow Port Adapter - Implements `WorkflowPort` over the package's
/// internal workflow registry.
///
/// See REDESIGN-PLAN.md Phase 7 §3.1 and docs/03_DDD/core-runtime.md §3.1.
library;

import 'package:mcp_bundle/src/ports/workflow_port.dart';

import '../workflow/workflow.dart';
import '../id_generator.dart';

/// Decoder from a map input to a workflow's typed `TInput`.
typedef WorkflowInputDecoder = dynamic Function(Map<String, dynamic> input);

/// Factory for building a concrete workflow on demand.
typedef WorkflowFactory = Workflow<dynamic, dynamic> Function();

/// Adapter exposing internal workflows via the standard [WorkflowPort]
/// contract.
class WorkflowPortAdapter implements WorkflowPort {
  /// Workflow id → factory.
  final Map<String, WorkflowFactory> registry;

  /// Workflow id → map-to-typed-input decoder. Optional — when absent, the
  /// raw map is passed through.
  final Map<String, WorkflowInputDecoder> decoders;

  /// Run id → completed handle (for [getRun] lookups).
  final Map<String, WorkflowRunHandle> _runs = {};

  WorkflowPortAdapter({
    required this.registry,
    this.decoders = const {},
  });

  @override
  Future<WorkflowRunHandle> runWorkflow(
    String id,
    Map<String, dynamic> input,
  ) async {
    final factory = registry[id];
    final startedAt = DateTime.now();
    final runId = generateId('wf', separator: '-');

    if (factory == null) {
      final handle = WorkflowRunHandle(
        runId: runId,
        workflowId: id,
        status: 'failed',
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        error: 'Unknown workflow: $id',
      );
      _runs[runId] = handle;
      return handle;
    }

    try {
      final workflow = factory();
      final decoded = decoders[id]?.call(input) ?? input;
      final ctx = WorkflowContext(
        runId: runId,
        workspaceId: (input['workspaceId'] as String?) ?? 'default',
        userId: (input['userId'] as String?) ?? 'system',
        asOf: startedAt,
        config: workflow.config,
      );

      final result = await workflow.run(decoded, ctx);

      final handle = WorkflowRunHandle(
        runId: runId,
        workflowId: id,
        status: result.success ? 'succeeded' : 'failed',
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        output: _toMap(result.output),
        error: result.error?.message,
      );
      _runs[runId] = handle;
      return handle;
    } catch (e) {
      final handle = WorkflowRunHandle(
        runId: runId,
        workflowId: id,
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
  Future<WorkflowRunHandle?> getRun(String runId) async => _runs[runId];

  @override
  Future<List<WorkflowDescriptor>> listWorkflows() async {
    return registry.entries.map((e) {
      final w = e.value();
      return WorkflowDescriptor(
        id: w.id,
        name: w.name,
        version: w.version,
        description: w.description,
      );
    }).toList(growable: false);
  }

  /// Serialize an arbitrary workflow output into a map payload for the
  /// [WorkflowRunHandle.output] field.
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
