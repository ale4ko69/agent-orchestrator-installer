# Decisions

Purpose:
- capture durable project decisions and their rationale
- prevent future agents from reopening settled questions without new evidence

Rules:
- Record accepted decisions only.
- Keep rejected options short.
- Link to source material when available.
- If a decision changes, add a new entry and mark the old one superseded.

## Decisions

### DEC-{{DATE}}-knowledge-foundation

Status: accepted
Date: {{DATE}}
Owner: project maintainers
Related: `knowledge-foundation`

Decision:
- Use `{{KNOWLEDGE_ROOT}}` as the local project knowledge root.
- Keep raw inputs in `{{KNOWLEDGE_RAW_DIR}}` and curated facts in `{{KNOWLEDGE_WIKI_DIR}}`.

Context:
- The project needs durable local memory that travels with the repository and is usable by agents without GitHub Wiki.

Consequences:
- Future agents should read this wiki before making history-sensitive decisions.
- Existing knowledge files are preserved by the installer instead of being overwritten.
