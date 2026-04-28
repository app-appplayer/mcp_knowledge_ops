/// MCP tool definitions for runbook operations.
///
/// Provides schema definitions for all runbook-related MCP tools,
/// including runbook listing, execution, approval, and manual step handling.
library;

/// MCP tool schema definitions for runbook operations.
class RunbookMcpTools {
  /// Schema for listing all runbooks.
  static Map<String, dynamic> listRunbooksSchema() => {
        'name': 'runbook.list',
        'description': 'List all available runbooks',
        'input': {
          'category': 'String?',
          'severity': 'String?',
          'tags': 'List<String>?',
        },
        'output': {'runbooks': 'Runbook[]'},
      };

  /// Schema for executing a runbook.
  static Map<String, dynamic> executeRunbookSchema() => {
        'name': 'runbook.execute',
        'description': 'Execute a runbook with provided variables',
        'input': {
          'runbookId': 'String',
          'variables': 'Map?',
        },
        'output': {
          'executionId': 'String',
          'status': 'String',
        },
      };

  /// Schema for getting runbook execution status.
  static Map<String, dynamic> getExecutionSchema() => {
        'name': 'runbook.getExecution',
        'description': 'Get the status and details of a runbook execution',
        'input': {'executionId': 'String'},
        'output': {'execution': 'RunbookExecution'},
      };

  /// Schema for resuming a manual step.
  static Map<String, dynamic> resumeManualStepSchema() => {
        'name': 'runbook.resumeManualStep',
        'description': 'Resume a runbook execution that is waiting on a manual step',
        'input': {
          'executionId': 'String',
          'stepId': 'String',
          'result': 'Map?',
        },
        'output': {'success': 'bool'},
      };

  /// Schema for approving a runbook step.
  static Map<String, dynamic> approveStepSchema() => {
        'name': 'runbook.approveStep',
        'description': 'Approve or reject a runbook step that is waiting for approval',
        'input': {
          'executionId': 'String',
          'stepId': 'String',
          'approved': 'bool',
          'reason': 'String?',
        },
        'output': {'success': 'bool'},
      };

  /// Schema for cancelling a runbook execution.
  static Map<String, dynamic> cancelExecutionSchema() => {
        'name': 'runbook.cancelExecution',
        'description': 'Cancel a running runbook execution',
        'input': {
          'executionId': 'String',
          'reason': 'String?',
        },
        'output': {'success': 'bool'},
      };

  /// All runbook MCP tool schemas.
  static List<Map<String, dynamic>> allSchemas() => [
        listRunbooksSchema(),
        executeRunbookSchema(),
        getExecutionSchema(),
        resumeManualStepSchema(),
        approveStepSchema(),
        cancelExecutionSchema(),
      ];
}
