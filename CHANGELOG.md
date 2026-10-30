## [0.3.0] - 2026-10-31 - Behavior action arguments filled from the run state, unique ids

### Breaking
Under the 0.x compatibility rule this makes the release a minor. Consumers on `^0.2.x` keep the old behaviour until they raise their floor.
- The behavior engine fills `${...}` in a step action's arguments from the run state before it dispatches (bundle spec 11 §11.7). It used to hand the arguments over exactly as written, so an argument that happens to contain `${...}` (for example a shell snippet) now changes; write `\${...}` to keep it literal.

### Added
- A string argument that is exactly one `${path}` takes the value at that state path with its type; any other string is rendered as text; a path with no value is `null` alone and nothing inside text. Maps and lists are walked at any depth, including a skill action's `inputs`. A step reads an earlier step's output by its id (`${fetch.score}`) or by a merged key. The action given to the dispatcher is a new object; the step definition is not changed.

### Changed (dependency floor)
- `mcp_bundle` floor raised to `^0.4.12`.

### Fixed
- Ids built from the clock alone (checkpoint, trace, span, audit, run, schedule, approval request and build ids) repeated when two records were made in the same tick, and a store replaced the earlier record without an error. They now come from one process-wide generator, `<prefix><sep><microseconds><sep><sequence>`; prefixes and separators are unchanged.

## [0.2.2] - 2026-05-30 - Behavior definition execution engine (additive)

### Added
- `lib/src/behavior/` — new module: unified behavior definition execution engine.
  - `BehaviorEngine` — runner; takes a `List<BehaviorStep>` (engine-native) plus an initial state map via `run(runId, steps, state)` and executes step-by-step, evaluating guards and routing outcomes. Engine-native types only — no `mcp_bundle` dependency (hosts map their bundle section to `BehaviorStep`).
  - `BehaviorRunnable` — per-activation handle returned by `BehaviorEngine.run`; supports `resume(runId, {statePatch})` for suspended runs (the optional `statePatch` is merged into the run state before re-evaluating the waiting guard — e.g. `{approved: true}` unblocks an approval gate).
  - `BehaviorStep` — runtime step record (id, status, result, error).
  - `Guard` — evaluates a step's `when` expression against `StateStore` entries; returns the outcome key used for `then` routing.
  - `Outcome` — registry of named outcomes (`proceed`, `skip`, `wait`, `stop`, `goto:<id>`) plus host-registered custom outcomes.
  - `StateStore` — abstract key/value store interface with two concrete implementations: `EphemeralStateStore` (in-memory, per-run) and `KvStateStore` (durable, backed by a `KvPort` for suspend/resume across restarts).
- `OpsRuntime.behaviorRegistry` — `Map<String, BehaviorRunnable Function()>` field (default empty map, additive). Hosts (brain_kernel `BundleActivation`) populate this map at bundle activation time; `bk.behavior.*` tools dispatch through it.
- Barrel export of the behavior module added to `lib/mcp_knowledge_ops.dart`.
- 17 new regression tests. Total: 1081 PASS.

### Backward compatibility
- Fully additive. `OpsRuntime.fromConsumedPorts` default for `behaviorRegistry` is `const {}`. No existing field, adapter, or execution path changed. `^0.2.1` caret consumers resolve `0.2.2` automatically.

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
