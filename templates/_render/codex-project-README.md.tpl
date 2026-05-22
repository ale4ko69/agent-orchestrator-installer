# Codex Project Pack

This folder is the portable Codex-oriented project pack for `{{PROJECT_NAME}}`.

Purpose:
- keep project-specific context inside the repository
- keep reusable orchestration logic in global `projects-*` skills
- make the structure portable to sibling repositories

Use with:
- repo entry point: `AGENTS.md`
- global reusable skills: `{{USER_CODEX_HOME}}/skills/projects-*`
- project-specific context: `.codex/project-context/`
- knowledge workflow: `.codex/project-context/dev/KNOWLEDGE-WORKFLOW.md` when `knowledge-foundation` is installed
