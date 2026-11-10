// Branches of the models and error types that the other tests do not reach.

import 'package:mcp_knowledge_ops/src/errors/ops_exception.dart';
import 'package:mcp_knowledge_ops/src/execution/handler_registry.dart'
    as registry;
import 'package:mcp_knowledge_ops/src/models/events.dart';
import 'package:mcp_knowledge_ops/src/models/execution_context.dart';
import 'package:mcp_knowledge_ops/src/models/execution_result.dart';
import 'package:mcp_knowledge_ops/src/models/stage.dart';
import 'package:test/test.dart';

class _Handler extends registry.StageHandler<String, String> {
  @override
  String get name => 'h';
  @override
  Future<String> execute(String input, registry.HandlerContext context) async =>
      input;
}

void main() {
  group('exceptions', () {
    test('gate, validation and circuit exceptions are not or are retryable',
        () {
      final gate = GateException('g',
          gateId: 'g1',
          result: GateEvaluationResult(
              passed: false, evaluatedAt: DateTime.utc(2026)));
      expect(gate.retryable, isFalse);
      expect(gate.suggestedDelay, Duration.zero);
      final v = ValidationException('v', errors: const [
        ValidationError(field: 'f', message: 'bad'),
      ]);
      expect(v.retryable, isFalse);
      expect(v.suggestedDelay, Duration.zero);
      const c = CircuitOpenException('open', circuitName: 'c1');
      expect(c.retryable, isTrue);
      expect(c.suggestedDelay, const Duration(seconds: 30));
      expect(c.toString(), contains('circuit=c1'));
    });

    test('aggregate error is retryable when any cause is', () {
      AggregateError agg(Object e) => AggregateError('a', errors: [
            ExecutionError(
                operationId: 'op', error: e, timestamp: DateTime.utc(2026)),
          ]);
      expect(agg(const CircuitOpenException('x', circuitName: 'c')).retryable,
          isTrue);
      expect(agg(StateError('plain')).retryable, isFalse);
      expect(agg(StateError('plain')).suggestedDelay, Duration.zero);
    });

    test('retry waits with growing, jittered delay and stops when told to',
        () async {
      var calls = 0;
      final seen = <Duration>[];
      final r = await RetryExecutor.execute<int>(
        operation: () async {
          calls++;
          if (calls < 3) throw StateError('again');
          return calls;
        },
        maxAttempts: 3,
        initialDelay: const Duration(milliseconds: 4),
        maxDelay: const Duration(milliseconds: 6),
        onRetry: (a, e, d) => seen.add(d),
      );
      expect(r, 3);
      expect(seen, hasLength(2));
      expect(seen.every((d) => d <= const Duration(milliseconds: 6)), isTrue);
    });

    test('fallback strategies', () async {
      Future<int> fail() async => throw StateError('x');
      expect(
          await FallbackHandler<int>(
                  strategy: FallbackStrategy.cachedValue, defaultValue: 7)
              .executeWithFallback(fail),
          7);
      expect(
          await FallbackHandler<int>(
                  strategy: FallbackStrategy.degrade, defaultValue: 8)
              .executeWithFallback(fail),
          8);
      expect(
          () => const FallbackHandler<int>(strategy: FallbackStrategy.degrade)
              .executeWithFallback(fail),
          throwsStateError);
    });
  });

  group('execution context', () {
    final config = const ExecutionConfig();
    test('copyWith replaces fields and keeps the others', () {
      final ctx = ExecutionContext(
          runId: 'r',
          traceId: 't',
          workspaceId: 'w',
          asOf: DateTime.utc(2026),
          config: config);
      final c = ctx.copyWith(
          runId: 'r2',
          userId: 'u',
          config: config.copyWith(
              dryRun: true, maxConcurrency: 3, autoApprove: true));
      expect(c.runId, 'r2');
      expect(c.userId, 'u');
      expect(c.config.dryRun, isTrue);
      expect(c.config.maxConcurrency, 3);
      expect(ctx.copyWith().runId, 'r');
      expect(config.copyWith().dryRun, config.dryRun);
    });

    test('retry config: jitter, json and copy', () {
      const rc = RetryConfig(
          initialDelay: Duration(milliseconds: 10),
          maxDelay: Duration(milliseconds: 20),
          jitterFactor: 0.5,
          retryableExceptions: ['StateError']);
      for (var i = 0; i < 20; i++) {
        final d = rc.delayForAttempt(2);
        expect(d, lessThanOrEqualTo(const Duration(milliseconds: 20)));
        expect(d, greaterThanOrEqualTo(Duration.zero));
      }
      final json = rc.toJson();
      expect(json['jitterFactor'], 0.5);
      expect(json['retryableExceptions'], ['StateError']);
      final back = RetryConfig.fromJson(json);
      expect(back.jitterFactor, 0.5);
      expect(back.retryableExceptions, ['StateError']);
      expect(RetryConfig.fromJson(const {}).maxAttempts, 3);
      final copy = rc.copyWith(maxAttempts: 9);
      expect(copy.maxAttempts, 9);
      expect(copy.maxDelay, rc.maxDelay);
      expect(rc.copyWith().jitterFactor, 0.5);
    });

    test('checkpoint json falls back to paused for an unknown state', () {
      final cp = Checkpoint.fromJson({
        'id': 'c',
        'runId': 'r',
        'name': 'n',
        'state': <String, dynamic>{},
        'stageOutputs': <String, dynamic>{},
        'executionState': 'no-such-state',
        'createdAt': DateTime.utc(2026).toIso8601String(),
      });
      expect(cp.executionState, ExecutionState.paused);
    });
  });

  group('stage and result models', () {
    test('Stage.copyWith', () {
      const s = Stage(id: 'a', name: 'A', handler: 'h');
      final c = s.copyWith(order: 2, onFailure: OnFailure.skip);
      expect(c.order, 2);
      expect(c.onFailure, OnFailure.skip);
      expect(s.copyWith().order, 0);
      expect(s.copyWith().onFailure, OnFailure.fail);
    });

    test('unknown statuses in json become pending', () {
      final r = StageResult.fromJson({
        'stageId': 's',
        'status': 'weird',
        'startedAt': DateTime.utc(2026).toIso8601String(),
      });
      expect(r.status, StageStatus.pending);
      expect(StageOutput.fromJson({'data': 1, 'status': 'weird'}).status,
          StageStatus.pending);
    });

    test('workflow error text and metrics json', () {
      final e = WorkflowError.fromException(StateError('x'), StackTrace.empty);
      expect(e.toString(), startsWith('WorkflowError(EXECUTION_ERROR)'));
      final m = const WorkflowMetrics(
          totalDuration: Duration(seconds: 1),
          stageDurations: {'a': Duration(milliseconds: 5)}).toJson();
      expect(m['stageDurations'], {'a': 5});
    });

    test('workflow started event json', () {
      final e = WorkflowStartedEvent(
          timestamp: DateTime.utc(2026), runId: 'r', workflowId: 'w');
      expect(e.toJson()['workflowId'], 'w');
      expect(e.toJson()['runId'], 'r');
    });
  });

  test('handler defaults and filter', () async {
    final h = _Handler();
    expect(h.id, 'h');
    expect(h.version, '1.0.0');
    expect(h.inputSchema, isNull);
    expect(h.outputSchema, isNull);
    expect(h.requires, isEmpty);
    expect(h.validateInput('x'), isEmpty);
    await h.cleanup();
    const f = registry.HandlerFilter(namePattern: 'a', version: '1');
    expect(f.namePattern, 'a');
    expect(f.requires, isNull);
  });
}
