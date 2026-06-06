---
name: specflow-plan
description: Produce a phased implementation plan from an approved SpecFlow spec, with architecture, risks, contracts, and validation.
---

# specflow-plan

## Goal

Create or update the implementation planning artifacts for a SpecFlow work item.

## Read First

```text
specs/<work-id>/spec.md
specs/<work-id>/checklists/requirements.md
```

## Output Contract

Create or update:

```text
specs/<work-id>/plan.md
specs/<work-id>/research.md
specs/<work-id>/data-model.md
specs/<work-id>/contracts/
specs/<work-id>/quickstart.md
```

## Plan Structure

1. Architecture approach
2. Reuse and duplicate-removal opportunities
3. File-level impact
4. Data/contracts impact
5. Risks and rollback notes
6. Validation path

## Rules

- Read existing code/docs before choosing an approach.
- Prefer existing project patterns and shared modules.
- Put rejected alternatives in `research.md`.
- Put payloads, schemas, CLI contracts, or MCP contracts under `contracts/`.
- Do not create `tasks.md` until the plan has a validation path.
