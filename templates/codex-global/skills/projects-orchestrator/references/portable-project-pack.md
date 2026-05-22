# Portable Project Pack

Use this as the expected project-local layout for reusable Codex workflows:

```text
<repo>/
  AGENTS.md
  .codex/
    README.md
    project-context/
      project-overview.md
      source-map.md
      modules/
        ui.md
        server.md
        docs.md
      rules/
        CONSTITUTION.md
        QUALITY-GATES.md
        TASK-PLANNING.md
        GIT-WORKFLOW.md
        UI-UX-POLICY.md
      dev/
        AGENT-INFRASTRUCTURE.md
        SPECFLOW-LIFECYCLE.md
```

Guidelines:
- Keep `projects-*` skills global under `<user-codex-home>/skills`.
- Keep project-specific facts inside the repository under `.codex/project-context`.
- Use `AGENTS.md` as the repo entry point that points to project-local docs and reusable global skills.
- Prefer copying or curating project-local docs over embedding project specifics into global skills.
