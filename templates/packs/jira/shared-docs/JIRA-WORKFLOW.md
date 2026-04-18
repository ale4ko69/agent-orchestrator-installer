# Jira Workflow Pack

This pack adds practical Jira-oriented orchestration guidance for task-driven delivery.

## Recommended Flow
1. Read task details and acceptance criteria.
2. Move task to `In Progress`.
3. Run Explore + Plan before implementation.
4. Implement with atomic delegated steps.
5. Verify with CR/UI-Test where relevant.
6. Add final Jira comment with summary and evidence links.

## Minimal Task Metadata
- Task key
- Summary
- Current status
- Assignee
- Acceptance criteria
- Related links/attachments

## Orchestrator Rule
- Jira actions are coordination metadata and stay in orchestrator scope.
- Code changes remain delegated to implementation agents.

