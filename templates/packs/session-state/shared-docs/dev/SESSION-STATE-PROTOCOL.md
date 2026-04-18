# Session State Protocol

Use this protocol for non-trivial multi-step tasks to preserve progress across interruptions.

## Core Files
- `plan.md`: static task plan (what to do)
- `session-state.md`: live execution state (current progress)

## Scope
- Task scope: `<project>/.results/spec/<TASK-ID>/session-state.md`
- Topic scope: `<project>/.results/sessions/<topic>/session-state.md`

## Required Updates
1. Before delegation: mark step as `IN_PROGRESS`
2. After verification: mark step as `DONE` or `RETRY`
3. After commit: attach commit SHA to completed step

## Status Values
- `PENDING`
- `IN_PROGRESS`
- `RETRY`
- `DONE`
- `FAILED`
- `SKIPPED`

## Recovery Procedure
1. Read `session-state.md`
2. Read `plan.md`
3. Compare with `git status` and recent commits
4. Continue from first non-completed step

## Orchestrator Rule
- Orchestrator owns session-state updates.
- Subagents are stateless and do not edit session-state directly.

