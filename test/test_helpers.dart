/// Test Helpers - Shared mocks and stubs for mcp_knowledge_ops tests.
///
/// Per REDESIGN-PLAN.md Phase 7 (no-legacy) this module provides mock
/// implementations for the capability-named standard ports and a
/// [TestOpsPorts] factory that assembles an [OpsPorts] with all mocks
/// wired.
library;

import 'dart:async';

import 'package:mcp_bundle/src/ports/philosophy_port.dart' as phil;
import 'package:mcp_bundle/src/ports/audit_port.dart' as port_audit;
import 'package:mcp_bundle/src/ports/runbook_port.dart' as port_runbook;
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

// ═══════════════════════════════════════════════════════════════════
// FactsPort Mock
// ═══════════════════════════════════════════════════════════════════

class MockFactsPort implements FactsPort {
  final List<String> calls = [];
  List<FactRecord> queryResult = [];
  final List<FactRecord> written = [];
  FactRecord? getResult;

  @override
  Future<List<FactRecord>> queryFacts(FactQuery query) async {
    calls.add('queryFacts');
    return queryResult;
  }

  @override
  Future<void> writeFacts(List<FactRecord> facts) async {
    calls.add('writeFacts');
    written.addAll(facts);
  }

  @override
  Future<FactRecord?> getFact(String id) async {
    calls.add('getFact:$id');
    return getResult;
  }

  @override
  Future<void> deleteFacts(List<String> ids) async {
    calls.add('deleteFacts');
  }
}

// ═══════════════════════════════════════════════════════════════════
// ClaimsPort Mock
// ═══════════════════════════════════════════════════════════════════

class MockClaimsPort implements ClaimsPort {
  final List<String> calls = [];
  final List<Claim> written = [];
  List<Claim> queryResult = [];
  ClaimValidationReport validationResult = const ClaimValidationReport(
    passed: true,
    entries: [],
  );

  @override
  Future<void> writeClaims(
    List<Claim> claims, {
    List<String>? evidenceRefs,
  }) async {
    calls.add('writeClaims');
    written.addAll(claims);
  }

  @override
  Future<List<Claim>> queryClaims(ClaimQuery query) async {
    calls.add('queryClaims');
    return queryResult;
  }

  @override
  Future<ClaimValidationReport> validateClaims(
    List<Claim> claims, {
    DateTime? asOf,
    String? policyVersion,
  }) async {
    calls.add('validateClaims');
    return validationResult;
  }

  @override
  Future<Claim?> getClaim(String id) async {
    calls.add('getClaim:$id');
    return null;
  }

  @override
  Future<void> updateClaimStatus(String id, ClaimStatus status) async {
    calls.add('updateClaimStatus:$id');
  }
}

// ═══════════════════════════════════════════════════════════════════
// SkillRuntimePort Mock
// ═══════════════════════════════════════════════════════════════════

class MockSkillRuntimePort implements SkillRuntimePort {
  final List<String> calls = [];

  @override
  Future<SkillRunHandle> executeSkill(
    String skillId,
    Map<String, dynamic> inputs, {
    Map<String, dynamic>? context,
  }) async {
    calls.add('executeSkill:$skillId');
    final now = DateTime.now();
    return SkillRunHandle(
      runId: 'mock-run-${now.microsecondsSinceEpoch}',
      skillId: skillId,
      running: false,
      result: SkillResult.empty(),
      startedAt: now,
      finishedAt: now,
    );
  }

  @override
  Future<void> cancel(String runId) async {
    calls.add('cancel:$runId');
  }
}

// ═══════════════════════════════════════════════════════════════════
// AppraisalPort Mock
// ═══════════════════════════════════════════════════════════════════

class MockAppraisalPort implements AppraisalPort {
  final List<String> calls = [];
  AppraisalResult? appraiseResult;

  @override
  Future<AppraisalResult> appraise(
    List<String> dimensions,
    Map<String, dynamic> context,
  ) async {
    calls.add('appraise');
    return appraiseResult ??
        AppraisalResult.empty(
          profileId: context['profileId'] as String? ?? 'mock',
        );
  }

