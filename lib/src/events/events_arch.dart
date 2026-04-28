/// Events Architecture - Barrel export for all event architecture files.
///
/// Provides a single import point for the complete event architecture:
/// models, publishing, subscribing, routing, storage, dead letter queue,
/// typed events, replay, metrics, tracing, integrations, and configuration.
library;

export 'ops_event.dart';
export 'event_publisher.dart';
export 'event_subscriber.dart';
export 'event_router.dart';
export 'event_store.dart';
export 'event_reliability.dart';
export 'dead_letter_queue.dart';
export 'typed_events.dart';
export 'event_replayer.dart';
export 'event_metrics.dart';
export 'event_tracing.dart';
export 'event_integrations.dart';
export 'event_config.dart';
