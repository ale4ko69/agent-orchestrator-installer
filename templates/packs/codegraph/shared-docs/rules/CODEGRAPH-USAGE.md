# CodeGraph Usage Rules

Use CodeGraph only when it improves confidence or saves meaningful exploration time.

## Required Behavior

- Prefer CodeGraph for symbol lookup, callers/callees, route discovery, and impact radius when a valid index exists.
- Verify important graph findings against source files.
- Fall back to `rg` and file reads when CodeGraph is unavailable or stale.
- Re-run or refresh indexing after large moves, generated code changes, or dependency graph shifts.
- Keep `.codegraph/` as local runtime/index state unless the project explicitly documents a different policy.

## Do Not

- Do not treat graph output as a substitute for tests.
- Do not make architectural claims from graph data alone.
- Do not commit secrets, private query logs, or local index data.
- Do not install or update CodeGraph silently.
