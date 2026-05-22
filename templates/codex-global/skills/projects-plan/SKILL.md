---
name: projects-plan
description: Use for phased DRY-first implementation planning after exploration is complete.
---

# projects-plan

## Mandatory Plan Structure
1. Analysis
2. Architecture
3. Implementation
4. Validation

## DRY-First Rule
If a task touches more than two usage points:
- plan a reusable base first
- roll out usage changes second
- remove duplicates third

## Output Contract
1. Ordered checklist
2. File-level actions
3. Duplicate-removal tasks
4. Validation checklist

## Guardrails
- Reject plans that duplicate known logic.
- Prefer reuse and consolidation before additive code.
