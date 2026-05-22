# SpecFlow Lifecycle

Use this lifecycle for non-trivial features:

1. **Specify**
- Clarify user value, scope, constraints, and success criteria.

2. **Plan**
- Decide architecture approach and integration points.
- Identify risks, dependencies, and rollback strategy.

3. **Task Breakdown**
- Split implementation into atomic tasks.
- Assign one owner/agent per task.

4. **Implement**
- Execute one task at a time.
- Verify output before moving forward.

5. **Review and Merge**
- Pass quality gates.
- Open PR and merge into main branch through review flow only.

## Working Conventions
- Keep tasks small and testable.
- Prefer reuse over duplication.
- Update docs for contract or behavior changes.

