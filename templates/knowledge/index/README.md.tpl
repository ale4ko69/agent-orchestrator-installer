# Knowledge Index

Purpose:
- provide a compact map of the knowledge foundation
- help agents choose the right file before reading everything

Root: `{{KNOWLEDGE_ROOT}}`

## Files

| File | Use When |
| --- | --- |
| `../{{KNOWLEDGE_WIKI_DIR}}/index.md` | You need curated, canonical project facts. |
| `../{{KNOWLEDGE_WIKI_DIR}}/decisions.md` | You need accepted decisions and rationale. |
| `../{{KNOWLEDGE_WIKI_DIR}}/task-history.md` | You need to understand what was already done. |
| `../{{KNOWLEDGE_WIKI_DIR}}/open-questions.md` | You need unresolved questions or known uncertainty. |
| `../{{KNOWLEDGE_WIKI_DIR}}/architecture-notes.md` | You need system shape, boundaries, or integration notes. |
| `../{{KNOWLEDGE_WIKI_DIR}}/agent-lessons.md` | You need reusable lessons from prior agent work. |
| `../{{KNOWLEDGE_WIKI_DIR}}/log.md` | You need a chronological record of knowledge updates. |
| `../{{KNOWLEDGE_RAW_DIR}}/README.md` | You need unprocessed source notes or raw inbox rules. |

## Read Order

1. `../{{KNOWLEDGE_WIKI_DIR}}/index.md`
2. `../{{KNOWLEDGE_WIKI_DIR}}/decisions.md`
3. `../{{KNOWLEDGE_WIKI_DIR}}/architecture-notes.md`
4. `../{{KNOWLEDGE_WIKI_DIR}}/task-history.md`
5. `../{{KNOWLEDGE_WIKI_DIR}}/open-questions.md`
6. `../{{KNOWLEDGE_WIKI_DIR}}/agent-lessons.md`
7. `../{{KNOWLEDGE_WIKI_DIR}}/log.md`
8. `../{{KNOWLEDGE_RAW_DIR}}/README.md`

## Maintenance Rule

When adding durable knowledge:
1. Put raw source material in `../{{KNOWLEDGE_RAW_DIR}}/` only when useful later.
2. Distill stable facts into the most specific wiki file.
3. Add a short entry to `../{{KNOWLEDGE_WIKI_DIR}}/log.md`.
4. Update this index only when files or read order change.
