/// Logger - Execution logging for observability.
///
/// Provides structured logging for pipeline and workflow execution.
library;

import 'dart:async';

/// Log level.
enum LogLevel {
  trace,
  debug,
  info,
  warn,
  error,
  fatal,
}

/// Base logger providing structured logging with context propagation.
class Logger {
  /// Logger name.
  final String name;

  /// Minimum log level.
  final LogLevel minLevel;

  /// Log sink.
  final LogSink _sink;

  /// Context data.
  final Map<String, dynamic> _context;

  Logger({
    this.name = 'default',
    this.minLevel = LogLevel.info,
    LogSink? sink,
    Map<String, dynamic>? context,
  })  : _sink = sink ?? ConsoleLogSink(),
        _context = context ?? {};

  /// Create child logger with additional context.
  Logger child(String childName, {Map<String, dynamic>? context}) {
    return Logger(
      name: '$name.$childName',
      minLevel: minLevel,
      sink: _sink,
      context: {..._context, ...?context},
    );
  }

  /// Create a new logger with additional context merged in.
  Logger withContext(Map<String, dynamic> additionalContext) {
    return Logger(
      name: name,
      minLevel: minLevel,
      sink: _sink,
      context: {..._context, ...additionalContext},
    );
  }

  /// Create a new logger with a trace ID set in context.
  Logger withTraceId(String traceId) {
    return withContext({'traceId': traceId});
  }

  /// Log trace message.
  void trace(String message, [Map<String, dynamic>? context]) {
    _log(LogLevel.trace, message, context: context);
  }

  /// Log debug message.
  void debug(String message, [Map<String, dynamic>? context]) {
    _log(LogLevel.debug, message, context: context);
  }

  /// Log info message.
  void info(String message, [Map<String, dynamic>? context]) {
    _log(LogLevel.info, message, context: context);
  }

  /// Log warning message.
  void warn(String message, [Map<String, dynamic>? context]) {
    _log(LogLevel.warn, message, context: context);
  }

  /// Log error message.
  void error(String message, {Object? error, Map<String, dynamic>? context}) {
    _log(LogLevel.error, message, error: error, context: context);
  }

  /// Log fatal message.
  void fatal(String message, {Object? error, Map<String, dynamic>? context}) {
    _log(LogLevel.fatal, message, error: error, context: context);
  }

  void _log(
    LogLevel level,
    String message, {
    Object? error,
    Map<String, dynamic>? context,
  }) {
    if (level.index < minLevel.index) return;

    final merged = {
      ..._context,
      ...?context,
      if (error != null) 'error': error.toString(),
    };

    // Extract structured fields from context if present.
    final traceId = merged.remove('traceId') as String?;
    final spanId = merged.remove('spanId') as String?;
    final workspaceId = merged.remove('workspaceId') as String?;
    final userId = merged.remove('userId') as String?;
    final environment = merged.remove('environment') as String?;
    final rawTags = merged.remove('tags');
    final tags =
        rawTags is List ? rawTags.cast<String>() : const <String>[];

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      logger: name,
      message: message,
      context: merged,
      traceId: traceId,
      spanId: spanId,
      workspaceId: workspaceId,
      userId: userId,
      tags: tags,
      environment: environment,
    );

    _sink.write(entry);
  }
}

/// Execution logger with additional methods for pipeline/workflow lifecycle.
///
/// Extends [Logger] with stage lifecycle, gate evaluation, progress tracking,
/// and performance metric methods for observability during execution.
class ExecutionLogger extends Logger {
  ExecutionLogger({
    super.name = 'execution',
    super.minLevel,
    super.sink,
    super.context,
  });

  @override
  ExecutionLogger child(String childName, {Map<String, dynamic>? context}) {
    return ExecutionLogger(
      name: '$name.$childName',
      minLevel: minLevel,
      sink: _sink,
      context: {..._context, ...?context},
    );
  }

  @override
  ExecutionLogger withContext(Map<String, dynamic> additionalContext) {
    return ExecutionLogger(
      name: name,
      minLevel: minLevel,
      sink: _sink,
      context: {..._context, ...additionalContext},
    );
  }

  @override
  ExecutionLogger withTraceId(String traceId) {
    return withContext({'traceId': traceId});
  }

