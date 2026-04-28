/// Cascade Refresh Executor - Topological refresh of dependent summaries.
///
/// Implements the cascade refresh algorithm from the pipelines spec
/// section 5.1 using Kahn's algorithm for topological sorting with
/// cycle detection.
library;

/// Request parameters for a cascade refresh execution.
class CascadeRefreshRequest {
  /// Dependency graph: node ID -> list of node IDs it depends on.
  final Map<String, List<String>> dependencies;

  /// Optional execution options (parallelism, stop-on-error, etc.).
  final Map<String, dynamic>? options;

  const CascadeRefreshRequest({
    required this.dependencies,
    this.options,
  });
}

/// Result of a cascade refresh execution.
class CascadeRefreshResult {
  /// Per-node refresh results keyed by node ID.
  final Map<String, RefreshResult> results;

  const CascadeRefreshResult({required this.results});

  /// Number of successfully refreshed nodes.
  int get refreshedCount =>
      results.values.where((r) => r.success).length;

  /// Number of failed nodes.
  int get failedCount =>
      results.values.where((r) => !r.success).length;
}

/// Result of refreshing a single node.
class RefreshResult {
  /// Identifier of the refreshed node.
  final String nodeId;

  /// Whether the refresh succeeded.
  final bool success;

  /// Error message if the refresh failed.
  final String? error;

  const RefreshResult({
    required this.nodeId,
    required this.success,
    this.error,
  });
}

/// Cascade refresh executor using topological sort (Kahn's algorithm)
/// for determining refresh order of dependent summaries.
///
/// Per spec section 5.1, when a summary is refreshed, all dependent
/// summaries must also be refreshed in the correct dependency order.
class CascadeRefreshExecutor {
  /// Build dependency graph and execute refresh in topological order.
  ///
  /// Uses Kahn's algorithm for topological sorting with cycle detection.
  /// Nodes at the same dependency level are refreshed in parallel batches.
  Future<CascadeRefreshResult> execute(CascadeRefreshRequest request) async {
    final order = topologicalSort(request.dependencies);

    // Execute in batches based on dependency levels
    final batches = _buildBatches(order, request.dependencies);
    final results = <String, RefreshResult>{};

    for (final batch in batches) {
      // Parallel execution within each batch
      final batchResults = await Future.wait(
        batch.map((nodeId) => _refreshNode(nodeId, request)),
      );
      for (var i = 0; i < batch.length; i++) {
        results[batch[i]] = batchResults[i];
      }
    }

    return CascadeRefreshResult(results: results);
  }

  /// Kahn's algorithm for topological sorting.
  ///
  /// Returns nodes in dependency order (dependencies first).
  /// Throws [StateError] if a cycle is detected in the dependency graph.
  List<String> topologicalSort(Map<String, List<String>> dependencies) {
    final inDegree = <String, int>{};
    final adjacency = <String, List<String>>{};

    // Initialize all nodes
    for (final node in dependencies.keys) {
      inDegree.putIfAbsent(node, () => 0);
      adjacency.putIfAbsent(node, () => []);

      for (final dep in dependencies[node]!) {
        adjacency.putIfAbsent(dep, () => []);
        adjacency[dep]!.add(node);
        inDegree.putIfAbsent(dep, () => 0);
        inDegree[node] = (inDegree[node] ?? 0) + 1;
      }
    }

    // Start with nodes that have no dependencies (in-degree 0)
    final queue = <String>[
      ...inDegree.entries
          .where((e) => e.value == 0)
          .map((e) => e.key),
    ];
    final result = <String>[];

    while (queue.isNotEmpty) {
      final node = queue.removeAt(0);
      result.add(node);

      for (final neighbor in adjacency[node]!) {
        inDegree[neighbor] = inDegree[neighbor]! - 1;
        if (inDegree[neighbor] == 0) {
          queue.add(neighbor);
        }
      }
    }

    if (result.length != inDegree.length) {
      throw StateError('Cycle detected in dependency graph');
    }

    return result;
  }

  /// Group nodes into batches by dependency level.
  ///
  /// Nodes within the same batch have no mutual dependencies and
  /// can be refreshed in parallel.
  List<List<String>> _buildBatches(
    List<String> order,
    Map<String, List<String>> dependencies,
  ) {
    final levels = <String, int>{};

    for (final node in order) {
      final deps = dependencies[node] ?? [];
      if (deps.isEmpty) {
        levels[node] = 0;
      } else {
        levels[node] = deps
            .map((d) => (levels[d] ?? 0) + 1)
            .reduce((a, b) => a > b ? a : b);
      }
    }

    final maxLevel = levels.values.isEmpty
        ? 0
        : levels.values.reduce((a, b) => a > b ? a : b);

    final batches = <List<String>>[];
    for (var i = 0; i <= maxLevel; i++) {
      batches.add(
        levels.entries
            .where((e) => e.value == i)
            .map((e) => e.key)
            .toList(),
      );
    }

    return batches;
  }

  /// Refresh a single node.
  ///
  /// Override this method to provide actual refresh logic via
  /// ExecutionEngine or a registered handler that calls
  /// `FactsPort.writeFacts`.
  Future<RefreshResult> _refreshNode(
    String nodeId,
    CascadeRefreshRequest request,
  ) async {
    // Placeholder for actual refresh logic via ExecutionEngine
    return RefreshResult(nodeId: nodeId, success: true);
  }
}
