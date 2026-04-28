/// EventRouter - Routes OpsEvents to registered handlers by pattern.
///
/// Supports wildcard pattern matching, interceptor pipelines,
/// safe handler execution with error callbacks, and handler registration
/// for decoupled event-driven architectures.
library;

import '../observability/logger.dart';
import 'ops_event.dart';
import 'event_subscriber.dart';

/// Chain-of-responsibility interceptor applied before handler execution.
///
/// Receives the event and a [next] callback to continue the chain.
/// Call [next] to pass control to the next interceptor/handler.
/// Skip calling [next] to suppress the event.
typedef EventInterceptor = Future<void> Function(
  OpsEvent event,
  Future<void> Function() next,
);

/// Error callback invoked when a handler throws.
typedef EventErrorHandler = void Function(
  OpsEvent event,
  String handlerPattern,
  Object error,
  StackTrace stackTrace,
);

/// Routes incoming [OpsEvent] instances to matching registered handlers.
///
/// Handlers are matched by event type patterns that support wildcards.
/// Interceptors are applied in registration order before handler execution.
class EventRouter {
  /// Registered handlers keyed by pattern.
  final Map<String, List<EventHandler>> _handlers = {};

  /// Ordered interceptor pipeline.
  final List<EventInterceptor> _interceptors = [];

  /// Error callback for handler failures.
  EventErrorHandler? onError;

  /// Logger for routing operations.
  final ExecutionLogger _logger;

  EventRouter({
    required ExecutionLogger logger,
    this.onError,
  }) : _logger = logger.child('event_router');

  /// Register a handler for events matching [pattern].
  ///
  /// Patterns support wildcards:
  /// - 'ops.pipeline.started' matches exactly that type.
  /// - 'ops.pipeline.*' matches any type starting with 'ops.pipeline.'.
  /// - '**' matches all event types.
  void register(String pattern, EventHandler handler) {
    _handlers.putIfAbsent(pattern, () => []).add(handler);
    _logger.debug('Handler registered', {
      'pattern': pattern,
      'totalHandlers': _handlers[pattern]!.length,
    });
  }

  /// Remove all handlers for a given pattern.
  void unregister(String pattern) {
    final removed = _handlers.remove(pattern);
    if (removed != null) {
      _logger.debug('Handlers unregistered', {
        'pattern': pattern,
        'count': removed.length,
      });
    }
  }

  /// Add an interceptor to the pipeline.
  ///
  /// Interceptors are applied in the order they are added.
  /// An interceptor can call [next] to continue the chain or skip it
  /// to suppress the event.
  void addInterceptor(EventInterceptor interceptor) {
    _interceptors.add(interceptor);
    _logger.debug('Interceptor added', {
      'totalInterceptors': _interceptors.length,
    });
  }

  /// Remove all interceptors.
  void clearInterceptors() {
    _interceptors.clear();
    _logger.debug('All interceptors cleared');
  }

  /// Route an event to all matching handlers.
  ///
  /// Applies interceptors first, then dispatches to all handlers
  /// whose patterns match the event type. Returns the number of
  /// handlers that were invoked.
  Future<int> route(OpsEvent event) async {
    _logger.trace('Routing event', {
      'eventId': event.eventId,
      'eventType': event.eventType,
    });

    // Apply chain-of-responsibility interceptor pipeline.
    final proceeded = await _applyInterceptorChain(event, 0);

    // Event was suppressed by an interceptor (next was not called).
    if (!proceeded) {
      _logger.debug('Event suppressed by interceptor', {
        'eventId': event.eventId,
        'eventType': event.eventType,
      });
      return 0;
    }

    // Find and execute matching handlers.
    final handlers = _findHandlers(event.eventType);
    if (handlers.isEmpty) {
      _logger.trace('No handlers matched', {
        'eventType': event.eventType,
      });
      return 0;
    }

    _logger.debug('Dispatching to handlers', {
      'eventId': event.eventId,
      'eventType': event.eventType,
      'handlerCount': handlers.length,
    });

    // Execute matching handlers in parallel (handlers are independent subscribers).
    final futures = handlers.map(
      (entry) => _safeHandle(entry.handler, entry.pattern, event),
    );
    await Future.wait(futures);

    return handlers.length;
  }

