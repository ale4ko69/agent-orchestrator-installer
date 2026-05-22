---
name: projects-explore
description: Use for pre-implementation analysis: usage mapping, duplicate detection, dependency impact, and reuse opportunities across software repositories.
---

# projects-explore

## Goal
Map real code impact before planning or implementation.

## Output Contract
1. Usage map
2. Duplicate map
3. Dependency map
4. Reuse recommendation
5. Files to read
6. Likely files to change

## Rules
- Do not infer repository state from one file.
- Prefer source code evidence over assumptions.
- If docs and code conflict, report the conflict explicitly.
- If the task affects more than one area or more than two files, complete this analysis before planning.
