# Spec Quality Checklist

Use this checklist before implementation begins.

## Requirements

- The user value is clear.
- Scope and non-goals are explicit.
- Acceptance criteria are observable.
- Open questions are resolved or listed as accepted assumptions.
- External dependencies and optional tools are named.

## Architecture

- Existing code and docs were checked before proposing new structure.
- Reuse opportunities are listed.
- Duplicate-removal work is planned when relevant.
- Data contracts, API payloads, file formats, or schemas are documented.
- Security, privacy, and permission boundaries are named.

## Tasks

- Tasks are ordered by dependency.
- Each task is small enough to verify.
- Parallel-safe tasks are marked with `[P]`.
- Documentation work is included.
- Validation commands are included.

## Approval Gate

Implementation may begin only after:

- `spec.md` exists
- `plan.md` exists
- `tasks.md` exists
- risks and validation path are visible
