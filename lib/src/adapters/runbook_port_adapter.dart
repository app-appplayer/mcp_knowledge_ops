/// Runbook Port Adapter - Implements `RunbookPort` over the internal
/// [RunbookExecutor].
///
/// See REDESIGN-PLAN.md Phase 7 §3.1 and docs/03_DDD/core-runtime.md §3.5.
library;

import 'package:mcp_bundle/src/ports/runbook_port.dart' as port;

import '../runbooks/runbook.dart';
import '../runbooks/runbook_executor.dart';

/// Adapter wrapping a [RunbookExecutor] and a runbook registry to expose
/// the standard [port.RunbookPort] contract.
///
/// Note: the internal `Runbook` type in `runbooks/runbook.dart` has the
/// same name as a concept in `mcp_bundle`, but the bundle does not export
/// a conflicting `Runbook` class. The bundle's `RunbookExecution` and
/// `RunbookDescriptor` types, however, clash with the internal
/// `RunbookExecution` type (see `runbooks/runbook.dart`), so the bundle
/// types are imported under the `port` prefix.
class RunbookPortAdapter implements port.RunbookPort {
  /// The underlying executor.
  final RunbookExecutor executor;

  /// Runbook id → runbook factory. Factories are used instead of static
  /// instances so that each invocation gets a fresh configuration.
  final Map<String, Runbook Function()> registry;

  RunbookPortAdapter({
    required this.executor,
    required this.registry,
  });

  @override
  Future<port.RunbookExecution> runRunbook(
    String id,
    Map<String, dynamic> input,
  ) async {
    final factory = registry[id];
    final startedAt = DateTime.now();
    final executionId = 'rb-${startedAt.microsecondsSinceEpoch}';

    if (factory == null) {
      return port.RunbookExecution(
        executionId: executionId,
        runbookId: id,
        status: 'failed',
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        error: 'Unknown runbook: $id',
      );
    }

    try {
      final runbook = factory();
      final ctx = RunbookContext(
        runId: executionId,
        workspaceId: (input['workspaceId'] as String?) ?? 'default',
      );

      final result = await executor.execute(runbook, input, ctx);

      return port.RunbookExecution(
        executionId: executionId,
        runbookId: id,
        status: result.success ? 'succeeded' : 'failed',
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        output: result.output,
        error: result.error?.message,
      );
    } catch (e) {
      return port.RunbookExecution(
        executionId: executionId,
        runbookId: id,
        status: 'failed',
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        error: e.toString(),
      );
    }
  }

  @override
  Future<List<port.RunbookDescriptor>> listRunbooks() async {
    return registry.entries.map((e) {
      final r = e.value();
      return port.RunbookDescriptor(
        id: r.id,
        name: r.name,
        description: r.description.isEmpty ? null : r.description,
        tags: r.tags,
      );
    }).toList(growable: false);
  }
}
