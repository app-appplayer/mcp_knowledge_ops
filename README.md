# MCP Knowledge Ops

## Support This Project

If you find this package useful, consider supporting ongoing development on PayPal.

[![Donate](https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/ncp/payment/F7G56QD9LSJ92)
Support makemind via [PayPal](https://www.paypal.com/ncp/payment/F7G56QD9LSJ92)

---

### MCP Knowledge Package Family

- [`mcp_bundle`](https://pub.dev/packages/mcp_bundle): Bundle schema, loader, validator, and expression language for MCP ecosystem.
- [`mcp_fact_graph`](https://pub.dev/packages/mcp_fact_graph): Temporal knowledge graph with evidence-based fact management and summarization.
- [`mcp_skill`](https://pub.dev/packages/mcp_skill): Skill definitions and runtime execution for AI capabilities.
- [`mcp_profile`](https://pub.dev/packages/mcp_profile): Profile definitions for AI personas with template rendering and appraisal.
- [`mcp_knowledge_ops`](https://pub.dev/packages/mcp_knowledge_ops): Knowledge operations including pipelines, workflows, and scheduling.
- [`mcp_knowledge`](https://pub.dev/packages/mcp_knowledge): Unified integration package for the complete knowledge system.

---

A powerful Dart package for knowledge operations including pipelines, workflows, scheduling, and automated knowledge processing. Part of the MakeMind MCP ecosystem.

## Features

### Core Features
- **Pipelines**: Define and execute multi-stage processing pipelines
- **Workflows**: Complex workflow orchestration with branching and conditions
- **Scheduling**: Automated job scheduling with cron-like expressions
- **Operations**: Built-in operations for curation, summarization, and pattern mining

### Pipeline Model
- **Stages**: Sequential processing stages
- **Checkpoints**: Save and restore pipeline state
- **Metrics**: Execution metrics and monitoring
- **Error Handling**: Retry logic and error recovery

### Workflow Model
- **Actions**: Discrete workflow actions
- **Conditions**: Conditional branching
- **Variables**: Workflow-scoped variables
- **Events**: Event-driven execution

### Built-in Operations
- **Curation**: Candidate review and confirmation
- **Summarization**: Entity summary generation
- **Pattern Mining**: Pattern discovery in knowledge
- **Index Refresh**: Knowledge index maintenance

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  mcp_knowledge_ops: ^0.1.0
```

### Basic Usage

```dart
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() async {
  // Create pipeline executor
  final executor = PipelineExecutor();

  // Define a curation pipeline
  final pipeline = Pipeline(
    id: 'daily_curation',
    name: 'Daily Curation',
    stages: [
      PipelineStage(
        id: 'fetch_candidates',
        type: StageType.fetch,
        config: {'status': 'pending', 'limit': 100},
      ),
      PipelineStage(
        id: 'auto_confirm',
        type: StageType.process,
        config: {'threshold': 0.95},
      ),
      PipelineStage(
        id: 'notify',
        type: StageType.output,
        config: {'channel': 'slack'},
      ),
    ],
  );

  // Execute pipeline
  final result = await executor.execute(
    pipeline,
    CurationInput(entityIds: ['user_123']),
    PipelineContext(runId: 'run_001'),
  );

  print('Success: ${result.success}');
  print('Metrics: ${result.metrics}');
}
```

## Core Concepts

### Pipelines

Pipelines define sequential processing stages:

```dart
final pipeline = Pipeline(
  id: 'summarization_pipeline',
  name: 'Entity Summarization',
  stages: [
    PipelineStage(
      id: 'fetch_facts',
      type: StageType.fetch,
      config: {'domain': 'preferences'},
    ),
    PipelineStage(
      id: 'generate_summary',
      type: StageType.process,
      config: {'model': 'claude-3-5-sonnet'},
    ),
    PipelineStage(
      id: 'store_summary',
      type: StageType.output,
      config: {'collection': 'summaries'},
    ),
  ],
  checkpointEnabled: true,
  retryPolicy: RetryPolicy(maxRetries: 3),
);
```

### Workflows

Workflows orchestrate complex multi-step processes:

```dart
final workflow = Workflow(
  id: 'onboarding_workflow',
  name: 'User Onboarding',
  actions: [
    WorkflowAction(
      id: 'extract_preferences',
      type: ActionType.skill,
      skillId: 'preference_extractor',
    ),
    WorkflowAction(
      id: 'check_premium',
      type: ActionType.condition,
      condition: '{{user.isPremium}}',
      onTrue: 'premium_setup',
      onFalse: 'basic_setup',
    ),
    WorkflowAction(
      id: 'premium_setup',
      type: ActionType.skill,
      skillId: 'premium_onboarding',
    ),
    WorkflowAction(
      id: 'basic_setup',
      type: ActionType.skill,
      skillId: 'basic_onboarding',
    ),
  ],
);

// Execute workflow
final workflowExecutor = WorkflowExecutor(handlers: handlers);
final execution = await workflowExecutor.execute(
  workflow,
  {'user': userContext},
);
```

### Scheduling

Schedule automated jobs:

```dart
final scheduler = Scheduler(
  config: SchedulerConfig(
    timezone: 'UTC',
    maxConcurrentJobs: 5,
  ),
);

// Schedule daily curation
await scheduler.schedule(
  ScheduledJob(
    id: 'daily_curation',
    name: 'Daily Candidate Curation',
    schedule: CronSchedule('0 6 * * *'), // 6 AM daily
    pipeline: curationPipeline,
    input: CurationInput(),
  ),
);

// Schedule hourly summarization
await scheduler.schedule(
  ScheduledJob(
    id: 'hourly_summary',
    name: 'Hourly Summary Refresh',
    schedule: CronSchedule('0 * * * *'), // Every hour
    pipeline: summarizationPipeline,
    input: SummarizationInput(staleOnly: true),
  ),
);

// Start scheduler
await scheduler.start();
```

### Built-in Operations

#### Curation
```dart
final curationPipeline = CurationPipeline(
  factGraph: factGraphPort,
);

final result = await executor.execute(
  curationPipeline,
  CurationInput(
    entityIds: ['user_123', 'user_456'],
    autoConfirmThreshold: 0.95,
  ),
  context,
);

print('Confirmed: ${result.output.confirmedCount}');
print('Rejected: ${result.output.rejectedCount}');
```

#### Summarization
```dart
final summarizationPipeline = SummarizationPipeline(
  factGraph: factGraphPort,
  llm: llmPort,
);

final result = await executor.execute(
  summarizationPipeline,
  SummarizationInput(
    entityIds: ['user_123'],
    summaryTypes: ['preferences', 'history'],
  ),
  context,
);

print('Updated: ${result.output.updatedSummaries}');
```

#### Pattern Mining
```dart
final patternPipeline = PatternMiningPipeline(
  factGraph: factGraphPort,
  llm: llmPort,
);

final result = await executor.execute(
  patternPipeline,
  PatternMiningInput(
    domain: 'preferences',
    minSupport: 0.1,
  ),
  context,
);

print('Patterns: ${result.output.patterns}');
```

## Port-Based Architecture

The package uses a port-based dependency injection pattern:

```dart
// Define custom operation port
class MyOpsPort implements OpsPort {
  @override
  Future<void> executeOperation(Operation op) async {
    // Your implementation
  }
}

// Use custom ports
final executor = PipelineExecutor(
  opsPort: MyOpsPort(),
);
```

## API Reference

### PipelineExecutor

| Method | Description |
|--------|-------------|
| `execute(pipeline, input, context)` | Execute a pipeline |
| `pause(runId)` | Pause pipeline execution |
| `resume(runId)` | Resume paused pipeline |
| `cancel(runId)` | Cancel pipeline |

### WorkflowExecutor

| Method | Description |
|--------|-------------|
| `execute(workflow, context)` | Execute a workflow |
| `getExecution(id)` | Get execution status |
| `listExecutions(filter)` | List executions |

### Scheduler

| Method | Description |
|--------|-------------|
| `schedule(job)` | Schedule a job |
| `unschedule(jobId)` | Remove a job |
| `start()` | Start scheduler |
| `stop()` | Stop scheduler |

## Examples

### Complete Examples Available
- `example/basic_pipeline.dart` - Basic pipeline execution
- `example/workflow.dart` - Workflow orchestration
- `example/scheduling.dart` - Job scheduling
- `example/curation.dart` - Curation pipeline
- `example/summarization.dart` - Summarization pipeline

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## Support

- [Documentation](https://github.com/app-appplayer/mcp_knowledge_ops/wiki)
- [Issue Tracker](https://github.com/app-appplayer/mcp_knowledge_ops/issues)
- [Discussions](https://github.com/app-appplayer/mcp_knowledge_ops/discussions)
- [Support on Patreon](https://www.patreon.com/mcpdevstudio)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
