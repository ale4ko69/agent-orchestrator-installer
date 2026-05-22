# {{PROJECT_NAME}} - Claude Code Instructions

This repository uses `.ai/shared-docs/` as the universal documentation source.

## Read Order
1. `.ai/shared-docs/project-overview.md`
2. `.ai/shared-docs/rules/*.md`
3. `.ai/shared-docs/modules/*.md`
4. relevant `docs/` sections

## Working Mode
- Prefer orchestrator-first behavior for non-trivial tasks.
- Run: discover -> plan -> approval -> implement -> verify.
- Reuse existing patterns before introducing new code.
- Keep documentation in sync when architecture or workflow changes.

## Important Paths
- Universal docs: `{{CODEX_HOME}}/shared-docs`
- Copilot-style agent specs: `{{CODEX_HOME}}/copilot-config/agents`
- Codex portable pack: `{{PROJECT_CODEX_DIR}}`

## Git Rules
- Main branch: `{{MAIN_BRANCH}}`
- Task prefix: `{{TASK_PREFIX}}`
- Never push directly to main.
