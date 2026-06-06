# SpecFlow Commands

Use this pack for non-trivial feature work that needs a durable specification, implementation plan, task breakdown, and verification trail.

## Work Directory

Create one feature directory per work item:

```text
specs/<work-id>/
  spec.md
  checklists/requirements.md
  plan.md
  research.md
  data-model.md
  contracts/
  quickstart.md
  tasks.md
```

Use stable ids such as `001-source-import`, `TASK-123-source-import`, or the issue key when one exists.

## Command Intents

- `specflow specify <work-id>`: create or update `spec.md` from user value, scope, constraints, and acceptance criteria.
- `specflow checklist <work-id>`: create `checklists/requirements.md` and resolve ambiguity before planning.
- `specflow plan <work-id>`: create `plan.md`, `research.md`, data/contracts notes, risk notes, and validation path.
- `specflow tasks <work-id>`: create `tasks.md` with ordered atomic tasks and parallel-safe markers.
- `specflow implement <work-id>`: execute tasks in order, updating verification notes as work is completed.

These are workflow intents for agents. They do not require a dedicated CLI in the first implementation.

## Rules

- Do not skip `spec.md` for cross-file, risky, or product-visible work.
- Do not plan implementation until requirement ambiguities are listed and resolved or accepted.
- Keep raw research and rejected options in `research.md`.
- Keep contracts and payload examples under `contracts/` when API or data boundaries are involved.
- Keep `tasks.md` atomic enough that each task can be independently verified.
- Update project docs when contracts, behavior, commands, or setup changed.
