// A cascade refresh: when a summary changes, the summaries that depend on it
// are refreshed in dependency order by the host's refresher.

import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

Future<void> main() async {
  final refreshed = <String>[];
  final executor = CascadeRefreshExecutor(
    refresher: (nodeId) async => refreshed.add(nodeId),
  );

  // weekly depends on daily, monthly depends on weekly.
  final result = await executor.execute(const CascadeRefreshRequest(
    dependencies: {
      'daily': [],
      'weekly': ['daily'],
      'monthly': ['weekly'],
    },
  ));

  print('refreshed in order: $refreshed');
  print('${result.refreshedCount} refreshed, ${result.failedCount} failed');
}
