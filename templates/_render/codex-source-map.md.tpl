# Source Map

This project-local Codex pack is intended to align these layers:

- `.ai/shared-docs/` as the universal documentation source
- `AGENTS.md` as the Codex repo entry point
- `CLAUDE.md` as the Claude Code repo entry point
- `{{USER_CODEX_HOME}}/skills/projects-*` as reusable global skills
- `{{PROJECT_CODEX_DIR}}/agents/*.toml` as thin repo-local agent wrappers

Portability rule:
- global reusable skills stay under `{{USER_CODEX_HOME}}/skills`
- `.codex/project-context/` travels with the repository
- `.claude/` runtime worktrees and lock/state files are not template assets
