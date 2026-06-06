---
name: codegraph-explore
description: Use CodeGraph-backed graph exploration when available, with fallback to rg/file reads and explicit impact notes.
---

# codegraph-explore

## Goal

Use CodeGraph as an optional graph-first exploration layer before planning or implementing non-trivial code changes.

## Workflow

1. Check whether CodeGraph is available and initialized for the repository.
2. Use graph queries for symbol lookup, callers/callees, route discovery, and impact radius.
3. Verify critical findings with source file reads.
4. Fall back to `rg` and normal file exploration if CodeGraph is unavailable, stale, or incomplete.
5. Record evidence paths and impact notes in the plan, review, or SpecFlow artifacts.

## Output Contract

Return:

1. Graph evidence used
2. File evidence used
3. Impact map
4. Confidence
5. Staleness or fallback notes

## Rules

- Do not claim CodeGraph is current unless you verified its status or freshness.
- Do not skip tests, type checks, or source reads.
- Do not expose secrets in graph queries or logs.
- If graph and source evidence conflict, trust current source and report the conflict.
