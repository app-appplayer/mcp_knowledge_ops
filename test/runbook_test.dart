/// Tests for Runbook, RunbookStep, RunbookAction, RunbookVariable, RunbookTrigger,
/// RunbookConfig, and related enums.
import 'package:test/test.dart';
import 'package:mcp_knowledge_ops/mcp_knowledge_ops.dart';

void main() {
  group('Runbook', () {
    test('creation with required fields', () {
      const runbook = Runbook(
        id: 'rb-1',
        name: 'Daily Curation',
        steps: [
          RunbookStep(
            id: 'step-1',
            name: 'Run Curation',
            action: RunbookAction(
              type: RunbookStepType.pipeline,
              pipelineId: 'curation_pipeline',
            ),
          ),
        ],
      );

      expect(runbook.id, equals('rb-1'));
      expect(runbook.name, equals('Daily Curation'));
      expect(runbook.steps, hasLength(1));
      expect(runbook.version, equals('1.0.0'));
      expect(runbook.description, equals(''));
      expect(runbook.tags, isEmpty);
    });

    test('creation with all optional fields', () {
      const runbook = Runbook(
        id: 'rb-2',
        name: 'Incident Response',
        description: 'Handle incidents',
        version: '2.0.0',
        category: RunbookCategory.incidentResponse,
        severity: RunbookSeverity.critical,
        tags: ['incident', 'critical'],
        owner: 'ops-team',
        steps: [],
        prerequisites: ['monitoring_active'],
      );

      expect(runbook.category, equals(RunbookCategory.incidentResponse));
      expect(runbook.severity, equals(RunbookSeverity.critical));
      expect(runbook.tags, hasLength(2));
      expect(runbook.owner, equals('ops-team'));
      expect(runbook.prerequisites, contains('monitoring_active'));
    });
  });

  group('Runbook.validateVariables', () {
    test('returns errors for missing required vars', () {
      const runbook = Runbook(
        id: 'rb-1',
        name: 'Test',
        steps: [],
        variables: [
          RunbookVariable(
            name: 'workspace',
            required: true,
          ),
          RunbookVariable(
            name: 'mode',
            required: true,
          ),
          RunbookVariable(
            name: 'optional_param',
            required: false,
          ),
        ],
      );

      final errors = runbook.validateVariables({'workspace': 'ws-1'});

      expect(errors, hasLength(1));
      expect(errors.first, contains('mode'));
    });

    test('returns empty list when all required vars provided', () {
      const runbook = Runbook(
        id: 'rb-1',
        name: 'Test',
        steps: [],
        variables: [
          RunbookVariable(name: 'workspace', required: true),
        ],
      );

      final errors = runbook.validateVariables({'workspace': 'ws-1'});

      expect(errors, isEmpty);
    });
  });

  group('Runbook.getDefaultVariables', () {
    test('returns defaults for variables with defaultValue', () {
      const runbook = Runbook(
        id: 'rb-1',
        name: 'Test',
        steps: [],
        variables: [
          RunbookVariable(
            name: 'mode',
            defaultValue: 'auto',
          ),
          RunbookVariable(
            name: 'limit',
            defaultValue: 100,
          ),
          RunbookVariable(
            name: 'no_default',
          ),
        ],
      );

      final defaults = runbook.getDefaultVariables();

      expect(defaults, hasLength(2));
      expect(defaults['mode'], equals('auto'));
      expect(defaults['limit'], equals(100));
      expect(defaults.containsKey('no_default'), isFalse);
    });
  });

  group('RunbookAction factories', () {
    test('pipeline() creates pipeline action', () {
      final action = RunbookAction.pipeline(
        'curation_pipeline',
        inputMapping: {'key': 'value'},
      );

      expect(action.type, equals(RunbookStepType.pipeline));
      expect(action.pipelineId, equals('curation_pipeline'));
      expect(action.inputMapping, equals({'key': 'value'}));
    });

    test('workflow() creates workflow action', () {
      final action = RunbookAction.workflow('skill_build');

      expect(action.type, equals(RunbookStepType.workflow));
      expect(action.workflowId, equals('skill_build'));
    });

    test('decision() with branches', () {
      final action = RunbookAction.decision(
        branches: [
          const DecisionBranch(
            condition: 'severity == critical',
            steps: ['escalate', 'notify'],
          ),
          const DecisionBranch(
            condition: 'severity == warning',
            steps: ['log'],
          ),
        ],
        defaultBranch: 'log',
      );

      expect(action.type, equals(RunbookStepType.decision));
      expect(action.branches, hasLength(2));
      expect(action.defaultBranch, equals('log'));
    });

    test('parallel() creates parallel action', () {
      final action = RunbookAction.parallel(
        steps: ['step-a', 'step-b', 'step-c'],
        maxConcurrent: 2,
        failFast: true,
      );

      expect(action.type, equals(RunbookStepType.parallel));
      expect(action.parallelSteps, hasLength(3));
      expect(action.maxConcurrent, equals(2));
      expect(action.failFast, isTrue);
    });

    test('loop() creates loop action', () {
      final action = RunbookAction.loop(
        collection: 'items',
        itemVariable: 'item',
        steps: ['process'],
      );

      expect(action.type, equals(RunbookStepType.loop));
      expect(action.collection, equals('items'));
      expect(action.itemVariable, equals('item'));
      expect(action.loopSteps, contains('process'));
    });

    test('manual() creates manual action', () {
      final action = RunbookAction.manual(
        instructions: 'Verify the deployment',
        checklist: ['Check logs', 'Verify metrics'],
        expectedDuration: const Duration(minutes: 15),
      );

      expect(action.type, equals(RunbookStepType.manual));
      expect(action.instructions, equals('Verify the deployment'));
      expect(action.checklist, hasLength(2));
      expect(action.expectedDuration, equals(const Duration(minutes: 15)));
    });

    test('notification() creates notification action', () {
      final action = RunbookAction.notification(
        channel: 'slack',
        template: 'deployment_complete',
        recipients: ['team-ops'],
      );

      expect(action.type, equals(RunbookStepType.notification));
      expect(action.channel, equals('slack'));
      expect(action.template, equals('deployment_complete'));
      expect(action.recipients, contains('team-ops'));
    });

    test('script() creates script action', () {
      final action = RunbookAction.script(
        script: 'cleanup.sh',
        interpreter: 'bash',
      );

      expect(action.type, equals(RunbookStepType.script));
      expect(action.script, equals('cleanup.sh'));
      expect(action.interpreter, equals('bash'));
    });

    test('wait() creates wait action', () {
      final action = RunbookAction.wait(const Duration(seconds: 30));

      expect(action.type, equals(RunbookStepType.wait));
      expect(action.config['duration'], equals(30000));
    });

    test('approval() creates approval action', () {
      final action = RunbookAction.approval(
        approvers: ['admin', 'lead'],
        requiredApprovals: 2,
      );

      expect(action.type, equals(RunbookStepType.approval));
      expect(action.config['approvers'], equals(['admin', 'lead']));
      expect(action.config['requiredApprovals'], equals(2));
    });
  });

  group('RunbookVariable', () {
    test('creation with pattern', () {
      const variable = RunbookVariable(
        name: 'email',
        description: 'User email',
        type: RunbookVariableType.string,
        required: true,
        pattern: r'^[^@]+@[^@]+\.[^@]+$',
      );

      expect(variable.name, equals('email'));
      expect(variable.pattern, isNotNull);
      expect(variable.required, isTrue);
    });

    test('creation with allowedValues', () {
      const variable = RunbookVariable(
        name: 'environment',
        type: RunbookVariableType.string,
        allowedValues: ['dev', 'staging', 'production'],
      );

      expect(variable.allowedValues, hasLength(3));
      expect(variable.allowedValues, contains('staging'));
    });

    test('default required is false', () {
      const variable = RunbookVariable(name: 'optional');

      expect(variable.required, isFalse);
    });
  });

  group('RunbookTrigger factories', () {
    test('schedule() creates cron trigger', () {
      final trigger = RunbookTrigger.schedule('0 0 * * *');

      expect(trigger.type, equals('schedule'));
      expect(trigger.config['cron'], equals('0 0 * * *'));
      expect(trigger.enabled, isTrue);
    });

    test('event() creates event trigger', () {
      final trigger = RunbookTrigger.event(
        'pipeline.completed',
        filter: {'success': true},
      );

      expect(trigger.type, equals('event'));
      expect(trigger.config['eventType'], equals('pipeline.completed'));
      expect(trigger.config['filter'], equals({'success': true}));
    });

    test('alert() creates alert trigger', () {
      final trigger = RunbookTrigger.alert(
        'high_error_rate',
        severity: 'critical',
      );

      expect(trigger.type, equals('alert'));
      expect(trigger.config['alertName'], equals('high_error_rate'));
      expect(trigger.config['severity'], equals('critical'));
    });
  });

  group('RunbookConfig', () {
    test('defaults', () {
      const config = RunbookConfig();

      expect(config.timeout, isNull);
      expect(config.allowParallel, isFalse);
      expect(config.requireApproval, isFalse);
      expect(config.approvers, isEmpty);
      expect(config.autoRollback, isFalse);
      expect(config.retryOnFailure, isFalse);
      expect(config.maxRetries, equals(0));
    });

    test('custom values', () {
      const config = RunbookConfig(
        timeout: Duration(hours: 2),
        allowParallel: true,
        requireApproval: true,
        approvers: ['admin'],
        notifyOnStart: ['ops'],
        notifyOnComplete: ['ops'],
        notifyOnFailure: ['ops', 'oncall'],
        autoRollback: true,
        rollbackSteps: ['cleanup'],
        retryOnFailure: true,
        maxRetries: 3,
      );

      expect(config.timeout, equals(const Duration(hours: 2)));
      expect(config.allowParallel, isTrue);
      expect(config.approvers, contains('admin'));
      expect(config.notifyOnFailure, hasLength(2));
      expect(config.rollbackSteps, contains('cleanup'));
    });
  });

  group('Enums', () {
    test('RunbookStepType has expected values', () {
      expect(
        RunbookStepType.values,
        containsAll([
          RunbookStepType.pipeline,
          RunbookStepType.workflow,
          RunbookStepType.script,
          RunbookStepType.manual,
          RunbookStepType.approval,
          RunbookStepType.notification,
          RunbookStepType.wait,
          RunbookStepType.decision,
          RunbookStepType.parallel,
          RunbookStepType.loop,
        ]),
      );
    });

    test('RunbookCategory has expected values', () {
      expect(
        RunbookCategory.values,
        containsAll([
          RunbookCategory.dailyOperations,
          RunbookCategory.weeklyMaintenance,
          RunbookCategory.incidentResponse,
          RunbookCategory.deployment,
          RunbookCategory.recovery,
          RunbookCategory.scaling,
          RunbookCategory.security,
        ]),
      );
    });

    test('RunbookSeverity has expected values', () {
      expect(
        RunbookSeverity.values,
        containsAll([
          RunbookSeverity.routine,
          RunbookSeverity.important,
          RunbookSeverity.critical,
          RunbookSeverity.emergency,
        ]),
      );
    });

    test('RunbookOnFailure has expected values', () {
      expect(
        RunbookOnFailure.values,
        containsAll([
          RunbookOnFailure.fail,
          RunbookOnFailure.continue_,
          RunbookOnFailure.skip,
          RunbookOnFailure.rollback,
        ]),
      );
    });

    test('RunbookExecutionStatus has expected values', () {
      expect(
        RunbookExecutionStatus.values,
        containsAll([
          RunbookExecutionStatus.pending,
          RunbookExecutionStatus.running,
          RunbookExecutionStatus.waitingApproval,
          RunbookExecutionStatus.waitingManual,
          RunbookExecutionStatus.completed,
          RunbookExecutionStatus.failed,
          RunbookExecutionStatus.cancelled,
          RunbookExecutionStatus.rolledBack,
        ]),
      );
    });

    test('StepExecutionStatus has expected values', () {
      expect(
        StepExecutionStatus.values,
        containsAll([
          StepExecutionStatus.pending,
          StepExecutionStatus.running,
          StepExecutionStatus.waiting,
          StepExecutionStatus.completed,
          StepExecutionStatus.skipped,
          StepExecutionStatus.failed,
        ]),
      );
    });
  });
}