  @override
  Future<List<AppraisalResult>> getHistory(
    String profileId,
    Period period,
  ) async {
    calls.add('getHistory:$profileId');
    return [];
  }
}

// ═══════════════════════════════════════════════════════════════════
// DecisionPort Mock
// ═══════════════════════════════════════════════════════════════════

class MockDecisionPort implements DecisionPort {
  final List<String> calls = [];

  @override
  Future<DecisionGuidance> decide(
    String policy,
    Map<String, dynamic> context,
  ) async {
    calls.add('decide:$policy');
    return const DecisionGuidance(
      action: DecisionAction.proceed,
      confidence: 0.9,
      explanation: 'mock decision',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MetricsPort Mock
// ═══════════════════════════════════════════════════════════════════

class MockMetricsPort implements MetricsPort {
  final List<String> calls = [];

  @override
  Future<MetricResult?> getMetric(
    String name,
    String entityId, {
    Period? period,
  }) async {
    calls.add('getMetric:$name');
    return null;
  }

  @override
  Future<Map<String, MetricResult>> getMetrics(
    List<String> names,
    String entityId, {
    Period? period,
  }) async {
    calls.add('getMetrics');
    return {};
  }

  @override
  Future<MetricResult> computeMetric(MetricSpec spec) async {
    calls.add('computeMetric:${spec.id}');
    return MetricResult(
      id: spec.id,
      normalizedValue: 0.5,
      sourceType: MetricSourceType.static_,
      confidence: 0.5,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// McpPort Mock
// ═══════════════════════════════════════════════════════════════════

class MockMcpPort implements McpPort {
  final List<String> calls = [];

  @override
  Future<ToolResult> callTool(
    String name,
    Map<String, dynamic> arguments, {
    String? serverId,
  }) async {
    calls.add('callTool:$name');
    return const ToolResult(content: {'result': 'ok'});
  }

  @override
  Future<ResourceContent> readResource(
    String uri, {
    String? serverId,
  }) async {
    calls.add('readResource:$uri');
    return ResourceContent(
      uri: uri,
      mimeType: 'text/plain',
      text: '',
    );
  }

  @override
  Future<List<ToolInfo>> listTools({String? serverId}) async {
    calls.add('listTools');
    return [];
  }

  @override
  Future<List<ResourceInfo>> listResources({String? serverId}) async {
    calls.add('listResources');
    return [];
  }

  @override
  Stream<ResourceContent>? subscribeResource(
    String uri, {
    String? serverId,
  }) =>
      null;

  @override
  Future<PromptTemplate?> getPrompt(
    String name, {
    String? serverId,
    Map<String, dynamic>? arguments,
  }) async =>
      null;

  @override
  Future<bool> isConnected({String? serverId}) async => true;
}

// ═══════════════════════════════════════════════════════════════════
// LlmPort Mock
// ═══════════════════════════════════════════════════════════════════

class MockLlmPort extends LlmPort {
  final List<String> calls = [];
  String completionResult = 'mock response';

  @override
  LlmCapabilities get capabilities => const LlmCapabilities(
        completion: true,
        streaming: true,
        embedding: true,
        toolCalling: true,
      );

  @override
  Future<bool> isAvailable() async => true;

  @override
  bool hasCapability(String capability) => true;

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    calls.add('complete');
    return LlmResponse(content: completionResult);
  }

  @override
  Stream<LlmChunk> completeStream(LlmRequest request) {
    calls.add('completeStream');
    return Stream.value(LlmChunk(content: completionResult, isDone: true));
  }

  @override
  Future<List<double>> embed(String text) async {
    calls.add('embed');
    return [0.1, 0.2, 0.3];
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    calls.add('embedBatch');
    return texts.map((_) => [0.1, 0.2, 0.3]).toList();
  }

  @override
  Future<double> similarity(String text1, String text2) async {
    calls.add('similarity');
    return 0.85;
  }

  @override
  Future<LlmResponse> completeWithTools(
      LlmRequest request, List<LlmTool> tools) async {
    calls.add('completeWithTools');
    return LlmResponse(content: completionResult);
  }
}

// ═══════════════════════════════════════════════════════════════════
// PhilosophyPort Mock
// ═══════════════════════════════════════════════════════════════════

class MockPhilosophyPort extends PhilosophyPort {
  final List<String> calls = [];

  PhilosophyGuidance? evaluateResult;
  ProhibitionCheckResult? checkProhibitionsResult;
  InterventionResult? interveneResult;
  Ethos? ethosResult;
  bool blockDelivery = false;
  bool throwOnIntervene = false;

  @override
  Future<PhilosophyGuidance> evaluate(
      PhilosophyEvaluationContext context) async {
    calls.add('evaluate');
    return evaluateResult ??
        PhilosophyGuidance(
          prohibitionChecks: const ProhibitionCheckResult(
            checks: [],
            hasHardViolation: false,
          ),
          recommendedAction: 'proceed',
          confidence: 0.9,
          explanation: 'Mock evaluation passed',
          prohibitionViolated: false,
        );
  }

  @override
  Future<ProhibitionCheckResult> checkProhibitions(
      ProhibitionCheckRequest request) async {
    calls.add('checkProhibitions');
    return checkProhibitionsResult ??
        const ProhibitionCheckResult(
          checks: [],
          hasHardViolation: false,
        );
  }

  @override
  Future<InterventionResult> intervene(
    InterventionPoint point,
    phil.PipelineContext context,
  ) async {
    calls.add('intervene:${point.name}');
    if (throwOnIntervene) {
      throw Exception('Mock philosophy intervention error');
    }
    return interveneResult ??
        InterventionResult(
          point: point,
          prohibitionViolated: blockDelivery,
        );
  }

  @override
  Future<Ethos> getEthos() async {
    calls.add('getEthos');
    return ethosResult ??
        Ethos(
          id: 'mock-ethos',
          name: 'Mock Ethos',
          valuePriorities: const [],
          prohibitions: const [],
          metadata: EthosMetadata(
            version: '1.0.0',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        );
  }

  @override
  Future<List<Tension>> detectTensions(MultiLayerContext context) async {
    calls.add('detectTensions');
    return [];
  }

  @override
  Future<EvolutionProposal?> proposeFeedback(FeedbackEvent event) async {
    calls.add('proposeFeedback');
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════
// EventPort Mock
// ═══════════════════════════════════════════════════════════════════

class MockEventPort implements EventPort {
  final List<PortEvent> publishedEvents = [];
  final List<String> calls = [];
  final InMemoryEventPort _inner = InMemoryEventPort();

  @override
  Future<void> publish(PortEvent event) async {
    calls.add('publish');
    publishedEvents.add(event);
    await _inner.publish(event);
  }

  @override
  Stream<PortEvent> subscribe(String eventType) {
    calls.add('subscribe:$eventType');
    return _inner.subscribe(eventType);
  }

  @override
  Stream<PortEvent> subscribeAll() {
    calls.add('subscribeAll');
    return _inner.subscribeAll();
  }

  @override
  Future<void> unsubscribe(String eventType) async {
    calls.add('unsubscribe:$eventType');
    await _inner.unsubscribe(eventType);
  }
}

// ═══════════════════════════════════════════════════════════════════
// NotificationPort Mock
// ═══════════════════════════════════════════════════════════════════

class MockNotificationPort implements NotificationPort {
  final List<Notification> sentNotifications = [];
  final List<String> calls = [];

  @override
  Future<NotificationResult> notify(Notification notification) async {
    calls.add('notify');
    sentNotifications.add(notification);
    return NotificationResult(
      notificationId: notification.notificationId,
      accepted: true,
      status: NotificationStatus.delivered,
    );
  }

  @override
  Future<List<NotificationResult>> notifyBatch(
      List<Notification> notifications) async {
    calls.add('notifyBatch');
    sentNotifications.addAll(notifications);
    return notifications
        .map((n) => NotificationResult(
              notificationId: n.notificationId,
              accepted: true,
              status: NotificationStatus.delivered,
            ))
        .toList();
  }

  @override
  Future<NotificationStatus> getStatus(String notificationId) async {
    calls.add('getStatus');
    return NotificationStatus.delivered;
  }

  @override
  Future<List<NotificationRecord>> getHistory({
    String? recipientId,
    NotificationType? type,
    DateTime? since,
    int limit = 100,
  }) async {
    calls.add('getHistory');
    return [];
  }

  @override
  Future<bool> cancel(String notificationId) async {
    calls.add('cancel');
    return true;
  }
}

// ═══════════════════════════════════════════════════════════════════
// KvStorage Mock
// ═══════════════════════════════════════════════════════════════════

class MockKvStorage implements KvStoragePort {
  final List<String> calls = [];
  final InMemoryKvStoragePort _inner = InMemoryKvStoragePort();

  @override
  Future<void> set(String key, dynamic value) async {
    calls.add('set:$key');
    await _inner.set(key, value);
  }

  @override
  Future<dynamic> get(String key) async {
    calls.add('get:$key');
    return _inner.get(key);
  }

  @override
  Future<void> remove(String key) async {
    calls.add('remove:$key');
    await _inner.remove(key);
  }

  @override
  Future<bool> exists(String key) async {
    calls.add('exists:$key');
    return _inner.exists(key);
  }

  @override
  Future<List<String>> keys({String? prefix}) async {
    calls.add('keys');
    return _inner.keys(prefix: prefix);
  }

  @override
  Future<void> clear() async {
    calls.add('clear');
    await _inner.clear();
  }
}

// ═══════════════════════════════════════════════════════════════════
// MetricPort Mock (instrumentation layer)
// ═══════════════════════════════════════════════════════════════════

class MockMetricPort implements MetricPort {
  final List<String> calls = [];
  final List<({String name, double value, Map<String, String>? tags})>
      recordedMetrics = [];

  @override
  Future<MetricValue> compute(
      String metricName, Map<String, dynamic> context) async {
    calls.add('compute:$metricName');
    return MetricValue(value: 0.0, timestamp: DateTime.now());
  }

  @override
  Future<void> record(String metricName, double value,
      {Map<String, String>? tags}) async {
    calls.add('record:$metricName');
    recordedMetrics.add((name: metricName, value: value, tags: tags));
  }

  @override
  Stream<MetricEvent> watch(String metricName) {
    calls.add('watch:$metricName');
    return const Stream.empty();
  }

  @override
  Future<List<MetricValue>> history(
    String metricName, {
    DateTime? start,
    DateTime? end,
    int? limit,
  }) async {
    calls.add('history:$metricName');
    return [];
  }
}

// ═══════════════════════════════════════════════════════════════════
// ApprovalPort Mock
// ═══════════════════════════════════════════════════════════════════

class MockApprovalPort implements ApprovalPort {
  final List<String> calls = [];
  bool autoApprove;

  MockApprovalPort({this.autoApprove = true});

  @override
  Future<ApprovalResult> requestApproval(ApprovalRequest request) async {
    calls.add('requestApproval');
    return ApprovalResult(
      approvalId: request.requestId,
      status: autoApprove ? ApprovalStatus.approved : ApprovalStatus.pending,
      approverId: autoApprove ? 'auto' : null,
      decidedAt: autoApprove ? DateTime.now() : null,
    );
  }

  @override
  Future<ApprovalStatus> checkStatus(String approvalId) async {
    calls.add('checkStatus');
    return autoApprove ? ApprovalStatus.approved : ApprovalStatus.pending;
  }

  @override
  Future<void> cancelApproval(String approvalId) async {
    calls.add('cancelApproval');
  }

  @override
  Stream<ApprovalEvent> watchApproval(String approvalId) {
    calls.add('watchApproval');
    return const Stream.empty();
  }

  @override
  Future<List<ApprovalRecord>> getHistory({
    String? entityId,
    String? requesterId,
    DateTime? since,
    int limit = 100,
  }) async {
    calls.add('getHistory');
    return [];
  }
}

// ═══════════════════════════════════════════════════════════════════
// TestOpsPorts Factory
// ═══════════════════════════════════════════════════════════════════

/// Bundle of mock standard ports for tests. Call [toOpsPorts] or
/// [toConsumedOpsPorts] to build the wired container.
class TestOpsPorts {
  final MockFactsPort facts;
  final MockClaimsPort claims;
  final MockSkillRuntimePort skillRuntime;
  final MockAppraisalPort appraisal;
  final MockDecisionPort decision;
  final MockMetricsPort metrics;
  final MockMcpPort mcp;
  final MockLlmPort llm;
  final MockPhilosophyPort philosophy;
  final MockKvStorage kvStorage;

  final MockNotificationPort notification;
  final MockApprovalPort approval;
  final MockEventPort event;
  final MockMetricPort metric;

  TestOpsPorts._({
    required this.facts,
    required this.claims,
    required this.skillRuntime,
    required this.appraisal,
    required this.decision,
    required this.metrics,
    required this.mcp,
    required this.llm,
    required this.philosophy,
    required this.kvStorage,
    required this.notification,
    required this.approval,
    required this.event,
    required this.metric,
  });

  factory TestOpsPorts({MockKvStorage? kvStorage}) {
    return TestOpsPorts._(
      facts: MockFactsPort(),
      claims: MockClaimsPort(),
      skillRuntime: MockSkillRuntimePort(),
      appraisal: MockAppraisalPort(),
      decision: MockDecisionPort(),
      metrics: MockMetricsPort(),
      mcp: MockMcpPort(),
      llm: MockLlmPort(),
      philosophy: MockPhilosophyPort(),
      kvStorage: kvStorage ?? MockKvStorage(),
      notification: MockNotificationPort(),
      approval: MockApprovalPort(),
      event: MockEventPort(),
      metric: MockMetricPort(),
    );
  }

  /// Build a [ConsumedOpsPorts] suitable for [OpsRuntime.fromConsumedPorts].
  ConsumedOpsPorts toConsumedOpsPorts() {
    return ConsumedOpsPorts(
      facts: facts,
      claims: claims,
      skillRuntime: skillRuntime,
      appraisal: appraisal,
      decision: decision,
      metrics: metrics,
      mcp: mcp,
      llm: llm,
      philosophy: philosophy,
      kvStorage: kvStorage,
      approval: approval,
      notification: notification,
      event: event,
      metric: metric,
    );
  }

  /// Build a complete [OpsPorts] with stub provided-port adapters.
  ///
  /// Callers that want real adapters (tests that exercise
  /// [WorkflowPort.runWorkflow] etc.) should use [OpsRuntime] instead.
  OpsPorts toOpsPorts() {
    return OpsPorts(
      workflow: const _StubWorkflowPort(),
      pipeline: const _StubPipelinePort(),
      scheduler: const _StubScheduleTriggerPort(),
      audit: const _StubAuditPort(),
      runbook: const _StubRunbookPort(),
      facts: facts,
      claims: claims,
      skillRuntime: skillRuntime,
      appraisal: appraisal,
      decision: decision,
      metrics: metrics,
      mcp: mcp,
      llm: llm,
      philosophy: philosophy,
      kvStorage: kvStorage,
      approval: approval,
      notification: notification,
      event: event,
      metric: metric,
    );
  }
}

// ── minimal provided-port stubs for tests that only need a full OpsPorts
// value (i.e. not exercising adapter behaviour) ──

class _StubWorkflowPort implements WorkflowPort {
  const _StubWorkflowPort();

  @override
  Future<WorkflowRunHandle> runWorkflow(
    String id,
    Map<String, dynamic> input,
  ) async {
    final now = DateTime.now();
    return WorkflowRunHandle(
      runId: 'stub-$id',
      workflowId: id,
      status: 'succeeded',
      startedAt: now,
      finishedAt: now,
    );
  }

  @override
  Future<WorkflowRunHandle?> getRun(String runId) async => null;

  @override
  Future<List<WorkflowDescriptor>> listWorkflows() async => [];
}

class _StubPipelinePort implements PipelinePort {
  const _StubPipelinePort();

  @override
  Future<PipelineRunHandle> runPipeline(
    String id,
    Map<String, dynamic> input,
  ) async {
    final now = DateTime.now();
    return PipelineRunHandle(
      runId: 'stub-$id',
      pipelineId: id,
      status: 'succeeded',
      startedAt: now,
      finishedAt: now,
    );
  }

  @override
  Future<PipelineRunHandle?> getPipelineRun(String runId) async => null;
}

class _StubScheduleTriggerPort implements ScheduleTriggerPort {
  const _StubScheduleTriggerPort();

  @override
  Future<String> schedule(String cron, ScheduleTarget target) async =>
      'stub-sched';

  @override
  Future<void> trigger(
    ScheduleTarget target,
    Map<String, dynamic> event,
  ) async {}

  @override
  Future<void> unschedule(String scheduleId) async {}
}

class _StubAuditPort implements port_audit.AuditPort {
  const _StubAuditPort();

  @override
  Future<void> record(port_audit.AuditEvent event) async {}

  @override
  Future<List<port_audit.AuditEvent>> query(
    port_audit.AuditFilter filter,
  ) async =>
      [];
}

class _StubRunbookPort implements port_runbook.RunbookPort {
  const _StubRunbookPort();

  @override
  Future<port_runbook.RunbookExecution> runRunbook(
    String id,
    Map<String, dynamic> input,
  ) async {
    final now = DateTime.now();
    return port_runbook.RunbookExecution(
      executionId: 'stub-$id',
      runbookId: id,
      status: 'succeeded',
      startedAt: now,
      finishedAt: now,
    );
  }

  @override
  Future<List<port_runbook.RunbookDescriptor>> listRunbooks() async => [];
}

// ═══════════════════════════════════════════════════════════════════
// Test Data Helpers
// ═══════════════════════════════════════════════════════════════════

/// Create a minimal [ExecutionContext] for testing.
ExecutionContext testExecutionContext({
  String runId = 'run-1',
  String traceId = 'trace-1',
  String workspaceId = 'ws-1',
  String? userId = 'user-1',
  ExecutionConfig? config,
  Map<String, dynamic>? state,
  Map<String, dynamic>? variables,
}) {
  return ExecutionContext(
    runId: runId,
    traceId: traceId,
    workspaceId: workspaceId,
    userId: userId,
    asOf: DateTime(2024, 1, 1),
    config: config ?? const ExecutionConfig(),
    state: state,
    variables: variables,
  );
}

/// Create a minimal [OpsEventMeta] for testing.
OpsEventMeta testMeta({String source = 'test'}) {
  return OpsEventMeta(source: source);
}

/// Create a minimal [OpsEvent] for testing.
OpsEvent testOpsEvent({
  String? eventId,
  String eventType = 'test.event',
  String correlationId = 'corr-1',
  String runId = 'run-1',
  String workspaceId = 'ws-1',
  Map<String, dynamic>? payload,
}) {
  return OpsEvent(
    eventId: eventId ?? OpsEvent.generateEventId(),
    eventType: eventType,
    correlationId: correlationId,
    runId: runId,
    workspaceId: workspaceId,
    timestamp: DateTime(2024, 1, 1),
    payload: payload ?? {},
    meta: testMeta(),
  );
}

/// Create a test [ExecutionLogger] backed by [InMemoryLogSink].
(ExecutionLogger, InMemoryLogSink) testLogger({
  LogLevel minLevel = LogLevel.trace,
}) {
  final sink = InMemoryLogSink();
  final logger = ExecutionLogger(
    name: 'test',
    minLevel: minLevel,
    sink: sink,
  );
  return (logger, sink);
}

/// Create a test [MetricsCollector] backed by [InMemoryMetricSink].
(MetricsCollector, InMemoryMetricSink) testMetrics() {
  final sink = InMemoryMetricSink();
  final collector = MetricsCollector(sink: sink);
  return (collector, sink);
}
