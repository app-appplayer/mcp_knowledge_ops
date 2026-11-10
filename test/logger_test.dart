/// Logger Tests - Tests for Logger, ExecutionLogger, LogSink, and related classes.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // Logger
  // ═══════════════════════════════════════════════════════════════

  group('Logger', () {
    late InMemoryLogSink sink;
    late Logger logger;

    setUp(() {
      sink = InMemoryLogSink();
      logger = Logger(name: 'test', minLevel: LogLevel.trace, sink: sink);
    });

    test('logs at all levels', () {
      logger.trace('trace message');
      logger.debug('debug message');
      logger.info('info message');
      logger.warn('warn message');
      logger.error('error message');
      logger.fatal('fatal message');

      expect(sink.entries.length, equals(6));
      expect(sink.entries[0].level, equals(LogLevel.trace));
      expect(sink.entries[0].message, equals('trace message'));
      expect(sink.entries[1].level, equals(LogLevel.debug));
      expect(sink.entries[2].level, equals(LogLevel.info));
      expect(sink.entries[3].level, equals(LogLevel.warn));
      expect(sink.entries[4].level, equals(LogLevel.error));
      expect(sink.entries[5].level, equals(LogLevel.fatal));
    });

    test('minLevel filters lower levels', () {
      final filtered =
          Logger(name: 'filtered', minLevel: LogLevel.warn, sink: sink);

      filtered.trace('should not appear');
      filtered.debug('should not appear');
      filtered.info('should not appear');
      filtered.warn('should appear');
      filtered.error('should appear');
      filtered.fatal('should appear');

      expect(sink.entries.length, equals(3));
      expect(sink.entries[0].level, equals(LogLevel.warn));
      expect(sink.entries[1].level, equals(LogLevel.error));
      expect(sink.entries[2].level, equals(LogLevel.fatal));
    });

    test('child() creates logger with parent name prefix', () {
      final child = logger.child('sub');

      child.info('child message');

      expect(sink.entries.length, equals(1));
      expect(sink.entries.first.logger, equals('test.sub'));
    });

    test('child() inherits context from parent', () {
      final parent = Logger(
          name: 'parent',
          minLevel: LogLevel.trace,
          sink: sink,
          context: {'env': 'test'});
      final child = parent.child('child', context: {'extra': 'data'});

      child.info('message');

      final entry = sink.entries.first;
      expect(entry.context['env'], equals('test'));
      expect(entry.context['extra'], equals('data'));
    });

    test('withContext() adds context to log entries', () {
      final contextLogger = logger.withContext({'userId': 'u-1'});

      contextLogger.info('contextual message');

      final entry = sink.entries.first;
      expect(entry.userId, equals('u-1'));
    });

    test('withTraceId() sets traceId in context', () {
      final traced = logger.withTraceId('trace-123');

      traced.info('traced message');

      final entry = sink.entries.first;
      expect(entry.traceId, equals('trace-123'));
    });

    test('error() accepts error object', () {
      logger.error('something broke', error: StateError('bad state'));

      final entry = sink.entries.first;
      expect(entry.level, equals(LogLevel.error));
      expect(entry.context['error'], contains('bad state'));
    });

    test('fatal() accepts error object', () {
      logger.fatal('critical failure', error: Exception('boom'));

      final entry = sink.entries.first;
      expect(entry.level, equals(LogLevel.fatal));
      expect(entry.context['error'], contains('boom'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // ExecutionLogger
  // ═══════════════════════════════════════════════════════════════

  group('ExecutionLogger', () {
    late InMemoryLogSink sink;
    late ExecutionLogger logger;

    setUp(() {
      sink = InMemoryLogSink();
      logger = ExecutionLogger(
        name: 'exec',
        minLevel: LogLevel.trace,
        sink: sink,
      );
    });

    test('stageStart logs stage start event', () {
      logger.stageStart('stage-1');

      expect(sink.entries.length, equals(1));
      final entry = sink.entries.first;
      expect(entry.message, contains('stage-1'));
      expect(entry.context['event'], equals('stage.start'));
      expect(entry.context['stageId'], equals('stage-1'));
    });

    test('stageEnd logs stage end event', () {
      logger.stageEnd('stage-1', result: 'ok');

      expect(sink.entries.length, equals(1));
      final entry = sink.entries.first;
      expect(entry.context['event'], equals('stage.end'));
      expect(entry.context['stageId'], equals('stage-1'));
      expect(entry.context['result'], equals('ok'));
    });

    test('stageFail logs stage failure', () {
      logger.stageFail('stage-1', Exception('test error'));

      expect(sink.entries.length, equals(1));
      final entry = sink.entries.first;
      expect(entry.level, equals(LogLevel.error));
      expect(entry.context['event'], equals('stage.fail'));
      expect(entry.context['stageId'], equals('stage-1'));
    });

    test('stageSkip logs skipped stage with reason', () {
      logger.stageSkip('stage-2', reason: 'not applicable');

      expect(sink.entries.length, equals(1));
      final entry = sink.entries.first;
      expect(entry.context['event'], equals('stage.skip'));
      expect(entry.context['reason'], equals('not applicable'));
    });

    test('gateEvaluate logs gate evaluation', () {
      logger.gateEvaluate('gate-1', true);

      expect(sink.entries.length, equals(1));
      final entry = sink.entries.first;
      expect(entry.context['event'], equals('gate.evaluate'));
      expect(entry.context['gateId'], equals('gate-1'));
      expect(entry.context['result'], isTrue);
    });

    test('progress() with current/total', () {
      logger.progress('stage-1', current: 5, total: 10);

      expect(sink.entries.length, equals(1));
      final entry = sink.entries.first;
      expect(entry.context['event'], equals('progress'));
      expect(entry.context['current'], equals(5));
      expect(entry.context['total'], equals(10));
      expect(entry.context['percent'], equals(0.5));
    });

    test('progress() with percent', () {
      logger.progress('stage-1', percent: 0.75);

      expect(sink.entries.length, equals(1));
      final entry = sink.entries.first;
      expect(entry.context['percent'], equals(0.75));
    });

    test('checkpoint() logs checkpoint', () {
      logger.checkpoint('cp-1', data: 'snapshot');

      expect(sink.entries.length, equals(1));
      final entry = sink.entries.first;
      expect(entry.context['event'], equals('checkpoint'));
      expect(entry.context['checkpointId'], equals('cp-1'));
    });

    test('metric() logs performance metric', () {
      logger.metric('latency', 42.5, unit: 'ms');

      expect(sink.entries.length, equals(1));
      final entry = sink.entries.first;
      expect(entry.context['event'], equals('metric'));
      expect(entry.context['metricName'], equals('latency'));
      expect(entry.context['value'], equals(42.5));
      expect(entry.context['unit'], equals('ms'));
    });

    test('child() returns ExecutionLogger', () {
      final child = logger.child('sub');
      expect(child, isA<ExecutionLogger>());
      expect(child.name, equals('exec.sub'));
    });

    test('withContext() returns ExecutionLogger', () {
      final ctx = logger.withContext({'key': 'val'});
      expect(ctx, isA<ExecutionLogger>());
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // InMemoryLogSink
  // ═══════════════════════════════════════════════════════════════

  group('InMemoryLogSink', () {
    late InMemoryLogSink sink;

    setUp(() {
      sink = InMemoryLogSink();
    });

    test('captures entries', () {
      final entry = LogEntry(
        timestamp: DateTime(2024, 1, 1),
        level: LogLevel.info,
        logger: 'test',
        message: 'hello',
      );
      sink.write(entry);

      expect(sink.entries.length, equals(1));
      expect(sink.entries.first.message, equals('hello'));
    });

    test('entriesByLevel filters correctly', () {
      sink.write(LogEntry(
        timestamp: DateTime(2024, 1, 1),
        level: LogLevel.info,
        logger: 'test',
        message: 'info msg',
      ));
      sink.write(LogEntry(
        timestamp: DateTime(2024, 1, 1),
        level: LogLevel.error,
        logger: 'test',
        message: 'error msg',
      ));
      sink.write(LogEntry(
        timestamp: DateTime(2024, 1, 1),
        level: LogLevel.info,
        logger: 'test',
        message: 'info msg 2',
      ));

      final infos = sink.entriesByLevel(LogLevel.info);
      expect(infos.length, equals(2));

      final errors = sink.entriesByLevel(LogLevel.error);
      expect(errors.length, equals(1));
    });

    test('clear() removes all entries', () {
      sink.write(LogEntry(
        timestamp: DateTime(2024, 1, 1),
        level: LogLevel.info,
        logger: 'test',
        message: 'hello',
      ));
      expect(sink.entries.length, equals(1));

      sink.clear();
      expect(sink.entries, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // MultiLogSink
  // ═══════════════════════════════════════════════════════════════

  group('MultiLogSink', () {
    test('delegates to all sinks', () {
      final sink1 = InMemoryLogSink();
      final sink2 = InMemoryLogSink();
      final multi = MultiLogSink([sink1, sink2]);

      final entry = LogEntry(
        timestamp: DateTime(2024, 1, 1),
        level: LogLevel.info,
        logger: 'test',
        message: 'broadcast',
      );
      multi.write(entry);

      expect(sink1.entries.length, equals(1));
      expect(sink2.entries.length, equals(1));
      expect(sink1.entries.first.message, equals('broadcast'));
      expect(sink2.entries.first.message, equals('broadcast'));
    });

    test('flush() delegates to all sinks', () async {
      final sink1 = InMemoryLogSink();
      final sink2 = InMemoryLogSink();
      final multi = MultiLogSink([sink1, sink2]);

      // Should not throw
      await multi.flush();
    });

    test('close() delegates to all sinks', () async {
      final sink1 = InMemoryLogSink();
      final sink2 = InMemoryLogSink();
      final multi = MultiLogSink([sink1, sink2]);

      // Should not throw
      await multi.close();
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // LogError
  // ═══════════════════════════════════════════════════════════════

  group('LogError', () {
    test('from() creates from error and stack trace', () {
      final error = StateError('bad state');
      final stack = StackTrace.current;
      final logError = LogError.from(error, stack);

      expect(logError.type, equals('StateError'));
      expect(logError.message, contains('bad state'));
      expect(logError.stack, isNotNull);
    });

    test('from() works without stack trace', () {
      final logError = LogError.from(Exception('test'));

      expect(logError.type, equals('_Exception'));
      expect(logError.message, contains('test'));
      expect(logError.stack, isNull);
    });

    test('toJson() serializes correctly', () {
      final logError = LogError(
        type: 'TestError',
        message: 'test message',
        code: 'ERR_001',
        stack: 'line 1\nline 2',
        cause: 'root cause',
      );

      final json = logError.toJson();
      expect(json['type'], equals('TestError'));
      expect(json['message'], equals('test message'));
      expect(json['code'], equals('ERR_001'));
      expect(json['stack'], equals('line 1\nline 2'));
      expect(json['cause'], equals('root cause'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // LogEntry
  // ═══════════════════════════════════════════════════════════════

  group('LogEntry', () {
    test('toJson() serializes correctly', () {
      final entry = LogEntry(
        timestamp: DateTime(2024, 1, 1),
        level: LogLevel.info,
        logger: 'test.logger',
        message: 'hello world',
        context: {'key': 'value'},
        traceId: 'trace-1',
        spanId: 'span-1',
        workspaceId: 'ws-1',
        userId: 'user-1',
        tags: ['tag1', 'tag2'],
        environment: 'test',
      );

      final json = entry.toJson();
      expect(json['level'], equals('info'));
      expect(json['logger'], equals('test.logger'));
      expect(json['message'], equals('hello world'));
      expect(json['context'], equals({'key': 'value'}));
      expect(json['traceId'], equals('trace-1'));
      expect(json['spanId'], equals('span-1'));
      expect(json['workspaceId'], equals('ws-1'));
      expect(json['userId'], equals('user-1'));
      expect(json['tags'], equals(['tag1', 'tag2']));
      expect(json['environment'], equals('test'));
    });

    test('toString() formats correctly', () {
      final entry = LogEntry(
        timestamp: DateTime(2024, 1, 1),
        level: LogLevel.error,
        logger: 'test',
        message: 'failure',
      );

      final str = entry.toString();
      expect(str, contains('ERROR'));
      expect(str, contains('test'));
      expect(str, contains('failure'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // LogLevel
  // ═══════════════════════════════════════════════════════════════

  group('LogLevel', () {
    test('has all expected values', () {
      expect(LogLevel.values.length, equals(6));
      expect(
          LogLevel.values,
          containsAll([
            LogLevel.trace,
            LogLevel.debug,
            LogLevel.info,
            LogLevel.warn,
            LogLevel.error,
            LogLevel.fatal
          ]));
    });

    test('ordering is correct', () {
      expect(LogLevel.trace.index, lessThan(LogLevel.debug.index));
      expect(LogLevel.debug.index, lessThan(LogLevel.info.index));
      expect(LogLevel.info.index, lessThan(LogLevel.warn.index));
      expect(LogLevel.warn.index, lessThan(LogLevel.error.index));
      expect(LogLevel.error.index, lessThan(LogLevel.fatal.index));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // LogSampling
  // ═══════════════════════════════════════════════════════════════

  group('LogSampling', () {
    test('default values', () {
      const sampling = LogSampling();
      expect(sampling.rate, equals(1.0));
      expect(sampling.alwaysLogAbove, equals(LogLevel.warn));
    });

    test('custom rate and alwaysLogAbove', () {
      const sampling = LogSampling(rate: 0.5, alwaysLogAbove: LogLevel.error);
      expect(sampling.rate, equals(0.5));
      expect(sampling.alwaysLogAbove, equals(LogLevel.error));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // RedactionConfig
  // ═══════════════════════════════════════════════════════════════

  group('RedactionConfig', () {
    test('default fields include sensitive keys', () {
      const config = RedactionConfig();
      expect(config.enabled, isTrue);
      expect(config.fields, contains('password'));
      expect(config.fields, contains('token'));
      expect(config.fields, contains('secret'));
      expect(config.fields, contains('apiKey'));
      expect(config.fields, contains('authorization'));
      expect(config.replacement, equals('***REDACTED***'));
    });

    test('custom configuration', () {
      const config = RedactionConfig(
        enabled: false,
        fields: ['customField'],
        replacement: '[HIDDEN]',
      );
      expect(config.enabled, isFalse);
      expect(config.fields, equals(['customField']));
      expect(config.replacement, equals('[HIDDEN]'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // LoggerConfig
  // ═══════════════════════════════════════════════════════════════

  group('LoggerConfig', () {
    test('default values', () {
      const config = LoggerConfig();
      expect(config.minLevel, equals(LogLevel.info));
      expect(config.format, equals(LogFormat.json));
      expect(config.outputs, equals(['console']));
      expect(config.sampling, isNull);
      expect(config.redaction, isNull);
    });

    test('custom configuration', () {
      const config = LoggerConfig(
        minLevel: LogLevel.debug,
        format: LogFormat.text,
        outputs: ['console', 'file'],
        sampling: LogSampling(rate: 0.5),
        redaction: RedactionConfig(),
      );
      expect(config.minLevel, equals(LogLevel.debug));
      expect(config.format, equals(LogFormat.text));
      expect(config.outputs, equals(['console', 'file']));
      expect(config.sampling, isNotNull);
      expect(config.redaction, isNotNull);
    });
  });
}
