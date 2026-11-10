/// Execution - Exports for execution engine components.
///
/// Provides execution engine, stage executor, gate evaluator, checkpoint management,
/// parallel execution with concurrency control, and execution state machine.
library;

export 'execution_engine.dart';
export 'execution_state_machine.dart';
export 'stage_executor.dart';
export 'gate_evaluator.dart';
export 'checkpoint_manager.dart';
export 'handler_registry.dart';
export 'parallel_executor.dart'
    show ParallelExecutionException, ParallelStageExecutor;
export 'circuit_breaker.dart';
