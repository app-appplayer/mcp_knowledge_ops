// The standalone pipeline executor, pipeline models, handler registry and the
// handler adapters.

import 'package:mcp_bundle/mcp_bundle.dart' as mb;
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart' hide FunctionHandler;
import 'package:mcp_knowledge_ops/src/pipeline/pipeline_executor.dart' as pe;
import 'package:mcp_knowledge_ops/src/pipeline/pipeline_handler.dart' as ph;
import 'package:test/test.dart';

import 'test_helpers.dart';

class _Pipe extends Pipeline<dynamic, dynamic> {
  _Pipe(this.stages, {this.config = const PipelineConfig()});
  @override
  final List<PipelineStage> stages;
  @override
  final PipelineConfig config;
  @override
  String get id => 'pipe';
  @override
  String get name => 'pipe';
  @override
  String get version => '1';
  @override
  String? get description => null;
  @override
  Future<PipelineResult<dynamic>> run(dynamic input, PipelineContext context) =>
      throw UnimplementedError();
}

class _Events implements pe.PipelineEventListener {
  final types = <String>[];
  @override
  void onEvent(pe.PipelineEvent event) => types.add(event.type);
}

ph.FunctionHandler<dynamic, dynamic> _fn(
        String id, Future<dynamic> Function(dynamic, HandlerContext) fn) =>
    ph.FunctionHandler<dynamic, dynamic>(id: id, name: id, fn: fn);

PipelineContext _ctx(PipelineConfig config, [Map<String, dynamic>? state]) =>
    PipelineContext(runId: 'r', workspaceId: 'w', config: config, state: state);

HandlerContext _hctx([OpsPorts? ports]) => HandlerContext(
    runId: 'r',
    stageId: 's',
    traceId: 't',
    asOf: DateTime.utc(2026),
    ports: ports);

