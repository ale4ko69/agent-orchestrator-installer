# Quality Gates

Updated: {{DATE}}
Project: {{PROJECT_NAME}}

## Mandatory Gates Before PR Merge

1. **Branch policy**
- Work only in task branches.
- No direct push to `{{MAIN_BRANCH}}`.

2. **Static checks**
- Lint passes.
- Type checks pass (if language/toolchain supports it).

3. **Build and smoke**
- Build succeeds.
- Minimal smoke run succeeds (app/service startup or equivalent).

4. **Tests**
- Relevant unit/integration tests pass.
- New behavior has coverage in tests or documented rationale for exception.

5. **Security**
- No hardcoded secrets or credentials.
- Input validation exists on external boundaries.

6. **Documentation**
- Update docs when behavior or contracts changed.
- Keep `shared-docs/project-overview.md` current after major structural changes.

## Fast Review Checklist
- Scope matches task.
- No unrelated changes included.
- Risks and unknowns are listed.
- Rollback path is clear.