  /// Apply the interceptor chain using chain-of-responsibility pattern.
  ///
  /// Each interceptor receives the event and a [next] callback.
  /// Calling [next] passes control to the next interceptor in the chain.
  /// Returns `true` if the full chain completed, `false` if suppressed.
  Future<bool> _applyInterceptorChain(OpsEvent event, int index) async {
    if (index >= _interceptors.length) return true;

    var chainContinued = false;
    final interceptor = _interceptors[index];
    try {
      await interceptor(
        event,
        () async {
          chainContinued = await _applyInterceptorChain(event, index + 1);
        },
      );
    } catch (e, stack) {
      _logger.error('Interceptor failed', error: e, context: {'stackTrace': stack.toString()});
      return false;
    }
    return chainContinued;
  }

  /// Safely execute a handler, catching and reporting errors.
  Future<void> _safeHandle(
    EventHandler handler,
    String pattern,
    OpsEvent event,
  ) async {
    try {
      await handler(event);
    } catch (e, stack) {
      _logger.error(
        'Handler execution failed',
        error: e,
        context: {'stackTrace': stack.toString()},
      );

      if (onError != null) {
        onError!(event, pattern, e, stack);
      }
    }
  }

  /// Find all handlers whose patterns match the given event type.
  List<_HandlerEntry> _findHandlers(String eventType) {
    final matched = <_HandlerEntry>[];

    for (final entry in _handlers.entries) {
      if (_matchesPattern(eventType, entry.key)) {
        for (final handler in entry.value) {
          matched.add(_HandlerEntry(pattern: entry.key, handler: handler));
        }
      }
    }

    return matched;
  }

  /// Check if an event type matches a given pattern.
  ///
  /// Pattern matching rules:
  /// - Exact match: 'ops.pipeline.started' matches 'ops.pipeline.started'.
  /// - Trailing wildcard: 'ops.pipeline.*' matches any type with prefix 'ops.pipeline.'
  ///   and exactly one more segment.
  /// - Double wildcard: 'ops.**' matches any type starting with 'ops.'.
  /// - Global wildcard: '**' or '*' matches everything.
  bool _matchesPattern(String eventType, String pattern) {
    // Global wildcards.
    if (pattern == '*' || pattern == '**') return true;

    // Exact match.
    if (!pattern.contains('*')) return eventType == pattern;

    final patternSegments = pattern.split('.');
    final typeSegments = eventType.split('.');

    for (var i = 0; i < patternSegments.length; i++) {
      final seg = patternSegments[i];

      if (seg == '**') {
        // Double wildcard matches zero or more remaining segments.
        return true;
      }

      if (seg == '*') {
        // Single wildcard at the end matches exactly one more segment.
        if (i == patternSegments.length - 1) {
          return typeSegments.length == i + 1;
        }
        // Single wildcard in the middle matches one segment.
        if (i >= typeSegments.length) return false;
        continue;
      }

      if (i >= typeSegments.length) return false;
      if (seg != typeSegments[i]) return false;
    }

    return typeSegments.length == patternSegments.length;
  }

  /// Get all registered patterns (for diagnostics).
  List<String> get registeredPatterns => _handlers.keys.toList();

  /// Get handler count for a pattern.
  int handlerCount(String pattern) => _handlers[pattern]?.length ?? 0;

  /// Get total handler count across all patterns.
  int get totalHandlerCount =>
      _handlers.values.fold(0, (sum, list) => sum + list.length);
}

/// Internal entry pairing a handler with its registration pattern.
class _HandlerEntry {
  final String pattern;
  final EventHandler handler;

  const _HandlerEntry({
    required this.pattern,
    required this.handler,
  });
}
