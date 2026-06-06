---
name: agent-memory-manage
description: Capture, distill, recall, and update project/user memory while keeping privacy and source-trace boundaries explicit.
---

# agent-memory-manage

## Goal

Use optional agent memory responsibly for cross-session continuity.

## Modes

- `capture`: save raw trace or source material for later distillation.
- `distill`: convert raw trace into stable facts, decisions, lessons, or preferences.
- `recall`: read relevant memory before history-sensitive work.
- `update`: add, supersede, or mark memory as stale.

## Workflow

1. Identify the memory scope: personal, project, client, or team.
2. Use project-local memory first unless an external provider is explicitly configured.
3. Preserve evidence references.
4. Keep raw notes separate from curated facts.
5. Verify drift-prone facts before relying on them.
6. Avoid secrets and sensitive data.

## Output Contract

Return:

1. Memory action
2. Scope
3. Files/provider touched or proposed
4. Evidence references
5. Privacy notes
6. Staleness or verification notes

## Rules

- Do not silently send memory to cloud providers.
- Do not delete memory stores automatically.
- Do not present unverified memory as current fact.
- If memory conflicts with current repo state, trust current source and report the conflict.
