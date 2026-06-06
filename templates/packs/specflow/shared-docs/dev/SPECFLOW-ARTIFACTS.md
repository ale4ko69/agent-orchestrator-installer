# SpecFlow Artifacts

SpecFlow artifacts are durable project files, not chat-only plans.

## `spec.md`

Purpose:

- describe the user value
- define scope and non-goals
- capture acceptance criteria
- record open questions and assumptions

Minimum sections:

```text
# <Feature Name>

## User Value
## Scope
## Non-Goals
## Acceptance Criteria
## Constraints
## Open Questions
```

## `checklists/requirements.md`

Purpose:

- test whether the spec is complete enough to plan
- force ambiguity into explicit questions
- preserve accepted assumptions

## `plan.md`

Purpose:

- explain the architecture approach
- list integration points
- identify reusable code and duplicate-removal opportunities
- define validation gates
- document rollback or recovery notes

## `research.md`

Purpose:

- preserve source links
- compare options
- record rejected approaches
- explain external tool or library choices

## `data-model.md`

Use when the feature changes entities, files, schemas, payloads, persistence, or queues.

## `contracts/`

Use for API examples, JSON schemas, event payloads, CLI contracts, MCP contracts, or file formats.

## `quickstart.md`

Purpose:

- show the shortest manual smoke path
- document setup assumptions
- list exact commands for validation

## `tasks.md`

Purpose:

- split implementation into ordered, testable work
- mark parallel-safe tasks with `[P]`
- include docs and validation tasks

Example:

```text
1. [ ] Update shared contract types.
2. [ ] Add provider implementation.
3. [P] Add unit check for contract validation.
4. [P] Update README usage.
5. [ ] Run smoke validation and record result.
```
