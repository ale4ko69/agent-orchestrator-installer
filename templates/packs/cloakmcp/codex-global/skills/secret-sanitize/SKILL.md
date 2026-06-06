---
name: secret-sanitize
description: Sanitize logs, configs, and excerpts before LLM exposure using CloakMCP-style local-first workflows when available.
---

# secret-sanitize

## Goal

Prevent accidental secret exposure during agent work.

## Workflow

1. Identify sensitive inputs: env files, logs, API requests, tokens, cookies, credentials, private URLs, or user data.
2. Use CloakMCP if available and configured.
3. If unavailable, manually redact before sharing.
4. Keep vaults and audit logs out of git.
5. Report what was sanitized and what remains risky.

## Output Contract

Return:

1. Sanitization method
2. Files or snippets reviewed
3. Redaction summary
4. Residual risk
5. Whether any local vault/runtime data was touched

## Rules

- Do not reveal secret values.
- Do not unpack secrets unless explicitly requested and locally safe.
- Do not install hooks or rewrite files automatically.
- Do not commit sanitizer artifacts.
