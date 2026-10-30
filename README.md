# MCP Knowledge Ops

> **Positioning:** `mcp_knowledge_ops` is an internal component of the MakeMind knowledge stack exposed through the `mcp_knowledge` facade. Application code should import `package:mcp_knowledge/mcp_knowledge.dart` — the symbols declared here are re-exported from there. Direct `package:mcp_knowledge_ops/` imports remain valid for advanced or integration scenarios but are discouraged in product code.

A stateless orchestration layer for MakeMind. Coordinates pipelines, workflows, scheduling, runbooks, and observability across the ecosystem; persistence is delegated to `mcp_fact_graph`.

## Components

- **Execution Engine** — runs pipeline / workflow definitions: stages with retry and failure policies, gates, checkpoints with resume, review / approval stages through the `ApprovalPort`, parallel execution.
- **Pipelines and workflows** — declarative specifications (ingest, curation, summary refresh, pattern mining, index rebuild; skill, profile and bundle build); their `run()` is a placeholder, the host builds engine definitions and registers the stage handlers.
- **Scheduler** — cron (`*` or exact numbers per field), event, deadline, manual and composite triggers with timeout, concurrency and de-duplication.
- **Runbooks** — operational procedures with variables, checks and approvals.
- **Behavior engine** — guard / outcome based step runner with suspend and resume.
- **Events, observability** — event toolkit (publisher, subscriber, router, store, replay, dead letters, reliability) and logging, metrics, tracing, audit, alerts, health checks as independent tools.
- **Standard port adapters** — `OpsRuntime` provides `WorkflowPort`, `PipelinePort`, `ScheduleTriggerPort`, `AuditPort` and `RunbookPort` from the `mcp_bundle` contract layer.

## Quick Start

```dart
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

// 1. Run a definition on the engine.
final handlers = HandlerRegistry()
  ..register('myHandler', MyHandler());

final engine = ExecutionEngine(
  config: const ExecutionEngineConfig(),
  handlers: handlers,
);

final result = await engine.executePipeline(definition, input, context);

// 2. Or assemble the whole runtime from your ports. The built-in pipelines
// are specifications: runPipeline calls their placeholder run(), so use the
// runtime's engine with your own definition to execute stages.
final runtime = OpsRuntime.fromConsumedPorts(consumedPorts);
runtime.handlers.register('myHandler', MyHandler());
final result2 = await runtime.engine.executePipeline(definition, input, context);
```

See `docs/` for the requirements, design, test lists and operations guides.

## Support

- [Issue Tracker](https://github.com/app-appplayer/mcp_knowledge_ops/issues)
- [Discussions](https://github.com/app-appplayer/mcp_knowledge_ops/discussions)

## License

MIT — see [LICENSE](LICENSE).
