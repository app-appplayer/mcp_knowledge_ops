## [0.2.1] - 2026-05-23 - mcp_bundle 0.4.0 cascade

### Changed (cascade)
- `mcp_bundle` caret bumped from `^0.3.0` to `^0.4.0`. mcp_knowledge_ops does not touch `UiSection.pages` directly, so this release is a caret-only cascade. Consumers should bump to `^0.2.1`.

## [0.2.0] - 2026-04-28 - Stateless Orchestration & New Pipelines

### Added
- Central `ExecutionEngine` coordinating pipeline and workflow runs.
- New built-in pipelines — ingest, summary refresh, index rebuild, cascade refresh, clustering — alongside existing curation and pattern mining.
- Workflow subsystem — review models, approval routing, cancellation.
- Scheduler — MCP tools integration, scheduler events.
- Runbooks subsystem.
- Observability layer — events, errors, structured logging / metrics / tracing.
- Standard port adapters implementing `mcp_bundle` ops Contract Layer.

### Changed
- Persistence delegated to `mcp_fact_graph`; `mcp_knowledge_ops` is now a stateless orchestration layer.
- Pipeline / workflow infrastructure restructured around the new execution engine.
- New dependency: `mcp_bundle ^0.3.0`.

### Removed
- Document, embedding, extraction, index, retrieval, search subsystems — now owned by `mcp_fact_graph` or replaced by Contract Layer ports.
- Standalone summarization pipeline (replaced by summary refresh pipeline).

---

## [0.1.1] - Bugfix

### Fixed
- Removed duplicate OpsLlmPort, OpsLlmRequest, LlmCompletion definitions
- Unified LLM Port types to use mcp_bundle Contract Layer exclusively
- Updated pipeline classes to use LlmPort instead of OpsLlmPort
- Fixed documentation examples to use correct LlmResponse.content field

---

## [0.1.0] - Initial Release

### Added

#### Core Features
- **Pipeline System**
  - `Pipeline` model with sequential stages
  - `PipelineStage` for individual processing steps
  - `PipelineExecutor` for pipeline execution
  - `PipelineResult` with metrics and output
  - Checkpoint support for state persistence
  - Retry policies for error recovery

- **Workflow System**
  - `Workflow` model for complex orchestration
  - `WorkflowAction` for discrete steps
  - `WorkflowExecutor` for workflow execution
  - Conditional branching support
  - Variable scoping and passing
  - Event-driven execution

- **Scheduling System**
  - `Scheduler` for automated job execution
  - `ScheduledJob` for job definitions
  - `CronSchedule` for cron-like expressions
  - Concurrent job limiting
  - Timezone support

- **Built-in Operations**
  - `CurationPipeline` for candidate curation
  - `SummarizationPipeline` for summary generation
  - `PatternMiningPipeline` for pattern discovery
  - Configurable thresholds and parameters

- **Port-Based Architecture**
  - `OpsPort` for operation execution
  - `FactGraphPort` for fact graph access
  - `LlmPort` for LLM integration

### Pipeline Features
- Sequential stage execution
- Checkpoint save/restore
- Metrics collection
- Error handling and retry
- Timeout management

### Workflow Features
- Action sequencing
- Conditional branching
- Variable interpolation
- Parallel execution
- Error recovery

### Scheduling Features
- Cron expression support
- One-time and recurring jobs
- Job dependencies
- Execution history

### Data Models
- `Pipeline` - Pipeline definition
- `PipelineStage` - Pipeline stage
- `PipelineResult` - Execution result
- `PipelineContext` - Execution context
- `Workflow` - Workflow definition
- `WorkflowAction` - Workflow action
- `WorkflowExecution` - Execution state
- `ScheduledJob` - Job definition
- `CurationInput/Output` - Curation I/O
- `SummarizationInput/Output` - Summarization I/O
- `PatternMiningInput/Output` - Pattern mining I/O

---

## Support and Contributing

- [Report Issues](https://github.com/app-appplayer/mcp_knowledge_ops/issues)
- [Join Discussions](https://github.com/app-appplayer/mcp_knowledge_ops/discussions)
- [Read Documentation](https://github.com/app-appplayer/mcp_knowledge_ops/wiki)
- [Support Development](https://www.patreon.com/mcpdevstudio)