  /// Log the start of a stage.
  void stageStart(String stageId, {Map<String, dynamic>? metadata}) {
    info('Stage started: $stageId', {
      'event': 'stage.start',
      'stageId': stageId,
      ...?metadata,
    });
  }

  /// Log the successful end of a stage.
  void stageEnd(String stageId, {Object? result, Map<String, dynamic>? metadata}) {
    info('Stage ended: $stageId', {
      'event': 'stage.end',
      'stageId': stageId,
      if (result != null) 'result': result.toString(),
      ...?metadata,
    });
  }

  /// Log a stage failure.
  void stageFail(String stageId, Object error, {Map<String, dynamic>? metadata}) {
    this.error('Stage failed: $stageId', error: error, context: {
      'event': 'stage.fail',
      'stageId': stageId,
      ...?metadata,
    });
  }

  /// Log a skipped stage.
  void stageSkip(String stageId, {String? reason, Map<String, dynamic>? metadata}) {
    info('Stage skipped: $stageId', {
      'event': 'stage.skip',
      'stageId': stageId,
      if (reason != null) 'reason': reason,
      ...?metadata,
    });
  }

  /// Log a gate evaluation result.
  void gateEvaluate(String gateId, bool result, {Map<String, dynamic>? metadata}) {
    info('Gate evaluated: $gateId = $result', {
      'event': 'gate.evaluate',
      'gateId': gateId,
      'result': result,
      ...?metadata,
    });
  }

  /// Log execution progress.
  ///
  /// Accepts [current] and [total] integers per spec for precise tracking.
  /// Falls back to [percent] (0.0-1.0) for compatibility.
  void progress(
    String stageId, {
    int? current,
    int? total,
    double? percent,
    Map<String, dynamic>? metadata,
  }) {
    final pct = (current != null && total != null && total > 0)
        ? (current / total)
        : (percent ?? 0.0);
    debug('Progress: $stageId ${(pct * 100).toStringAsFixed(1)}%', {
      'event': 'progress',
      'stageId': stageId,
      if (current != null) 'current': current,
      if (total != null) 'total': total,
      'percent': pct,
      ...?metadata,
    });
  }

  /// Log an execution checkpoint.
  void checkpoint(String checkpointId, {Object? data, Map<String, dynamic>? metadata}) {
    info('Checkpoint: $checkpointId', {
      'event': 'checkpoint',
      'checkpointId': checkpointId,
      if (data != null) 'data': data.toString(),
      ...?metadata,
    });
  }

  /// Log a performance metric.
  void metric(String name, double value, {String? unit, Map<String, dynamic>? metadata}) {
    debug('Metric: $name = $value${unit != null ? ' $unit' : ''}', {
      'event': 'metric',
      'metricName': name,
      'value': value,
      if (unit != null) 'unit': unit,
      ...?metadata,
    });
  }
}

/// Structured error information attached to a log entry.
class LogError {
  /// Error type (runtime type name).
  final String type;

  /// Error message.
  final String message;

  /// Machine-readable error code.
  final String? code;

  /// Stack trace string.
  final String? stack;

  /// Cause chain (inner exception details).
  final String? cause;

  const LogError({
    required this.type,
    required this.message,
    this.code,
    this.stack,
    this.cause,
  });

  /// Create from an error object and optional stack trace.
  factory LogError.from(Object error, [StackTrace? stackTrace]) {
    return LogError(
      type: error.runtimeType.toString(),
      message: error.toString(),
      stack: stackTrace?.toString(),
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'type': type,
        'message': message,
        if (code != null) 'code': code,
        if (stack != null) 'stack': stack,
        if (cause != null) 'cause': cause,
      };
}

/// Log entry.
class LogEntry {
  /// Entry timestamp.
  final DateTime timestamp;

  /// Log level.
  final LogLevel level;

  /// Logger name.
  final String logger;

  /// Log message.
  final String message;

  /// Additional context data.
  final Map<String, dynamic> context;

  /// Trace ID for distributed tracing correlation.
  final String? traceId;

  /// Span ID for distributed tracing correlation.
  final String? spanId;

  /// Workspace identifier.
  final String? workspaceId;

  /// User identifier.
  final String? userId;

  /// Tags for categorization and filtering.
  final List<String> tags;

  /// Environment name (e.g., 'production', 'staging', 'development').
  final String? environment;

