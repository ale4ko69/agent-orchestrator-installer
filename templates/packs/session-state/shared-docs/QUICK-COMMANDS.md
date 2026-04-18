# Quick Commands (Session-State Pack)

These commands are for orchestrator sessions using `session-state.md`.

## Commands
- `sessions`
  - Show all active task/topic sessions.
- `close session <name>`
  - Archive a session safely.
- `delete session <name>`
  - Permanently remove a session (requires explicit confirmation).

## Expected Behavior
1. `sessions` is read-only.
2. `close session` requires confirmation.
3. `delete session` requires explicit destructive confirmation.

## Suggested Output
- Session name
- Scope (`task`/`topic`)
- Current status
- Last update time

