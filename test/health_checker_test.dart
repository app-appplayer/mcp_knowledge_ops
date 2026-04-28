/// Health Checker Tests - Tests for HealthChecker, HealthCheck,
/// HealthCheckResult, and HealthReport.
library;

import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // HealthChecker
  // ═══════════════════════════════════════════════════════════════

  group('HealthChecker', () {
    late HealthChecker checker;

    setUp(() {
      checker = HealthChecker();
    });

    test('addCheck() registers health check', () {
      checker.addCheck(HealthCheck(
        id: 'check-1',
        name: 'Database',
        check: () async => HealthCheckResult(
          checkId: 'check-1',
          status: HealthStatus.healthy,
          duration: Duration.zero,
          checkedAt: DateTime.now(),
        ),
      ));

      expect(checker.checks.length, equals(1));
      expect(checker.checks.first.id, equals('check-1'));
    });

    test('removeCheck() removes check by ID', () {
      checker.addCheck(HealthCheck(
        id: 'check-1',
        name: 'Database',
        check: () async => HealthCheckResult(
          checkId: 'check-1',
          status: HealthStatus.healthy,
          duration: Duration.zero,
          checkedAt: DateTime.now(),
        ),
      ));

      checker.removeCheck('check-1');
      expect(checker.checks, isEmpty);
    });

    test('runAll() runs all checks and returns report', () async {
      checker.addCheck(HealthCheck(
        id: 'db',
        name: 'Database',
        check: () async => HealthCheckResult(
          checkId: 'db',
          status: HealthStatus.healthy,
          message: 'Connected',
          duration: const Duration(milliseconds: 10),
          checkedAt: DateTime.now(),
        ),
      ));
      checker.addCheck(HealthCheck(
        id: 'cache',
        name: 'Cache',
        check: () async => HealthCheckResult(
          checkId: 'cache',
          status: HealthStatus.healthy,
          message: 'Available',
          duration: const Duration(milliseconds: 5),
          checkedAt: DateTime.now(),
        ),
      ));

      final report = await checker.runAll();

      expect(report.checks.length, equals(2));
      expect(report.status, equals(HealthStatus.healthy));
      expect(report.timestamp, isNotNull);
    });

    test('healthy check returns healthy status', () async {
      checker.addCheck(HealthCheck(
        id: 'healthy-svc',
        name: 'Healthy Service',
        check: () async => HealthCheckResult(
          checkId: 'healthy-svc',
          status: HealthStatus.healthy,
          message: 'All good',
          duration: Duration.zero,
          checkedAt: DateTime.now(),
        ),
      ));

      final report = await checker.runAll();
      expect(report.status, equals(HealthStatus.healthy));
      expect(report.checks.first.status, equals(HealthStatus.healthy));
    });

    test('failed non-critical check returns degraded status', () async {
      checker.addCheck(HealthCheck(
        id: 'healthy-svc',
        name: 'Healthy Service',
        check: () async => HealthCheckResult(
          checkId: 'healthy-svc',
          status: HealthStatus.healthy,
          duration: Duration.zero,
          checkedAt: DateTime.now(),
        ),
      ));
      checker.addCheck(HealthCheck(
        id: 'unhealthy-svc',
        name: 'Unhealthy Service',
        critical: false,
        check: () async => HealthCheckResult(
          checkId: 'unhealthy-svc',
          status: HealthStatus.unhealthy,
          message: 'Connection failed',
          duration: Duration.zero,
          checkedAt: DateTime.now(),
        ),
      ));

      final report = await checker.runAll();
      expect(report.status, equals(HealthStatus.degraded));
    });

    test('failed critical check returns unhealthy status', () async {
      checker.addCheck(HealthCheck(
        id: 'critical-db',
        name: 'Critical Database',
        critical: true,
        check: () async => HealthCheckResult(
          checkId: 'critical-db',
          status: HealthStatus.unhealthy,
          message: 'Database down',
          duration: Duration.zero,
          checkedAt: DateTime.now(),
        ),
      ));

      final report = await checker.runAll();
      expect(report.status, equals(HealthStatus.unhealthy));
    });

    test('degraded check results in degraded overall', () async {
      checker.addCheck(HealthCheck(
        id: 'degraded-svc',
        name: 'Degraded Service',
        check: () async => HealthCheckResult(
          checkId: 'degraded-svc',
          status: HealthStatus.degraded,
          message: 'Slow responses',
          duration: Duration.zero,
          checkedAt: DateTime.now(),
        ),
      ));

      final report = await checker.runAll();
      expect(report.status, equals(HealthStatus.degraded));
    });

    test('runCheck() runs single check by ID', () async {
      checker.addCheck(HealthCheck(
        id: 'target',
        name: 'Target Check',
        check: () async => HealthCheckResult(
          checkId: 'target',
          status: HealthStatus.healthy,
          message: 'OK',
          duration: const Duration(milliseconds: 1),
          checkedAt: DateTime.now(),
        ),
      ));
      checker.addCheck(HealthCheck(
        id: 'other',
        name: 'Other Check',
        check: () async => HealthCheckResult(
          checkId: 'other',
          status: HealthStatus.unhealthy,
          duration: Duration.zero,
          checkedAt: DateTime.now(),
        ),
      ));

      final result = await checker.runCheck('target');

      expect(result.checkId, equals('target'));
      expect(result.status, equals(HealthStatus.healthy));
    });

    test('runCheck() returns unhealthy for unknown check ID', () async {
      final result = await checker.runCheck('nonexistent');

      expect(result.status, equals(HealthStatus.unhealthy));
      expect(result.message, contains('not found'));
    });

    test('getStatus() returns healthy before any runs', () {
      expect(checker.getStatus(), equals(HealthStatus.healthy));
    });

    test('getStatus() returns status based on last run', () async {
      checker.addCheck(HealthCheck(
        id: 'check-1',
        name: 'Check',
        check: () async => HealthCheckResult(
          checkId: 'check-1',
          status: HealthStatus.degraded,
          duration: Duration.zero,
          checkedAt: DateTime.now(),
        ),
      ));

      await checker.runAll();
      expect(checker.getStatus(), equals(HealthStatus.degraded));
    });

    test('check with exception returns unhealthy', () async {
      checker.addCheck(HealthCheck(
        id: 'failing',
        name: 'Failing Check',
        check: () async => throw Exception('connection refused'),
      ));

      final report = await checker.runAll();
      expect(report.checks.first.status, equals(HealthStatus.unhealthy));
      expect(report.checks.first.message, contains('connection refused'));
    });

    test('check with timeout returns unhealthy', () async {
      checker.addCheck(HealthCheck(
        id: 'slow',
        name: 'Slow Check',
        timeout: const Duration(milliseconds: 100),
        check: () async {
          await Future<void>.delayed(const Duration(seconds: 5));
          return HealthCheckResult(
            checkId: 'slow',
            status: HealthStatus.healthy,
            duration: Duration.zero,
            checkedAt: DateTime.now(),
          );
        },
      ));

      final report = await checker.runAll();
      expect(report.checks.first.status, equals(HealthStatus.unhealthy));
      expect(report.checks.first.message, contains('timed out'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // HealthCheckResult
  // ═══════════════════════════════════════════════════════════════

  group('HealthCheckResult', () {
    test('toJson() serializes correctly', () {
      final result = HealthCheckResult(
        checkId: 'db',
        status: HealthStatus.healthy,
        message: 'Connected successfully',
        details: {'latency_ms': 5},
        duration: const Duration(milliseconds: 10),
        checkedAt: DateTime(2024, 1, 1),
      );

      final json = result.toJson();
      expect(json['checkId'], equals('db'));
      expect(json['status'], equals('healthy'));
      expect(json['message'], equals('Connected successfully'));
      expect(json['details'], equals({'latency_ms': 5}));
      expect(json['duration'], equals(10));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // HealthReport
  // ═══════════════════════════════════════════════════════════════

  group('HealthReport', () {
    test('toJson() serializes correctly', () {
      final report = HealthReport(
        status: HealthStatus.healthy,
        checks: [
          HealthCheckResult(
            checkId: 'db',
            status: HealthStatus.healthy,
            duration: const Duration(milliseconds: 5),
            checkedAt: DateTime(2024, 1, 1),
          ),
        ],
        timestamp: DateTime(2024, 1, 1),
      );

      final json = report.toJson();
      expect(json['status'], equals('healthy'));
      expect((json['checks'] as List).length, equals(1));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Enums
  // ═══════════════════════════════════════════════════════════════

  group('Health enums', () {
    test('HealthStatus has all values', () {
      expect(HealthStatus.values,
          containsAll([HealthStatus.healthy, HealthStatus.degraded,
              HealthStatus.unhealthy]));
    });

    test('HealthCheckType has all values', () {
      expect(HealthCheckType.values,
          containsAll([HealthCheckType.liveness, HealthCheckType.readiness,
              HealthCheckType.dependency]));
    });
  });
}
