---
name: specflow-tasks
description: Convert a SpecFlow plan into ordered, atomic, verifiable implementation tasks.
---

# specflow-tasks

## Goal

Create or update:

```text
specs/<work-id>/tasks.md
```

## Read First

```text
specs/<work-id>/spec.md
specs/<work-id>/plan.md
specs/<work-id>/quickstart.md
```

## Task Rules

- Tasks must be ordered by dependency.
- Each task must be independently verifiable.
- Mark parallel-safe tasks with `[P]`.
- Include documentation updates.
- Include validation and smoke checks.
- Avoid broad task labels such as "finish backend" or "clean up everything".

## Output Shape

```text
# Tasks

1. [ ] Update shared contracts.
2. [ ] Add provider implementation.
3. [P] Add focused contract checks.
4. [P] Update README usage.
5. [ ] Run validation and record results.
```

## Rules

- If a task affects more than two usage points, plan reusable base work first.
- Do not include unrelated refactors.
- Keep destructive operations explicit and separate.
