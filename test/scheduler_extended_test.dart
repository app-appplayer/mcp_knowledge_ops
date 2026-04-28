import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  group('SchedulerMcpTools', () {
    test('allSchemas() returns 8 schemas', () {
      final schemas = SchedulerMcpTools.allSchemas();

      expect(schemas.length, equals(8));
    });

    test('each schema has name and input keys', () {
      final schemas = SchedulerMcpTools.allSchemas();

      for (final schema in schemas) {
        expect(schema.containsKey('name'), isTrue,
            reason: 'Schema missing "name" key: $schema');
        expect(schema.containsKey('input'), isTrue,
            reason: 'Schema missing "input" key: $schema');
        expect(schema['name'], isA<String>());
      }
    });
  });

  group('ScheduleConfig', () {
    test('defaults are correct', () {
      const config = ScheduleConfig();

      expect(config.enabled, isTrue);
      expect(config.priority, equals(5));
      expect(config.maxConcurrent, equals(1));
      expect(config.deduplicate, isFalse);
      expect(config.dedupeWindow, isNull);
      expect(config.timeout, isNull);
      expect(config.retryOnFailure, isFalse);
      expect(config.retryConfig, isNull);
      expect(config.tags, isEmpty);
      expect(config.metadata, isEmpty);
    });

    test('copyWith changes specified fields', () {
      const original = ScheduleConfig();
      final modified = original.copyWith(
        enabled: false,
        priority: 8,
        maxConcurrent: 3,
        tags: ['tag1', 'tag2'],
      );

      expect(modified.enabled, isFalse);
      expect(modified.priority, equals(8));
      expect(modified.maxConcurrent, equals(3));
      expect(modified.tags, equals(['tag1', 'tag2']));
      // Unchanged fields retain defaults
      expect(modified.deduplicate, isFalse);
      expect(modified.retryOnFailure, isFalse);
    });
  });

  group('ScheduleRetryConfig', () {
    test('delayForAttempt calculates exponential backoff', () {
      const config = ScheduleRetryConfig(
        initialDelay: Duration(seconds: 1),
        backoffMultiplier: 2.0,
        maxDelay: Duration(minutes: 5),
      );

      // Attempt 0 returns initialDelay per implementation
      final delay0 = config.delayForAttempt(0);
      expect(delay0, equals(const Duration(seconds: 1)));

      // Attempt 1: initialDelay * 2^0 = 1s
      final delay1 = config.delayForAttempt(1);
      expect(delay1, equals(const Duration(seconds: 1)));

      // Attempt 2: initialDelay * 2^1 = 2s
      final delay2 = config.delayForAttempt(2);
      expect(delay2, equals(const Duration(seconds: 2)));

      // Attempt 3: initialDelay * 2^2 = 4s
      final delay3 = config.delayForAttempt(3);
      expect(delay3, equals(const Duration(seconds: 4)));
    });

    test('delayForAttempt respects maxDelay cap', () {
      const config = ScheduleRetryConfig(
        initialDelay: Duration(seconds: 1),
        backoffMultiplier: 2.0,
        maxDelay: Duration(seconds: 3),
      );

      // Attempt 3: would be 4s but capped at 3s
      final delay = config.delayForAttempt(3);
      expect(delay.inMilliseconds, lessThanOrEqualTo(3000));
    });
  });
}
