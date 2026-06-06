# CloakMCP Integration

CloakMCP is an optional external local-first secret sanitization tool for agent workflows.

Reference:

- https://github.com/ovitrac/CloakMCP

This pack does not vendor CloakMCP source code and does not install hooks or rewrite secrets automatically.

## Purpose

Use CloakMCP-style workflows to reduce accidental secret exposure before text reaches an LLM:

- scan text/files for secrets and sensitive values
- replace sensitive values with deterministic tags
- keep mappings in a local vault/runtime store
- unpack only when explicitly needed and safe
- preserve auditability through local logs

## Suggested Workflow

1. Scan before sending logs, configs, or environment-like text to an LLM.
2. Pack/redact sensitive values locally.
3. Send only sanitized text to the agent/model.
4. Keep vaults, backups, and audit logs out of git.
5. Unpack only in a trusted local environment.

## Setup

Install and configure CloakMCP using upstream instructions.

Check readiness:

```powershell
cloak --help
```

If CloakMCP is unavailable, agents must fall back to manual secret review and avoid sharing sensitive data.

## Boundaries

- Do not install hooks automatically.
- Do not rewrite user files without explicit confirmation.
- Do not commit vaults, backups, audit logs, or unpacked secrets.
- Do not treat sanitizer output as permission to expose sensitive project data broadly.
- Keep project-specific policies documented and reviewable.