  /// Duration of the operation being logged.
  final Duration? duration;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.logger,
    required this.message,
    this.context = const {},
    this.traceId,
    this.spanId,
    this.workspaceId,
    this.userId,
    this.tags = const [],
    this.environment,
    this.duration,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level.name,
        'logger': logger,
        'message': message,
        if (context.isNotEmpty) 'context': context,
        if (traceId != null) 'traceId': traceId,
        if (spanId != null) 'spanId': spanId,
        if (workspaceId != null) 'workspaceId': workspaceId,
        if (userId != null) 'userId': userId,
        if (tags.isNotEmpty) 'tags': tags,
        if (environment != null) 'environment': environment,
        if (duration != null) 'durationMs': duration!.inMilliseconds,
      };

  @override
  String toString() {
    final levelStr = level.name.toUpperCase().padRight(5);
    final dataStr = context.isNotEmpty ? ' $context' : '';
    final traceStr = traceId != null ? ' [trace:$traceId]' : '';
    return '${timestamp.toIso8601String()} [$levelStr] $logger:$traceStr $message$dataStr';
  }
}

/// Log sink interface.
abstract class LogSink {
  /// Write log entry.
  void write(LogEntry entry);

  /// Flush buffered entries.
  Future<void> flush();

  /// Close sink.
  Future<void> close();
}

/// Console log sink.
class ConsoleLogSink implements LogSink {
  @override
  void write(LogEntry entry) {
    // Uses Zone-based output in production; direct print for console sink.
    // ignore: avoid_print
    Zone.current.print(entry.toString());
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}

/// In-memory log sink for testing.
class InMemoryLogSink implements LogSink {
  final List<LogEntry> _entries = [];

  /// Get all entries.
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Get entries by level.
  List<LogEntry> entriesByLevel(LogLevel level) {
    return _entries.where((e) => e.level == level).toList();
  }

  /// Clear entries.
  void clear() => _entries.clear();

  @override
  void write(LogEntry entry) {
    _entries.add(entry);
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}

/// Multi-sink that writes to multiple sinks.
class MultiLogSink implements LogSink {
  final List<LogSink> _sinks;

  MultiLogSink(this._sinks);

  @override
  void write(LogEntry entry) {
    for (final sink in _sinks) {
      sink.write(entry);
    }
  }

  @override
  Future<void> flush() async {
    await Future.wait(_sinks.map((s) => s.flush()));
  }

  @override
  Future<void> close() async {
    await Future.wait(_sinks.map((s) => s.close()));
  }
}

// ═══════════════════════════════════════════════════════════════════
// Logger Configuration
// ═══════════════════════════════════════════════════════════════════

/// Log output format.
enum LogFormat {
  /// Structured JSON output.
  json,

  /// Human-readable text output.
  text,
}

/// Logger configuration.
///
/// Controls minimum level, output format, sink targets,
/// sampling, and redaction settings.
class LoggerConfig {
  /// Minimum log level.
  final LogLevel minLevel;

  /// Output format.
  final LogFormat format;

  /// Output sink identifiers (e.g., 'console', 'file').
  final List<String> outputs;

  /// Sampling configuration for high-volume logs.
  final LogSampling? sampling;

  /// Redaction configuration for sensitive data.
  final RedactionConfig? redaction;

  const LoggerConfig({
    this.minLevel = LogLevel.info,
    this.format = LogFormat.json,
    this.outputs = const ['console'],
    this.sampling,
    this.redaction,
  });
}

/// Log sampling configuration.
///
/// Controls which log entries are sampled for high-volume scenarios.
class LogSampling {
  /// Sampling rate (0.0 to 1.0). 1.0 means all logs are emitted.
  final double rate;

  /// Minimum level that bypasses sampling (always emitted).
  final LogLevel alwaysLogAbove;

  const LogSampling({
    this.rate = 1.0,
    this.alwaysLogAbove = LogLevel.warn,
  });
}

/// Redaction configuration for sensitive data in logs.
///
/// Controls which context fields are redacted before logging.
class RedactionConfig {
  /// Whether redaction is enabled.
  final bool enabled;

  /// Field names to redact from log context.
  final List<String> fields;

  /// Replacement string for redacted values.
  final String replacement;

  const RedactionConfig({
    this.enabled = true,
    this.fields = const ['password', 'token', 'secret', 'apiKey', 'authorization'],
    this.replacement = '***REDACTED***',
  });
}
