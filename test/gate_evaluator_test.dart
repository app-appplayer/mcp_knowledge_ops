/// GateEvaluator Tests - Tests for quality gate evaluation.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

import 'test_helpers.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // GateEvaluator
  // ═══════════════════════════════════════════════════════════════

  group('GateEvaluator', () {
    late GateEvaluator evaluator;

    setUp(() {
      evaluator = GateEvaluator();
    });

    // ─────────────────────────────────────────────────────────────
    // Threshold conditions
    // ─────────────────────────────────────────────────────────────

    group('threshold conditions', () {
      test('passes when value meets threshold (>=)', () async {
        final context = testExecutionContext(
          state: {
            'stages': {
              'stage-1': {'output': {'score': 0.95}, 'status': 'completed'}
            }
          },
        );

        final gate = Gate(
          id: 'gate-1',
          name: 'Quality Gate',
          afterStage: 'stage-1',
          conditions: [
            GateCondition(
              type: ConditionType.threshold,
              metric: r'${stages.stage-1.output.score}',
              operator: '>=',
              value: 0.8,
            ),
          ],
        );

        final result = await evaluator.evaluate(gate, context);
        expect(result.passed, isTrue);
        expect(result.gateId, equals('gate-1'));
        expect(result.conditionResults.length, equals(1));
      });

      test('fails when value below threshold', () async {
        final context = testExecutionContext(
          state: {
            'stages': {
              'stage-1': {'output': {'score': 0.5}, 'status': 'completed'}
            }
          },
        );

        final gate = Gate(
          id: 'gate-2',
          name: 'Quality Gate',
          afterStage: 'stage-1',
          conditions: [
            GateCondition(
              type: ConditionType.threshold,
              metric: r'${stages.stage-1.output.score}',
              operator: '>=',
              value: 0.8,
            ),
          ],
        );

        final result = await evaluator.evaluate(gate, context);
        expect(result.passed, isFalse);
        expect(result.conditionResults.first.passed, isFalse);
        expect(result.conditionResults.first.message, isNotNull);
      });

      test('fails when metric not found', () async {
        final context = testExecutionContext();

        final gate = Gate(
          id: 'gate-3',
          name: 'Missing Metric Gate',
          afterStage: 'stage-1',
          conditions: [
            GateCondition(
              type: ConditionType.threshold,
              metric: r'${stages.nonexistent.output.score}',
              operator: '>=',
              value: 0.8,
            ),
          ],
        );

        final result = await evaluator.evaluate(gate, context);
        expect(result.passed, isFalse);
      });

      test('fails when metric has no metric field', () async {
        final context = testExecutionContext();

        final gate = Gate(
          id: 'gate-no-metric',
          name: 'No Metric Gate',
          afterStage: 'stage-1',
          conditions: [
            const GateCondition(
              type: ConditionType.threshold,
              operator: '>=',
              value: 0.8,
            ),
          ],
        );

        final result = await evaluator.evaluate(gate, context);
        expect(result.passed, isFalse);
        expect(result.conditionResults.first.message,
            contains('requires a metric'));
      });

      test('supports comparison operators', () async {
        final context = testExecutionContext(
          state: {
            'stages': {
              'stage-1': {'output': {'count': 10}, 'status': 'completed'}
            }
          },
        );

        // Test > operator
        final gateGt = Gate(
          id: 'gate-gt',
          name: 'Greater Than',
          afterStage: 'stage-1',
          conditions: [
            GateCondition(
              type: ConditionType.threshold,
              metric: r'${stages.stage-1.output.count}',
              operator: '>',
              value: 5,
            ),
          ],
        );
        expect((await evaluator.evaluate(gateGt, context)).passed, isTrue);

        // Test < operator
        final gateLt = Gate(
          id: 'gate-lt',
          name: 'Less Than',
          afterStage: 'stage-1',
          conditions: [
            GateCondition(
              type: ConditionType.threshold,
              metric: r'${stages.stage-1.output.count}',
              operator: '<',
              value: 20,
            ),
          ],
        );
        expect((await evaluator.evaluate(gateLt, context)).passed, isTrue);

        // Test == operator
        final gateEq = Gate(
          id: 'gate-eq',
          name: 'Equal',
          afterStage: 'stage-1',
          conditions: [
            GateCondition(
              type: ConditionType.threshold,
              metric: r'${stages.stage-1.output.count}',
              operator: '==',
              value: 10,
            ),
          ],
        );
        expect((await evaluator.evaluate(gateEq, context)).passed, isTrue);

        // Test != operator
        final gateNe = Gate(
          id: 'gate-ne',
          name: 'Not Equal',
          afterStage: 'stage-1',
          conditions: [
            GateCondition(
              type: ConditionType.threshold,
              metric: r'${stages.stage-1.output.count}',
              operator: '!=',
              value: 5,
            ),
          ],
        );
        expect((await evaluator.evaluate(gateNe, context)).passed, isTrue);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Expression conditions
    // ─────────────────────────────────────────────────────────────

    group('expression conditions', () {
      test('passes when expression evaluates to true', () async {
        final context = testExecutionContext(
          state: {'input': 'test-data'},
        );

        final gate = Gate(
          id: 'gate-expr-1',
          name: 'Expression Gate',
          afterStage: 'stage-1',
          conditions: [
            const GateCondition(
              type: ConditionType.expression,
              expression: 'true',
            ),
          ],
        );

        final result = await evaluator.evaluate(gate, context);
        expect(result.passed, isTrue);
      });

      test('fails when expression evaluates to false', () async {
        final context = testExecutionContext();

        final gate = Gate(
          id: 'gate-expr-2',
          name: 'False Expression Gate',
          afterStage: 'stage-1',
          conditions: [
            const GateCondition(
              type: ConditionType.expression,
              expression: 'false',
            ),
          ],
        );

        final result = await evaluator.evaluate(gate, context);
        expect(result.passed, isFalse);
      });

      test('fails when expression is null', () async {
        final context = testExecutionContext();

        final gate = Gate(
          id: 'gate-expr-null',
          name: 'Null Expression Gate',
          afterStage: 'stage-1',
          conditions: [
            const GateCondition(
              type: ConditionType.expression,
            ),
          ],
        );

        final result = await evaluator.evaluate(gate, context);
        expect(result.passed, isFalse);
        expect(result.conditionResults.first.message,
            contains('requires an expression'));
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Multiple conditions
    // ─────────────────────────────────────────────────────────────

    group('multiple conditions', () {
      test('all conditions must pass for gate to pass', () async {
        final context = testExecutionContext(
          state: {
            'stages': {
              'stage-1': {
                'output': {'score': 0.9, 'count': 100},
                'status': 'completed'
              }
            }
          },
        );

        final gate = Gate(
          id: 'gate-multi',
          name: 'Multi-condition Gate',
          afterStage: 'stage-1',
          conditions: [
            GateCondition(
              type: ConditionType.threshold,
              metric: r'${stages.stage-1.output.score}',
              operator: '>=',
              value: 0.8,
            ),
            const GateCondition(
              type: ConditionType.expression,
              expression: 'true',
            ),
          ],
        );

        final result = await evaluator.evaluate(gate, context);
        expect(result.passed, isTrue);
        expect(result.conditionResults.length, equals(2));
        expect(result.conditionResults.every((r) => r.passed), isTrue);
      });

      test('gate fails if any condition fails', () async {
        final context = testExecutionContext(
          state: {
            'stages': {
              'stage-1': {'output': {'score': 0.5}, 'status': 'completed'}
            }
          },
        );

        final gate = Gate(
          id: 'gate-partial-fail',
          name: 'Partial Fail Gate',
          afterStage: 'stage-1',
          conditions: [
            GateCondition(
              type: ConditionType.threshold,
              metric: r'${stages.stage-1.output.score}',
              operator: '>=',
              value: 0.8,
            ),
            const GateCondition(
              type: ConditionType.expression,
              expression: 'true',
            ),
          ],
        );

        final result = await evaluator.evaluate(gate, context);
        expect(result.passed, isFalse);
      });

      test('block failure mode causes early exit on first failure', () async {
        final context = testExecutionContext();

        final gate = Gate(
          id: 'gate-block',
          name: 'Block Gate',
          afterStage: 'stage-1',
          onFailure: GateFailure.block,
          conditions: [
            const GateCondition(
              type: ConditionType.expression,
              expression: 'false',
            ),
            const GateCondition(
              type: ConditionType.expression,
              expression: 'true',
            ),
          ],
        );

        final result = await evaluator.evaluate(gate, context);
        expect(result.passed, isFalse);
        // With block mode, should stop after first failure
        expect(result.conditionResults.length, equals(1));
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Approval conditions
    // ─────────────────────────────────────────────────────────────

    group('approval conditions', () {
      test('fails when approval not found in context', () async {
        final context = testExecutionContext();

        final gate = Gate(
          id: 'gate-approval',
          name: 'Approval Gate',
          afterStage: 'stage-1',
          conditions: [
            const GateCondition(
              type: ConditionType.approval,
              approvers: ['admin'],
            ),
          ],
        );

        final result = await evaluator.evaluate(gate, context);
        expect(result.passed, isFalse);
        expect(result.conditionResults.first.message,
            contains('not found'));
      });

      test('passes when approval is present and approved', () async {
        final context = testExecutionContext(
          state: {
            'approvals.approval_0': {
              'approved': true,
              'approver': 'admin',
            }
          },
        );

        final gate = Gate(
          id: 'gate-approved',
          name: 'Approval Gate',
          afterStage: 'stage-1',
          conditions: [
            const GateCondition(
              type: ConditionType.approval,
              approvers: ['admin'],
            ),
          ],
        );

        final result = await evaluator.evaluate(gate, context);
        expect(result.passed, isTrue);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // GateResult metadata
    // ─────────────────────────────────────────────────────────────

    group('GateResult', () {
      test('includes evaluatedAt timestamp', () async {
        final context = testExecutionContext();

        final gate = Gate(
          id: 'gate-time',
          name: 'Timed Gate',
          afterStage: 'stage-1',
          conditions: [
            const GateCondition(
              type: ConditionType.expression,
              expression: 'true',
            ),
          ],
        );

        final result = await evaluator.evaluate(gate, context);
        expect(result.evaluatedAt, isA<DateTime>());
      });

      test('includes duration', () async {
        final context = testExecutionContext();

        final gate = Gate(
          id: 'gate-duration',
          name: 'Duration Gate',
          afterStage: 'stage-1',
          conditions: [
            const GateCondition(
              type: ConditionType.expression,
              expression: 'true',
            ),
          ],
        );

        final result = await evaluator.evaluate(gate, context);
        expect(result.duration, isNotNull);
      });

      test('GateResult.passed factory creates passing result', () {
        final result = GateResult.passed('gate-1', [
          ConditionResult.passed('cond-1'),
        ]);
        expect(result.passed, isTrue);
        expect(result.gateId, equals('gate-1'));
        expect(result.conditionResults.length, equals(1));
      });

      test('GateResult.failed factory creates failing result', () {
        final result = GateResult.failed('gate-1', [
          ConditionResult.failed('cond-1', message: 'Failed'),
        ]);
        expect(result.passed, isFalse);
        expect(result.gateId, equals('gate-1'));
      });
    });

    // ─────────────────────────────────────────────────────────────
    // ConditionResult
    // ─────────────────────────────────────────────────────────────

    group('ConditionResult', () {
      test('passed factory creates passing result', () {
        final result = ConditionResult.passed('c-1', message: 'All good');
        expect(result.passed, isTrue);
        expect(result.conditionId, equals('c-1'));
        expect(result.message, equals('All good'));
      });

      test('failed factory creates failing result with details', () {
        final result = ConditionResult.failed(
          'c-1',
          actual: 0.5,
          expected: 0.8,
          message: 'Below threshold',
        );
        expect(result.passed, isFalse);
        expect(result.actual, equals(0.5));
        expect(result.expected, equals(0.8));
        expect(result.message, equals('Below threshold'));
      });

      test('toJson serializes correctly', () {
        final result = ConditionResult(
          conditionId: 'c-1',
          passed: true,
          actual: 0.95,
          expected: 0.8,
        );
        final json = result.toJson();
        expect(json['conditionId'], equals('c-1'));
        expect(json['passed'], isTrue);
        expect(json['actual'], equals(0.95));
        expect(json['expected'], equals(0.8));
      });
    });
  });
}
