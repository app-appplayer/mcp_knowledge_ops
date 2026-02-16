/// MCP Knowledge Operations - Orchestration layer for MakeMind.
///
/// This library provides orchestration operations for MCP applications,
/// including pipelines, workflows, scheduling, and integration with
/// fact graphs, skills, profiles, and bundles.
library mcp_knowledge_ops;

// Pipeline infrastructure
export 'src/pipeline/pipeline.dart';
export 'src/pipeline/pipeline_executor.dart';
export 'src/pipeline/pipeline_handler.dart';

// Concrete pipelines
export 'src/pipeline/pipelines/curation_pipeline.dart';
export 'src/pipeline/pipelines/summarization_pipeline.dart';
export 'src/pipeline/pipelines/pattern_mining_pipeline.dart';

// Workflow infrastructure
export 'src/workflow/workflow.dart';
export 'src/workflow/workflow_executor.dart';

// Scheduler
export 'src/scheduler/scheduler.dart';

// Ports for dependencies
export 'src/ports/ops_port.dart';

// Document and indexing (RAG utilities)
export 'src/document/document.dart';
export 'src/document/chunk.dart';
export 'src/index/knowledge_index.dart';
export 'src/index/index_entry.dart';
export 'src/search/search_query.dart';
export 'src/search/search_result.dart';
export 'src/retrieval/retriever.dart';
export 'src/retrieval/context_builder.dart';
export 'src/embedding/embedding.dart';
export 'src/extraction/knowledge_extractor.dart';
