# {{PROJECT_NAME}} - Codex Instructions

This repository uses a multi-target AI layout:
- `.ai/` for universal docs and Copilot-oriented orchestration
- `.codex/` for Codex project-local context and thin repo agents
- `CLAUDE.md` for Claude Code entry guidance

## Default Mode
- Work orchestrator-first for non-trivial tasks.
- Run: discover -> plan -> approval -> implement -> verify.
- Treat `.ai/shared-docs/` as the universal documentation source.
- Treat `.codex/project-context/` as the portable Codex project pack.
- Treat `{{KNOWLEDGE_ROOT}}/` as the durable local project knowledge base when installed.

## Read Order
1. `.ai/shared-docs/project-overview.md`
2. `.ai/shared-docs/rules/*.md`
3. `{{KNOWLEDGE_ROOT}}/{{KNOWLEDGE_INDEX_DIR}}/README.md` for history-sensitive work, if present
4. `{{KNOWLEDGE_ROOT}}/{{KNOWLEDGE_WIKI_DIR}}/index.md` and relevant wiki files, if present
5. `.ai/shared-docs/modules/*.md`
6. `.codex/project-context/project-overview.md` if present
7. `.codex/project-context/rules/*.md`
8. relevant `docs/` sections

## Project Knowledge
- Raw source material belongs in `{{KNOWLEDGE_ROOT}}/{{KNOWLEDGE_RAW_DIR}}/`.
- Curated durable facts belong in `{{KNOWLEDGE_ROOT}}/{{KNOWLEDGE_WIKI_DIR}}/`.
- Follow `.codex/project-context/dev/KNOWLEDGE-WORKFLOW.md` when the knowledge foundation is installed.

## Skills
Prefer global reusable Codex skills from:
- `{{USER_CODEX_HOME}}/skills/projects-orchestrator`
- `{{USER_CODEX_HOME}}/skills/projects-explore`
- `{{USER_CODEX_HOME}}/skills/projects-plan`
- `{{USER_CODEX_HOME}}/skills/projects-implement`
- `{{USER_CODEX_HOME}}/skills/projects-ui-ux`
- `{{USER_CODEX_HOME}}/skills/projects-review`
- `{{USER_CODEX_HOME}}/skills/projects-validation`

## Repo-Local Codex Pack
- Project Codex dir: `{{PROJECT_CODEX_DIR}}`
- Thin repo agents: `{{PROJECT_CODEX_DIR}}/agents/*.toml`
- Project context: `{{PROJECT_CODEX_DIR}}/project-context/`

## Git Rules
- Main branch: `{{MAIN_BRANCH}}`
- Task prefix: `{{TASK_PREFIX}}`
- Never push directly to main.
- Use task branches and explicit commit scope.
