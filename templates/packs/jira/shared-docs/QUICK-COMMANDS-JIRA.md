# Quick Commands (Jira Pack)

Use these command intents in chat when Jira pack is enabled.

## Commands
- `task <KEY>`: read current issue summary/status/acceptance criteria
- `set in-progress <KEY>`: move issue to active state
- `comment <KEY>`: post final execution summary and evidence
- `attach evidence <KEY>`: attach screenshots/log references if supported

## Behavior Rules
- Ask for confirmation before status/comment mutations.
- Do not block execution if Jira is temporarily unavailable.
- Continue local workflow and report Jira action failures clearly.

