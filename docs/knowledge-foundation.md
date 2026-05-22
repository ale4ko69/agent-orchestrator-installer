# Knowledge Foundation

`knowledge-foundation` installs a local project knowledge wiki. It is designed for repositories where agents need durable memory without depending on GitHub Wiki or an external service.

## What It Installs

Default root:

```text
.ai/knowledge/
  raw/
  wiki/
  index/
```

Files:
- `raw/README.md`: rules for unprocessed source notes.
- `wiki/index.md`: curated knowledge entry point.
- `wiki/decisions.md`: accepted decisions and rationale.
- `wiki/task-history.md`: completed work and validation notes.
- `wiki/open-questions.md`: unresolved questions.
- `wiki/architecture-notes.md`: system shape and boundaries.
- `wiki/agent-lessons.md`: reusable lessons from agent work.
- `wiki/log.md`: chronological knowledge update log.
- `index/README.md`: read order and file map.

When the `codex` target is installed, it also writes:

```text
.codex/project-context/dev/KNOWLEDGE-WORKFLOW.md
```

## Install

PowerShell:

```powershell
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -InstallPacks knowledge-foundation -KnowledgeRoot .ai/knowledge
```

Python:

```powershell
py -3 ./scripts/install.py ./project.config.json --install-packs knowledge-foundation --knowledge-root .ai/knowledge
```

You can also set it in config:

```json
{
  "enabledPacks": ["knowledge-foundation"],
  "knowledge": {
    "enabled": true,
    "root": ".ai/knowledge",
    "rawDir": "raw",
    "wikiDir": "wiki",
    "indexDir": "index",
    "updateOnInstall": true,
    "enableDaemon": false,
    "citationMode": "source-file",
    "indexProvider": "sqlite-fts5"
  }
}
```

## Current Scope

P0 is file-only:
- no background daemon
- no SQLite/FTS index creation
- no automatic session summarizer

The installer preserves existing knowledge files instead of overwriting them. This is intentional because the folder is meant to protect project memory.
