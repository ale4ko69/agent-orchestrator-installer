# Agent Memory Workflow

Agent memory is an optional layer for cross-session recall and long-horizon project continuity.

References:

- https://github.com/TencentCloud/TencentDB-Agent-Memory
- https://github.com/supermemoryai/supermemory

This pack does not vendor either project and does not install external memory providers automatically.

## Layer Boundaries

Keep these layers separate:

- `knowledge-foundation`: curated project wiki, decisions, task history, open questions, and raw source notes.
- `session-state`: live task execution state for current work.
- `agent-memory`: optional cross-session recall, user/project preferences, long-horizon task traces, reusable workflow lessons, and handoff context.
- `codegraph`: code symbol/call/impact graph, not user or workflow memory.

## Provider Modes

Recommended config shape:

```json
{
  "agentMemory": {
    "provider": "local-layered"
  }
}
```

Provider options:

- `none`: disabled.
- `local-layered`: local Markdown/file-first memory inspired by layered agent memory systems.
- `supermemory`: external Supermemory API/MCP provider, opt-in only.
- `tencentdb`: external TencentDB Agent Memory-style provider, opt-in only.
- `hybrid`: advanced mode, only when explicitly designed for a project.

## Local Layered Memory

Use local layered memory first unless a project needs an external provider.

Suggested layers:

```text
raw trace / source notes
-> atomic facts
-> scenario or workflow notes
-> project profile
-> user/team preferences
```

For long tasks:

1. Offload verbose logs and raw traces to files.
2. Keep a compact task canvas in context.
3. Preserve drill-down ids such as `node_id`, `result_ref`, source file path, commit, issue, or PR.
4. Distill only stable facts into curated memory.

## External Providers

Use external providers only when the user/project explicitly accepts the privacy and operational tradeoffs.

Good Supermemory-style use cases:

- persistent user/project profile across repositories
- connectors and document processing
- hybrid search across external sources
- team-level memory with account controls

Good TencentDB-style use cases:

- local gateway/plugin architecture
- layered memory with traceability
- long-task token offload patterns
- specialized runtime integration such as OpenClaw/Hermes-style agents

## Capture / Distill / Recall / Update

Standard loop:

1. `capture`: collect raw task trace or source material.
2. `distill`: turn raw trace into atomic facts and reusable lessons.
3. `recall`: read only relevant memory before a task.
4. `update`: revise stale facts and record new decisions.

## Privacy

- Do not store secrets.
- Do not store regulated or client-sensitive data without approval.
- Mark provider scope clearly: personal, project, client, or team.
- Prefer local memory for sensitive projects.
- Treat external provider usage as opt-in because memory content may leave the repository.
