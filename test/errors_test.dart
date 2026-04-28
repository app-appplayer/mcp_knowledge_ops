/// Errors Tests - Tests for error codes, exceptions, retry, and fallback.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // OpsErrorCategory
  // ═══════════════════════════════════════════════════════════════

  group('OpsErrorCategory', () {
    test('has all values', () {
      expect(OpsErrorCategory.values, containsAll([
        OpsErrorCategory.pipeline,
        OpsErrorCategory.workflow,
        OpsErrorCategory.gate,
        OpsErrorCategory.approval,
        OpsErrorCategory.execution,
      ]));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // OpsErrorCode
  // ═══════════════════════════════════════════════════════════════

  group('OpsErrorCode', () {
    test('fromCode returns correct code', () {
      final code = OpsErrorCode.fromCode('OPS-PIPE-001');
      expect(code, equals(OpsErrorCode.pipelineNotFound));
    });

    test('fromCode returns null for unknown', () {
      final code = OpsErrorCode.fromCode('UNKNOWN');
      expect(code, isNull);
    });

    test('byCategory returns pipeline codes', () {
      final codes = OpsErrorCode.byCategory(OpsErrorCategory.pipeline);
      expect(codes.length, equals(9));
      expect(codes, contains(OpsErrorCode.stageFailed));
    });

    test('byCategory returns gate codes', () {
      final codes = OpsErrorCode.byCategory(OpsErrorCategory.gate);
      expect(codes.length, equals(5));
    });

    test('toString includes code and display name', () {
      final s = OpsErrorCode.pipelineNotFound.toString();
      expect(s, contains('OPS-PIPE-001'));
      expect(s, contains('Pipeline Not Found'));
    });

    test('all codes have valid code strings', () {
      for (final code in OpsErrorCode.values) {
        // OPS-* for operations codes, PHIL-* for philosophy codes
        expect(code.code, anyOf(startsWith('OPS-'), startsWith('PHIL-')));
        expect(code.displayName, isNotEmpty);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // PipelineException
  // ═══════════════════════════════════════════════════════════════

  group('PipelineException', () {
    test('creation and properties', () {
      const ex = PipelineException(
        'Pipeline failed',
        code: 'OPS-PIPE-004',
        pipelineId: 'pipe-1',
        stageId: 'stage-2',
      );
      expect(ex.message, equals('Pipeline failed'));
      expect(ex.pipelineId, equals('pipe-1'));
      expect(ex.stageId, equals('stage-2'));
      expect(ex.retryable, isFalse);
      expect(ex.suggestedDelay, equals(Duration.zero));
    });

    test('toString', () {
      const ex = PipelineException(
        'Failed',
        pipelineId: 'pipe-1',
        stageId: 'stage-1',
      );
      expect(ex.toString(), contains('pipe-1'));
      expect(ex.toString(), contains('stage-1'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // StageException
  // ═══════════════════════════════════════════════════════════════

  group('StageException', () {
    test('is retryable by default', () {
      const ex = StageException('Stage failed', stageId: 's1');
      expect(ex.retryable, isTrue);
      expect(ex.suggestedDelay, equals(const Duration(seconds: 1)));
    });

    test('fromError factory', () {
      final ex = StageException.fromError(
        Exception('boom'),
        stageId: 's1',
        handlerId: 'handler-1',
      );
      expect(ex.stageId, equals('s1'));
      expect(ex.handlerId, equals('handler-1'));
      expect(ex.message, contains('boom'));
    });

    test('toString', () {
      const ex = StageException('Failed', stageId: 's1', handlerId: 'h1');
      expect(ex.toString(), contains('s1'));
      expect(ex.toString(), contains('h1'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // RetryableOpsException / PermanentOpsException
  // ═══════════════════════════════════════════════════════════════

  group('RetryableOpsException', () {
    test('is retryable', () {
      const ex = RetryableOpsException(
        'Temporary failure',
        attemptNumber: 2,
        nextRetryIn: Duration(seconds: 5),
      );
      expect(ex.retryable, isTrue);
      expect(ex.suggestedDelay, equals(const Duration(seconds: 5)));
      expect(ex.attemptNumber, equals(2));
    });

    test('toString', () {
      const ex = RetryableOpsException('Failed', attemptNumber: 3);
      expect(ex.toString(), contains('attempt=3'));
    });
  });

  group('PermanentOpsException', () {
    test('is not retryable', () {
      const ex = PermanentOpsException('Permanent failure');
      expect(ex.retryable, isFalse);
      expect(ex.suggestedDelay, equals(Duration.zero));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GateException
  // ═══════════════════════════════════════════════════════════════

  group('GateException', () {
    test('creation and properties', () {
      final ex = GateException(
        'Gate failed',
        gateId: 'g1',
        result: GateEvaluationResult(
          passed: false,
          evaluatedAt: DateTime(2024, 1, 1),
        ),
      );
      expect(ex.gateId, equals('g1'));
      expect(ex.result.passed, isFalse);
      expect(ex.retryable, isFalse);
    });

    test('toString', () {
      final ex = GateException(
        'Failed',
        gateId: 'g1',
        result: GateEvaluationResult(
          passed: false,
          evaluatedAt: DateTime(2024, 1, 1),
        ),
      );
      expect(ex.toString(), contains('g1'));
    });
  });

  group('GateEvaluationResult', () {
    test('with condition results', () {
      final result = GateEvaluationResult(
        passed: false,
        conditionResults: [
          const GateConditionResult(conditionId: 'c1', passed: true),
          const GateConditionResult(conditionId: 'c2', passed: false, actualValue: 50, expectedValue: 80),
        ],
        evaluatedAt: DateTime(2024, 1, 1),
      );
      expect(result.conditionResults.length, equals(2));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // OpsTimeoutException
  // ═══════════════════════════════════════════════════════════════

  group('OpsTimeoutException', () {
    test('is retryable', () {
      const ex = OpsTimeoutException(
        'Timed out',
        timeout: Duration(seconds: 30),
        operation: 'stage-1',
      );
      expect(ex.retryable, isTrue);
      expect(ex.suggestedDelay, equals(const Duration(seconds: 5)));
      expect(ex.timeout, equals(const Duration(seconds: 30)));
    });

    test('toString', () {
      const ex = OpsTimeoutException(
        'Timeout',
        timeout: Duration(seconds: 30),
        operation: 'op',
      );
      expect(ex.toString(), contains('30000ms'));
      expect(ex.toString(), contains('op'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // ResourceException
  // ═══════════════════════════════════════════════════════════════

  group('ResourceException', () {
    test('is retryable with 1 minute delay', () {
      const ex = ResourceException(
        'Storage unavailable',
        resourceType: 'kvStorage',
      );
      expect(ex.retryable, isTrue);
      expect(ex.suggestedDelay, equals(const Duration(minutes: 1)));
    });

    test('toString', () {
      const ex = ResourceException(
        'Missing',
        resourceType: 'llm',
        resourceId: 'primary',
      );
      expect(ex.toString(), contains('llm'));
      expect(ex.toString(), contains('primary'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // ValidationException
  // ═══════════════════════════════════════════════════════════════

  group('ValidationException', () {
    test('is not retryable', () {
      const ex = ValidationException(
        'Validation failed',
        errors: [
          ValidationError(field: 'name', message: 'required'),
          ValidationError(field: 'age', message: 'must be positive', value: -1),
        ],
      );
      expect(ex.retryable, isFalse);
      expect(ex.errors.length, equals(2));
    });

    test('toString includes error count', () {
      const ex = ValidationException(
        'Invalid',
        errors: [ValidationError(field: 'name', message: 'required')],
      );
      expect(ex.toString(), contains('1 error(s)'));
    });
  });

  group('ValidationError', () {
    test('toString', () {
      const err = ValidationError(field: 'email', message: 'invalid format');
      expect(err.toString(), equals('email: invalid format'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // CircuitOpenException
  // ═══════════════════════════════════════════════════════════════

  group('CircuitOpenException', () {
    test('creation and properties', () {
      final now = DateTime.now();
      final resetAt = now.add(const Duration(seconds: 30));
      final ex = CircuitOpenException(
        message: 'Circuit open',
        circuitName: 'factgraph',
        openedAt: now,
        resetAt: resetAt,
      );
      expect(ex.circuitName, equals('factgraph'));
      expect(ex.openedAt, equals(now));
      expect(ex.resetAt, equals(resetAt));
      expect(ex.message, equals('Circuit open'));
    });

    test('remainingTime returns non-negative duration', () {
      final past = DateTime.now().subtract(const Duration(seconds: 10));
      final ex = CircuitOpenException(
        message: 'Open',
        circuitName: 'test',
        openedAt: past,
        resetAt: past.add(const Duration(seconds: 5)),
      );
      expect(ex.remainingTime, equals(Duration.zero));
    });

    test('toString', () {
      final now = DateTime.now();
      final ex = CircuitOpenException(
        message: 'Open',
        circuitName: 'test',
        openedAt: now,
        resetAt: now.add(const Duration(seconds: 30)),
      );
      expect(ex.toString(), contains('test'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // RetryExecutor
  // ═══════════════════════════════════════════════════════════════

  group('RetryExecutor', () {
    test('succeeds on first attempt', () async {
      final result = await RetryExecutor.execute<String>(
        operation: () async => 'success',
      );
      expect(result, equals('success'));
    });

    test('retries and succeeds', () async {
      var attempts = 0;
      final result = await RetryExecutor.execute<String>(
        operation: () async {
          attempts++;
          if (attempts < 3) throw Exception('fail');
          return 'success';
        },
        maxAttempts: 3,
        initialDelay: const Duration(milliseconds: 1),
        jitterFactor: 0.0,
      );
      expect(result, equals('success'));
      expect(attempts, equals(3));
    });

    test('throws after max attempts', () async {
      expect(
        () => RetryExecutor.execute<String>(
          operation: () async => throw Exception('always fail'),
          maxAttempts: 2,
          initialDelay: const Duration(milliseconds: 1),
          jitterFactor: 0.0,
        ),
        throwsA(isA<RetryableOpsException>()),
      );
    });

    test('stops retrying for non-retryable OpsException', () async {
      expect(
        () => RetryExecutor.execute<String>(
          operation: () async {
            throw const PermanentOpsException('permanent');
          },
          maxAttempts: 5,
          initialDelay: const Duration(milliseconds: 1),
        ),
        throwsA(isA<RetryableOpsException>()),
      );
    });

    test('calls onRetry callback', () async {
      final retryAttempts = <int>[];
      try {
        await RetryExecutor.execute<String>(
          operation: () async => throw Exception('fail'),
          maxAttempts: 3,
          initialDelay: const Duration(milliseconds: 1),
          jitterFactor: 0.0,
          onRetry: (attempt, error, delay) {
            retryAttempts.add(attempt);
          },
        );
      } catch (_) {}
      expect(retryAttempts, equals([1, 2]));
    });

    test('respects isRetryable filter', () async {
      expect(
        () => RetryExecutor.execute<String>(
          operation: () async {
            throw const FormatException('bad');
          },
          maxAttempts: 5,
          initialDelay: const Duration(milliseconds: 1),
          isRetryable: (e) => e is! FormatException,
        ),
        throwsA(isA<RetryableOpsException>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // FallbackHandler
  // ═══════════════════════════════════════════════════════════════

  group('FallbackHandler', () {
    test('defaultValue strategy returns default on error', () async {
      final handler = FallbackHandler<String>(
        strategy: FallbackStrategy.defaultValue,
        defaultValue: 'fallback',
      );

      final result = await handler.executeWithFallback(
        () async => throw Exception('fail'),
      );
      expect(result, equals('fallback'));
    });

    test('alternative strategy calls alternative on error', () async {
      final handler = FallbackHandler<String>(
        strategy: FallbackStrategy.alternative,
        alternative: () async => 'alt-result',
      );

      final result = await handler.executeWithFallback(
        () async => throw Exception('fail'),
      );
      expect(result, equals('alt-result'));
    });

    test('returns operation result on success', () async {
      final handler = FallbackHandler<String>(
        strategy: FallbackStrategy.defaultValue,
        defaultValue: 'fallback',
      );

      final result = await handler.executeWithFallback(
        () async => 'original',
      );
      expect(result, equals('original'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // ErrorAggregator
  // ═══════════════════════════════════════════════════════════════

  group('ErrorAggregator', () {
    test('starts with no errors', () {
      final agg = ErrorAggregator();
      expect(agg.hasErrors, isFalse);
      expect(agg.toAggregateError(), isNull);
    });

    test('add and hasErrors', () {
      final agg = ErrorAggregator();
      agg.add('op1', Exception('fail'));
      expect(agg.hasErrors, isTrue);
      expect(agg.errors.length, equals(1));
    });

    test('toAggregateError creates AggregateError', () {
      final agg = ErrorAggregator();
      agg.add('op1', Exception('fail1'));
      agg.add('op2', Exception('fail2'));

      final error = agg.toAggregateError();
      expect(error, isNotNull);
      expect(error!.errors.length, equals(2));
      expect(error.toString(), contains('2 error(s)'));
    });

    test('clear removes all errors', () {
      final agg = ErrorAggregator();
      agg.add('op1', Exception('fail'));
      agg.clear();
      expect(agg.hasErrors, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // ErrorResponse
  // ═══════════════════════════════════════════════════════════════

  group('ErrorResponse', () {
    test('fromException creates response', () {
      const ex = StageException('Stage failed', stageId: 's1', code: 'OPS-PIPE-004');
      final response = ErrorResponse.fromException(ex);
      expect(response.code, equals('OPS-PIPE-004'));
      expect(response.retryable, isTrue);
      expect(response.retryAfterMs, equals(1000));
    });

    test('toJson', () {
      final response = ErrorResponse(
        code: 'ERR-001',
        message: 'Something failed',
        retryable: false,
        timestamp: DateTime(2024, 1, 1),
      );
      final json = response.toJson();
      expect(json['error']['code'], equals('ERR-001'));
      expect(json['error']['retryable'], isFalse);
      expect(json['timestamp'], contains('2024'));
    });

    test('fromException with non-retryable exception', () {
      const ex = PermanentOpsException('Permanent', code: 'OPS-EXEC-006');
      final response = ErrorResponse.fromException(ex);
      expect(response.retryable, isFalse);
      expect(response.retryAfterMs, isNull);
    });
  });
}
