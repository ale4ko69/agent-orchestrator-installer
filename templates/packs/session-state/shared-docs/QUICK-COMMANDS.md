# Quick Commands (Session State)

These commands are for orchestrator sessions using `session-state.md`.

## Commands
- `sessions`
  - Show all active work-item/topic sessions.
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
- Scope (`work-item`/`topic`)
- Current status
- Last update time
