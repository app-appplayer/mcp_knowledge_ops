// The last uncovered branches.

import 'dart:async';

import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart' hide RetryPolicy;
import 'package:mcp_knowledge_ops/src/pipeline/pipeline_handler.dart' as ph;
import 'package:test/test.dart';

import 'test_helpers.dart';

class _BaseHandler extends ph.PipelineHandler<String, String> {
  @override
  String get id => 'h';
  @override
  String get name => 'h';
  @override
  String get version => '1';
  @override
  List<String> get requires => const [];
  @override
  Map<String, dynamic> get inputSchema => const {};
  @override
  Map<String, dynamic> get outputSchema => const {};
  @override
  Future<String> execute(String input, HandlerContext context) async => input;
}

void main() {
  test('rollback config keeps its enabled flag when only another field changes',
      () {
    const c = RollbackConfig(enabled: false);
    expect(c.copyWith(autoRollback: true).enabled, isFalse);
  });

  test('a composite trigger reports its type', () {
    expect(
        CompositeTrigger(
                operator: CompositeOperator.or, triggers: const [], id: 'c')
            .type,
        TriggerType.composite);
  });

  test('a handler without overrides validates nothing and cleans nothing',
      () async {
    final h = _BaseHandler();
    expect(h.validateInput('x'), isNull);
    await h.cleanup(HandlerContext(
        runId: 'r', stageId: 's', traceId: 't', asOf: DateTime.utc(2026)));
  });

  test('a scheduled task runs the adapter action with its target', () async {
    final calls = <Map<String, dynamic>>[];
    final scheduler = Scheduler();
    final adapter = ScheduleTriggerPortAdapter(
        scheduler: scheduler, action: (d) async => calls.add(d));
    final id = await adapter.schedule('* * * * *',
        const ScheduleTarget(kind: 'pipeline', id: 'p', parameters: {'x': 1}));
    await scheduler.triggerManually(id, data: {'when': 'now'});
    expect(calls.single['kind'], 'pipeline');
    expect(calls.single['parameters'], {'x': 1});
    expect(calls.single['event'], {'when': 'now'});
  });

  test(
      'a half-open circuit closes after enough successes and re-opens on a failure',
      () async {
    CircuitBreaker make() => CircuitBreaker(
        'c',
        const CircuitBreakerConfig(
            failureThreshold: 1,
            resetTimeout: Duration(milliseconds: 5),
            successThreshold: 1,
            halfOpenMaxRequests: 2));
    final closing = make();
    await expectLater(closing.execute<int>(() async => throw StateError('x')),
        throwsStateError);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(await closing.execute(() async => 1), 1);
    expect(closing.state, CircuitState.closed);

    final reopening = make();
    await expectLater(reopening.execute<int>(() async => throw StateError('x')),
        throwsStateError);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await expectLater(reopening.execute<int>(() async => throw StateError('y')),
        throwsStateError);
    expect(reopening.state, CircuitState.open);
  });

  test('replay records a handler that throws as failed', () async {
    final kv = MockKvStorage();
    final persister = EventPersister(kvStorage: kv);
    final router = EventRouter(logger: testLogger().$1);
    await persister.persist(
        EventStreams.execution('x'), testOpsEvent(eventType: 't'));
    final replayer = EventReplayer(
        kvStorage: kv,
        router: _ThrowingRouter(router),
        logger: testLogger().$1);
    final r = await replayer.replayExecution('x');
    expect(r.results.single.isFailed, isTrue);
    expect(r.results.single.error, contains('route failed'));
  });
}

class _ThrowingRouter implements EventRouter {
  _ThrowingRouter(this._inner);
  final EventRouter _inner;
  @override
  Future<int> route(OpsEvent event) async => throw StateError('route failed');
  @override
  dynamic noSuchMethod(Invocation i) =>
      Function.apply((_inner as dynamic).noSuchMethod, [i]);
}
