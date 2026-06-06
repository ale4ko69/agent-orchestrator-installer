---
name: specflow-specify
description: Create or update a durable feature specification under specs/<work-id>/ before non-trivial implementation.
---

# specflow-specify

## Goal

Turn a feature request into a durable `specs/<work-id>/spec.md` that can survive chat handoffs.

## Required Inputs

- Work id or short slug
- User value
- Scope
- Non-goals
- Acceptance criteria
- Constraints
- Open questions or assumptions

## Output Contract

Create or update:

```text
specs/<work-id>/spec.md
```

Minimum sections:

1. User Value
2. Scope
3. Non-Goals
4. Acceptance Criteria
5. Constraints
6. Open Questions
7. Accepted Assumptions

## Rules

- Do not plan implementation inside the spec.
- Preserve unresolved ambiguity instead of hiding it.
- Use source links or local file references when evidence matters.
- Keep acceptance criteria observable.