void main() {
  late ph.PipelineHandlerRegistry registry;
  late _Events events;

  // ignore: deprecated_member_use_from_same_package
  pe.PipelineExecutor exec() =>
      pe.PipelineExecutor(registry: registry, listener: events);

  setUp(() {
    registry = ph.PipelineHandlerRegistry();
    events = _Events();
    registry
      ..register(_fn('ok', (i, c) async => {'v': 1}))
      ..register(_fn('boom', (i, c) async => throw StateError('boom')))
      ..register(_fn('echo', (i, c) async => i));
  });

  group('pipeline executor', () {
    test('runs sorted stages with mappings, conditions and events', () async {
      final pipe = _Pipe(const [
        PipelineStage(
            id: 'b',
            name: 'b',
            order: 2,
            handler: 'echo',
            inputMapping: {'got': 'v', 'none': 'absent'}),
        PipelineStage(
            id: 'a',
            name: 'a',
            order: 1,
            handler: 'ok',
            outputMapping: {'v': 'v', 'z': 'zz'}),
        PipelineStage(
            id: 'skipme',
            name: 's',
            order: 3,
            handler: 'ok',
            condition: 'false'),
        PipelineStage(
            id: 'neg', name: 'n', order: 4, handler: 'ok', condition: '!v'),
        PipelineStage(
            id: 'truthy',
            name: 't',
            order: 5,
            handler: 'ok',
            condition: 'flag'),
      ]);
      final ctx = _ctx(pipe.config, {'flag': 'yes'});
      final r = await exec().execute<dynamic, dynamic>(pipe, 'in', ctx);
      expect(r.success, isTrue);
      expect(r.stages.first.stageId, 'a'); // ordered
      expect(ctx.getState<int>('v'), 1);
      expect(
          events.types,
          containsAll([
            'pipeline_started',
            'stage_started',
            'stage_completed',
            'pipeline_completed'
          ]));
    });

    test('conditions: true literal, strings, numbers, absent', () async {
      Future<int> run(String cond, Map<String, dynamic> state) async {
        final pipe = _Pipe([
          PipelineStage(
              id: 's', name: 's', order: 0, handler: 'ok', condition: cond)
        ]);
        final r = await exec()
            .execute<dynamic, dynamic>(pipe, null, _ctx(pipe.config, state));
        return r.stages.single.output == null ? 0 : 1;
      }

      expect(await run('true', {}), 1);
      expect(await run('s', {'s': ''}), 0);
      expect(await run('s', {'s': 'x'}), 1);
      expect(await run('n', {'n': 0}), 0);
      expect(await run('n', {'n': 2}), 1);
      expect(
          await run('n', {
            'n': const [1]
          }),
          1);
      expect(await run('n', {}), 0);
    });

    test('a missing handler fails the stage; error strategies differ',
        () async {
      final pipe = (OnErrorStrategy s) => _Pipe(const [
            PipelineStage(id: 'x', name: 'x', order: 0, handler: 'missing'),
            PipelineStage(id: 'y', name: 'y', order: 1, handler: 'ok'),
          ], config: PipelineConfig(onError: s));
      final fail = await exec().execute<dynamic, dynamic>(
          pipe(OnErrorStrategy.fail),
          null,
          _ctx(pipe(OnErrorStrategy.fail).config));
      expect(fail.success, isFalse);
      expect(fail.error!.code, 'STAGE_FAILED');
      expect(fail.error!.stageId, 'x');
      final skip = await exec().execute<dynamic, dynamic>(
          pipe(OnErrorStrategy.skip),
          null,
          _ctx(pipe(OnErrorStrategy.skip).config));
      expect(skip.stages, hasLength(2));
      final retry = await exec().execute<dynamic, dynamic>(
          pipe(OnErrorStrategy.retry),
          null,
          _ctx(pipe(OnErrorStrategy.retry).config));
      expect(retry.stages, hasLength(2));
      expect(events.types, contains('pipeline_completed'));
    });

    test(
        'a thrown handler becomes a failed stage; unexpected errors are wrapped',
        () async {
      final pipe = _Pipe(const [
        PipelineStage(id: 'x', name: 'x', order: 0, handler: 'boom'),
      ]);
      final r =
          await exec().execute<dynamic, dynamic>(pipe, null, _ctx(pipe.config));
      expect(r.success, isFalse);
      expect(events.types, contains('stage_failed'));
      // An error outside a stage (a throwing listener) is wrapped too.
      final throwing = pe.PipelineExecutor(
          registry: registry, listener: _ThrowingListener());
      final wrapped = await throwing.execute<dynamic, dynamic>(
          pipe, null, _ctx(pipe.config));
      expect(wrapped.success, isFalse);
      expect(wrapped.error!.message, contains('listener exploded'));
    });

    test('retries use the stage or the policy configuration', () async {
      var n = 0;
      registry.register(_fn('flaky', (i, c) async {
        if (++n < 3) throw StateError('x');
        return 'done';
      }));
      const retry =
          RetryConfig(maxAttempts: 3, initialDelay: Duration(milliseconds: 1));
      final byStage = _Pipe(const [
        PipelineStage(
            id: 's', name: 's', order: 0, handler: 'flaky', retryConfig: retry),
      ]);
      expect(
          (await exec().execute<dynamic, dynamic>(
                  byStage, null, _ctx(byStage.config)))
              .success,
          isTrue);
      expect(n, 3);
      n = 0;
      final byPolicy = _Pipe(const [
        PipelineStage(id: 's', name: 's', order: 0, handler: 'flaky'),
      ],
          config:
              PipelineConfig(retryPolicy: RetryPolicy(defaultConfig: retry)));
      expect(
          (await exec().execute<dynamic, dynamic>(
                  byPolicy, null, _ctx(byPolicy.config)))
              .success,
          isTrue);
      n = -10;
      final exhausted = _Pipe(const [
        PipelineStage(
            id: 's',
            name: 's',
            order: 0,
            handler: 'flaky',
            retryConfig: RetryConfig(
                maxAttempts: 2, initialDelay: Duration(milliseconds: 1))),
      ]);
      expect(
          (await exec().execute<dynamic, dynamic>(
                  exhausted, null, _ctx(exhausted.config)))
              .success,
          isFalse);
    });

    test('exception and event classes', () {
      final e = pe.PipelineExecutionException(code: 'C', message: 'm');
      expect(e.toString(), 'PipelineExecutionException(C): m');
      final t = DateTime.utc(2026);
      expect(
          pe.PipelineStartedEvent(pipelineId: 'p', runId: 'r', timestamp: t)
              .type,
          'pipeline_started');
      expect(
          pe.PipelineFailedEvent(
                  pipelineId: 'p',
                  runId: 'r',
                  error: 'e',
                  timestamp: t,
                  failedStage: 's')
              .type,
          'pipeline_failed');
    });
  });

  group('pipeline models', () {
    test('stage and config json round trips, durations in every form', () {
      final stage = PipelineStage.fromJson({
        'id': 's',
        'name': 'n',
        'order': 1,
        'handler': 'h',
        'inputMapping': {'a': 'b'},
        'outputMapping': {'c': 'd'},
        'condition': 'x',
        'retryConfig': {'maxAttempts': 2},
        'timeout': '2m',
        'description': 'desc',
      });
      expect(stage.timeout, const Duration(minutes: 2));
      final json = stage.toJson();
      expect(json['retryConfig'], isA<Map>());
      expect(json['timeout'], 120000);
      expect(PipelineStage.fromJson(const {}).id, '');

      Duration? dur(Object? v) =>
          PipelineStage.fromJson({'timeout': v}).timeout;
      expect(dur('5s'), const Duration(seconds: 5));
      expect(dur('2h'), const Duration(hours: 2));
      expect(dur('3d'), const Duration(days: 3));
      expect(dur('1w'), const Duration(days: 7));
      expect(dur('250'), const Duration(milliseconds: 250));
      expect(dur(1500), const Duration(milliseconds: 1500));
      expect(dur(const Duration(seconds: 9)), const Duration(seconds: 9));
      expect(
          dur({
            'seconds': 1,
            'minutes': 1,
            'hours': 1,
            'days': 1,
            'milliseconds': 1
          }),
          const Duration(
              days: 1, hours: 1, minutes: 1, seconds: 1, milliseconds: 1));
      expect(dur('garbage'), Duration.zero);
      expect(dur(true), Duration.zero);

      final cfg = PipelineConfig.fromJson({
        'maxConcurrency': 3,
        'timeout': '1m',
        'retryPolicy': {
          'default': {'maxAttempts': 4},
          'perStage': {
            's': {'maxAttempts': 9}
          },
        },
        'onError': 'skip',
        'checkpointEnabled': true,
        'extra': {'k': 1},
      });
      expect(cfg.onError, OnErrorStrategy.skip);
      expect(cfg.retryPolicy!.getConfigForStage('s').maxAttempts, 9);
      expect(cfg.retryPolicy!.getConfigForStage('other').maxAttempts, 4);
      final back = cfg.toJson();
      expect(back['timeout'], 60000);
      expect(back['retryPolicy']['perStage'], isNotEmpty);
      expect(back['extra'], {'k': 1});
      expect(PipelineConfig.fromJson(const {}).onError, OnErrorStrategy.fail);
      expect(OnErrorStrategy.fromString('nope'), OnErrorStrategy.fail);
      expect(
          RetryPolicy.fromJson(const {}).defaultConfig.maxAttempts, isNotNull);
      expect(
          const RetryPolicy(defaultConfig: RetryConfig())
              .toJson()
              .containsKey('perStage'),
          isFalse);
    });

    test('pipeline context copies', () {
      final c = _ctx(const PipelineConfig(), {'a': 1});
      final copy = c.copyWith(runId: 'r2', userId: 'u');
      expect(copy.runId, 'r2');
      expect(copy.userId, 'u');
      expect(copy.state, {'a': 1});
      expect(c.copyWith().runId, 'r');
      expect(c.getState<String>('a'), isNull); // wrong type
    });
  });

  group('handler registry', () {
    test('register, list, validate, find, clear', () {
      registry.register(ph.FunctionHandler<dynamic, dynamic>(
          id: 'ns.thing',
          name: 'thing',
          requires: const ['mcp'],
          inputSchema: const {
            'properties': {'a': {}}
          },
          outputSchema: const {'type': 'object'},
          fn: (i, c) async => i));
      expect(registry.has('ns.thing'), isTrue);
      registry.unregister('echo');
      expect(registry.has('echo'), isFalse);
      expect(registry.list(filter: const ph.HandlerFilter(namespace: 'ns')),
          hasLength(1));
      expect(registry.list(filter: const ph.HandlerFilter()), isNotEmpty);
      final info =
          registry.list(filter: const ph.HandlerFilter(namespace: 'ns')).single;
      expect(info.toJson()['requires'], ['mcp']);
      expect(info.toJson()['inputSchema'], isNotEmpty);
      expect(info.toJson()['outputSchema'], isNotEmpty);
      final plain = registry.list().firstWhere((h) => h.id == 'ok').toJson();
      expect(plain.containsKey('requires'), isFalse);

      expect(registry.validate('nope').valid, isFalse);
      expect(registry.validate('ns.thing', required: ['a']).valid, isTrue);
      final bad = registry.validate('ns.thing', required: ['a', 'zz']);
      expect(bad.errors.single, contains('zz'));
      expect(
          registry.validate('ok', required: ['x']).valid, isFalse); // no schema
      expect(registry.validate('ok', required: const []).valid, isTrue);
      expect(registry.findByPattern('ns.*'), hasLength(1));
      registry.clear();
      expect(registry.list(), isEmpty);
    });

    test('function handler defaults', () async {
      final h = _fn('x', (i, c) async => i);
      expect(h.validateInput(1), isNull);
      await h.cleanup(_hctx());
      expect(ph.ValidationResult.valid().valid, isTrue);
      expect(const ph.ValidationResult(valid: true, warnings: ['w']).warnings,
          ['w']);
    });
  });

  group('handler adapters', () {
    test('the registration service', () {
      final s = HandlerRegistrationService();
      final h = ExpressionHandlerAdapter(expression: 'a');
      s.register('e', h);
      expect(s.has('e'), isTrue);
      expect(s.getHandler('e'), same(h));
      expect(s.listHandlers(), ['e']);
      s.unregister('e');
      s.register('x', h);
      s.clear();
      expect(s.listHandlers(), isEmpty);
    });

    test('mcp tool: with ports, from the constructor, and without', () async {
      final ports = TestOpsPorts().toOpsPorts();
      final a = McpToolHandlerAdapter(
          toolName: 't', defaultParams: const {'d': 1}, serverId: 's');
      expect(a.name, 'mcp.t');
      expect(a.requires, ['mcp']);
      final out = await a.execute({'x': 2}, _hctx(ports));
      expect(out['toolName'], 't');
      expect(out['isError'], isFalse);
      final fromCtor =
          McpToolHandlerAdapter(toolName: 't', ports: ports, name: 'n');
      expect((await fromCtor.execute({}, _hctx()))['toolName'], 't');
      await expectLater(a.execute({}, _hctx()), throwsStateError);
    });

    test('llm handler interpolates its prompt; needs a port', () async {
      final ports = TestOpsPorts().toOpsPorts();
      final a = LlmHandlerAdapter(prompt: 'Hello {{who}}', model: 'm');
      expect(a.requires, ['llm']);
      expect(a.name, 'llm.complete');
      final r = await a.execute({'who': 'world'}, _hctx(ports));
      expect(r['prompt'], 'Hello world');
      expect(r['response'], 'mock response');
      await expectLater(a.execute({}, _hctx()), throwsStateError);
      expect(
          (await LlmHandlerAdapter(prompt: 'p', ports: ports, name: 'x')
              .execute({}, _hctx()))['model'],
          isNull);
    });

    test('expression handler', () async {
      Future<dynamic> run(String e, Map<String, dynamic> data) async =>
          (await ExpressionHandlerAdapter(expression: e)
              .execute(data, _hctx()))['result'];
      expect(
          await run('a.b', {
            'a': {'b': 5}
          }),
          5);
      expect(
          await run('a.b.c', {
            'a': {'b': 5}
          }),
          isNull);
      expect(await run('missing ?? fallback', {}), 'fallback');
      expect(await run('x ?? y', {'x': 3}), 3);
      expect(await run('x ??', {}), '');
      expect(await run('n >= 3', {'n': 3}), isTrue);
      expect(await run('n > 3', {'n': 3}), isFalse);
      expect(await run('n < 4', {'n': 3}), isTrue);
      expect(await run('n <= 2', {'n': 3}), isFalse);
      expect(await run('n == 3', {'n': 3}), isTrue);
      expect(await run('n != 3', {'n': 3}), isFalse);
      expect(await run("s == 'ok'", {'s': 'ok'}), isTrue);
      expect(await run('s == "ok"', {'s': 'ok'}), isTrue);
      expect(await run('b == true', {'b': true}), isTrue);
      expect(await run('b != false', {'b': true}), isTrue);
      expect(await run('s > t', {'s': 'a', 't': 'b'}), isNull); // not numbers
      expect(await run('a == b == c', {}), isNull); // not a binary comparison
      expect(ExpressionHandlerAdapter(expression: 'x', name: 'n').name, 'n');
    });

    test('philosophy adapters: skipped without a port, results with one',
        () async {
      final intervene = PhilosophyInterventionHandlerAdapter(
          interventionPoint: mb.InterventionPoint.postGeneration);
      expect(intervene.name, 'philosophy.intervene.postGeneration');
      expect(intervene.requires, ['philosophy']);
      expect((await intervene.execute({}, _hctx()))['status'], 'skipped');
      final ports = TestOpsPorts().toOpsPorts();
      final passed = await intervene.execute({'k': 1}, _hctx(ports));
      expect(passed['status'], 'passed');
      final withPipeline = HandlerContext(
          runId: 'r',
          stageId: 's',
          pipelineId: 'p',
          traceId: 't',
          asOf: DateTime.utc(2026),
          ports: ports);
      expect((await intervene.execute({}, withPipeline))['status'], 'passed');

      final prohibition = PhilosophyProhibitionHandlerAdapter();
      expect(prohibition.name, 'philosophy.checkProhibitions');
      expect(prohibition.requires, ['philosophy']);
      expect((await prohibition.execute({}, _hctx()))['status'], 'skipped');
      final ok = await prohibition
          .execute({'action': 'a', 'output': 'o'}, _hctx(ports));
      expect(ok['status'], 'passed');
      expect(ok['checkCount'], isA<int>());
    });
  });
}

class _ThrowingListener implements pe.PipelineEventListener {
  @override
  void onEvent(pe.PipelineEvent event) {
    if (event.type == 'stage_started') throw StateError('listener exploded');
  }
}
