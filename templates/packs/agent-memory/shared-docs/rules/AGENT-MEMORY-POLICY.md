# Agent Memory Policy

Use agent memory to improve continuity, not to create hidden authority.

## Required

- Keep memory source references whenever practical.
- Separate raw traces from curated facts.
- Mark stale, uncertain, or unverified memory.
- Prefer project-local memory for project-specific decisions.
- Ask for explicit approval before using cloud/external memory providers for sensitive content.

## Do Not

- Do not store secrets, tokens, credentials, private keys, or session cookies.
- Do not treat memory as current truth when source code or docs disagree.
- Do not preserve user preferences that are clearly one-off or temporary.
- Do not delete provider data, accounts, or local memory stores automatically.
- Do not send sensitive project memory to external providers without explicit approval.

## Recall Rules

Before history-sensitive work:

1. Read current project docs and source files first when cheap.
2. Use memory to identify prior decisions, preferences, and repeated pitfalls.
3. Verify drift-prone facts before acting.
4. Report conflicts between memory and current repository state.

## Update Rules

After meaningful work:

1. Add stable facts only.
2. Keep entries short and specific.
3. Link to commits, specs, issues, source files, or raw notes.
4. Remove or supersede stale facts through explicit notes instead of silent deletion.
