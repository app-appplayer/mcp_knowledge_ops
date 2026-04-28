# MCP Knowledge Ops

> **Positioning:** `mcp_knowledge_ops` is an internal component of the MakeMind knowledge stack exposed through the `mcp_knowledge` facade. Application code should import `package:mcp_knowledge/mcp_knowledge.dart` — the symbols declared here are re-exported from there. Direct `package:mcp_knowledge_ops/` imports remain valid for advanced or integration scenarios but are discouraged in product code.

A stateless orchestration layer for MakeMind. Coordinates pipelines, workflows, scheduling, runbooks, and observability across the ecosystem; persistence is delegated to `mcp_fact_graph`.

## Components

- **Execution Engine** — central coordinator for pipeline / workflow runs.
- **Pipelines** — staged data processing with gates and metrics. Built-in pipelines: curation, summary refresh, pattern mining, ingest, index rebuild, cascade refresh, clustering.
- **Workflows** — long-running build/release flows with reviews, approval routing, and cancellation.
- **Scheduler** — cron / event / deadline triggers, MCP tools integration, scheduler events.
- **Runbooks** — operational procedures.
- **Observability** — logging, metrics, tracing, structured events.
- **Standard port adapters** — implements `mcp_bundle` ops Contract Layer (workflow / pipeline / runbook / runs / schedule trigger / audit).

## Quick Start

```dart
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

final handlers = HandlerRegistry();
handlers.register('myHandler', MyHandler());

final engine = ExecutionEngine(
  config: ExecutionEngineConfig(),
  handlers: handlers,
);

final result = await engine.executePipeline(pipeline, input, context);
```

## Support

- [Issue Tracker](https://github.com/app-appplayer/mcp_knowledge_ops/issues)
- [Discussions](https://github.com/app-appplayer/mcp_knowledge_ops/discussions)

## License

MIT — see [LICENSE](LICENSE).
