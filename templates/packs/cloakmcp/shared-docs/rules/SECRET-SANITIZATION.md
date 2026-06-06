# Secret Sanitization Rules

Use these rules before sharing project content with AI agents or external services.

## Required

- Scan environment files, logs, tokens, request dumps, and configs before sharing.
- Redact secrets deterministically when a future unpack step is needed.
- Keep local vault/runtime data outside git.
- Use explicit confirmation before installing hooks, rewriting files, or unpacking secrets.
- Prefer least-privilege excerpts over full dumps.

## Do Not

- Do not paste `.env`, credentials, private keys, JWTs, cookies, or session tokens into prompts.
- Do not commit sanitizer vaults or audit logs.
- Do not run automatic rewrite steps on a repository without user approval.
- Do not use cloud/external sanitizer services for sensitive projects unless approved.
- Do not assume redaction is perfect; review high-risk content manually.

## Fallback

If CloakMCP is not available:

1. Use manual review.
2. Remove secret-like values.
3. Share only the smallest necessary excerpt.
4. Mark output as manually sanitized.
