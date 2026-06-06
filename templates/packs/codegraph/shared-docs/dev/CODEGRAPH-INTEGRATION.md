# CodeGraph Integration

CodeGraph is an optional external local tool for graph-first code exploration.

Reference:

- https://github.com/colbymchenry/codegraph

This pack does not vendor CodeGraph source code and does not install CodeGraph automatically. It only adds project guidance for using CodeGraph when the tool and index are available.

## Purpose

Use CodeGraph to answer structural questions before planning or editing:

- Where is this symbol defined?
- Who calls this function/class/route?
- What does this module call?
- What is the likely impact radius of this change?
- Which routes, services, tests, and contracts are connected?

CodeGraph complements this installer.

- `--analyze-project` produces static overview docs.
- `knowledge-foundation` preserves curated project memory.
- `codegraph` provides live symbol/call/impact lookup.

## Setup

Install and initialize CodeGraph using its upstream instructions.

Typical project flow:

```powershell
codegraph --version
codegraph install
codegraph init -i
```

If the tool is unavailable, stale, or incomplete, fall back to `rg`, file reads, tests, and project docs.

## Runtime State

Treat `.codegraph/` as generated local index/runtime state. Do not treat it as source of truth. Do not commit large local index data unless a project deliberately chooses otherwise.

## Explore Workflow

Before non-trivial edits:

1. Read project entry docs and local instructions.
2. Check whether CodeGraph is available and initialized.
3. Use graph queries for symbol, callers/callees, and impact analysis.
4. Verify important results with file reads.
5. Record impact notes in the plan or SpecFlow artifacts.

## When To Use

Good fit:

- large or unfamiliar repositories
- refactors
- route/service impact analysis
- shared utilities or contracts
- onboarding a new agent to a codebase
- SpecFlow planning

Usually unnecessary:

- tiny repositories
- one-file fixes
- docs-only edits
- environments where external tooling is not allowed

## Safety

- CodeGraph output is context, not proof.
- Re-index after significant structural changes.
- Do not skip tests or type checks because a graph query looked safe.
- Do not expose secrets through query text, logs, or MCP output.
