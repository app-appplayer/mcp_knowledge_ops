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
