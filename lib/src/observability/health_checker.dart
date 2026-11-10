/// Health Checker - Health checking for observability.
///
/// Provides health check capabilities for pipeline and workflow execution.
library;

import 'dart:async' show TimeoutException;

/// Health status.
enum HealthStatus {
  healthy,
  degraded,
  unhealthy,
}

/// Health check type.
enum HealthCheckType {
  liveness,
  readiness,
  dependency,
}

/// Health check definition.
class HealthCheck {
  /// Check ID.
  final String id;

  /// Check name.
  final String name;

  /// Check description.
  final String description;

  /// Check type.
  final HealthCheckType type;

  /// Check function.
  final Future<HealthCheckResult> Function() check;

  /// Timeout for the check.
  final Duration timeout;

  /// Interval between checks.
  final Duration interval;

  /// Whether this check is critical.
  final bool critical;

  HealthCheck({
    required this.id,
    required this.name,
    this.description = '',
    this.type = HealthCheckType.liveness,
    required this.check,
    this.timeout = const Duration(seconds: 5),
    this.interval = const Duration(seconds: 30),
    this.critical = false,
  });
}

/// Health check result.
class HealthCheckResult {
  /// Check ID.
  final String checkId;

  /// Result status.
  final HealthStatus status;

  /// Result message.
  final String message;

  /// Additional details.
  final Map<String, dynamic> details;

  /// Duration of the check.
  final Duration duration;

  /// Timestamp when the check was performed.
  final DateTime checkedAt;

  const HealthCheckResult({
    required this.checkId,
    required this.status,
    this.message = '',
    this.details = const {},
    required this.duration,
    required this.checkedAt,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'checkId': checkId,
        'status': status.name,
        if (message.isNotEmpty) 'message': message,
        if (details.isNotEmpty) 'details': details,
        'duration': duration.inMilliseconds,
        'checkedAt': checkedAt.toIso8601String(),
      };
}

/// Health report containing results from all checks.
class HealthReport {
  /// Overall status.
  final HealthStatus status;

  /// Individual check results.
  final List<HealthCheckResult> checks;

  /// Report timestamp.
  final DateTime timestamp;

  const HealthReport({
    required this.status,
    required this.checks,
    required this.timestamp,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'status': status.name,
        'checks': checks.map((c) => c.toJson()).toList(),
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Health checker for running health checks.
class HealthChecker {
  /// Registered health checks.
  final List<HealthCheck> _checks = [];

  /// Last run results.
  final Map<String, HealthCheckResult> _lastResults = {};

  /// Get registered checks.
  List<HealthCheck> get checks => List.unmodifiable(_checks);

  /// Add a health check.
  void addCheck(HealthCheck check) {
    _checks.add(check);
  }

  /// Remove a health check by ID.
  void removeCheck(String checkId) {
    _checks.removeWhere((c) => c.id == checkId);
    _lastResults.remove(checkId);
  }

  /// Run all registered health checks.
  Future<HealthReport> runAll() async {
    final results = <HealthCheckResult>[];

    for (final check in _checks) {
      final result = await _executeCheck(check);
      results.add(result);
      _lastResults[check.id] = result;
    }

    final overallStatus = _computeOverallStatus(results);

    return HealthReport(
      status: overallStatus,
      checks: results,
      timestamp: DateTime.now(),
    );
  }

  /// Run a specific health check by ID.
  Future<HealthCheckResult> runCheck(String checkId) async {
    final check = _checks.where((c) => c.id == checkId).firstOrNull;
    if (check == null) {
      return HealthCheckResult(
        checkId: checkId,
        status: HealthStatus.unhealthy,
        message: 'Health check not found: $checkId',
        duration: Duration.zero,
        checkedAt: DateTime.now(),
      );
    }

    final result = await _executeCheck(check);
    _lastResults[check.id] = result;
    return result;
  }

  /// Get overall health status based on last run results.
  HealthStatus getStatus() {
    if (_lastResults.isEmpty) {
      return HealthStatus.healthy;
    }
    return _computeOverallStatus(_lastResults.values.toList());
  }

  /// Execute a single health check with timeout handling.
  Future<HealthCheckResult> _executeCheck(HealthCheck check) async {
    final startTime = DateTime.now();

    try {
      final result = await check.check().timeout(check.timeout);
      return result;
    } on TimeoutException {
      final duration = DateTime.now().difference(startTime);
      return HealthCheckResult(
        checkId: check.id,
        status: HealthStatus.unhealthy,
        message: 'Health check timed out after ${check.timeout.inSeconds}s',
        duration: duration,
        checkedAt: startTime,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      return HealthCheckResult(
        checkId: check.id,
        status: HealthStatus.unhealthy,
        message: 'Health check failed: $e',
        duration: duration,
        checkedAt: startTime,
      );
    }
  }

  /// Compute overall status from a list of results.
  ///
  /// If any critical check is unhealthy, overall is unhealthy.
  /// If any check is degraded, overall is degraded.
  /// Otherwise, overall is healthy.
  HealthStatus _computeOverallStatus(List<HealthCheckResult> results) {
    var hasUnhealthy = false;
    var hasDegraded = false;

    for (final result in results) {
      final check = _checks.where((c) => c.id == result.checkId).firstOrNull;
      final isCritical = check?.critical ?? false;

      if (result.status == HealthStatus.unhealthy) {
        if (isCritical) {
          return HealthStatus.unhealthy;
        }
        hasUnhealthy = true;
      } else if (result.status == HealthStatus.degraded) {
        hasDegraded = true;
      }
    }

    if (hasUnhealthy || hasDegraded) {
      return HealthStatus.degraded;
    }

    return HealthStatus.healthy;
  }
}
