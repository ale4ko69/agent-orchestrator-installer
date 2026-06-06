---
name: specflow-implement
description: Execute a SpecFlow task list in order while preserving validation evidence and documentation updates.
---

# specflow-implement

## Goal

Implement the approved task list for a SpecFlow work item.

## Read First

```text
specs/<work-id>/spec.md
specs/<work-id>/plan.md
specs/<work-id>/tasks.md
specs/<work-id>/quickstart.md
```

## Workflow

1. Pick the next unchecked task.
2. Make the smallest scoped change that completes it.
3. Run the relevant validation.
4. Update `tasks.md` with completion status and evidence.
5. Continue only when the current task is verified.

## Rules

- Do not skip validation tasks.
- Do not broaden scope beyond the current work item.
- Update docs when behavior, commands, contracts, setup, or user-visible workflows change.
- Record validation commands and outcomes.
- If implementation reveals a spec conflict, stop and update the spec/plan before continuing.
