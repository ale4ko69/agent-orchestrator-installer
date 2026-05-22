---
name: projects-orchestrator
description: Use for multi-step software project tasks that need discovery, phased planning, approval gating, delegation, and verification across repositories.
---

# projects-orchestrator

Use this skill when a task is non-trivial, cross-file, risky, architectural, or likely to benefit from staged execution.

## Workflow
1. Run discovery with `projects-explore`.
2. Produce a phased implementation plan with `projects-plan`.
3. Wait for explicit approval before non-trivial implementation.
4. Implement with `projects-implement` or `projects-ui-ux`.
5. Verify with `projects-review` and/or `projects-validation`.

## Trivial Task Rule
You may skip formal phased planning only for isolated, low-risk, one-file fixes.

## Required Output Before Planning
1. Evidence
2. Conflicts
3. Confidence
4. Blocking questions

## Required Output Before Implementation
1. Scope
2. Ordered plan
3. Risks
4. Validation path

## Project Context
If the repository has `AGENTS.md`, follow it.
If the repository has `.codex/project-context/`, treat it as the project-local pack.
For expected project-pack layout, read `references/portable-project-pack.md`.
