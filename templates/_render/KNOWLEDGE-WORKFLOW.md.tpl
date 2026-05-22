# Knowledge Workflow

Purpose:
- keep project knowledge portable, current, and useful to future agents
- separate raw source material from curated durable facts

## Locations

Primary knowledge root:
- `{{KNOWLEDGE_ROOT}}`

Core files:
- `{{KNOWLEDGE_ROOT}}/{{KNOWLEDGE_INDEX_DIR}}/README.md`
- `{{KNOWLEDGE_ROOT}}/{{KNOWLEDGE_WIKI_DIR}}/index.md`
- `{{KNOWLEDGE_ROOT}}/{{KNOWLEDGE_WIKI_DIR}}/decisions.md`
- `{{KNOWLEDGE_ROOT}}/{{KNOWLEDGE_WIKI_DIR}}/architecture-notes.md`
- `{{KNOWLEDGE_ROOT}}/{{KNOWLEDGE_WIKI_DIR}}/task-history.md`
- `{{KNOWLEDGE_ROOT}}/{{KNOWLEDGE_WIKI_DIR}}/open-questions.md`
- `{{KNOWLEDGE_ROOT}}/{{KNOWLEDGE_WIKI_DIR}}/agent-lessons.md`
- `{{KNOWLEDGE_ROOT}}/{{KNOWLEDGE_WIKI_DIR}}/log.md`
- `{{KNOWLEDGE_ROOT}}/{{KNOWLEDGE_RAW_DIR}}/README.md`

## Read Protocol

For non-trivial or history-sensitive tasks:
1. Read `{{KNOWLEDGE_ROOT}}/{{KNOWLEDGE_INDEX_DIR}}/README.md`.
2. Read only the wiki files relevant to the task.
3. Check `open-questions.md` before making assumptions.
4. Check `decisions.md` before revisiting prior choices.
5. Check `agent-lessons.md` when debugging repeated workflow failures.

## Write Protocol

After meaningful work:
1. Save raw source material under `{{KNOWLEDGE_RAW_DIR}}/` only when useful later.
2. Add durable facts to the most specific curated wiki file.
3. Add accepted choices to `decisions.md`.
4. Add implementation or validation summaries to `task-history.md`.
5. Add unresolved items to `open-questions.md`.
6. Add reusable workflow or debugging lessons to `agent-lessons.md`.
7. Add one chronological summary to `log.md`.

## Quality Bar

Knowledge entries must be:
- portable across repositories
- specific enough to guide future work
- short enough to scan
- linked to evidence when practical
- free of secrets and credentials
