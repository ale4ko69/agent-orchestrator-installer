# Research Engine Workflow

This pack records how to use self-hosted research and answer engines as optional evidence-gathering tools.

Reference:

- https://github.com/ItzCrazyKns/Vane

The installer does not vendor Vane or install it automatically.

## Purpose

Use a research/answer engine before specification or planning work when current external evidence matters.

Good use cases:

- market or product research
- source-cited technical investigation
- documentation discovery
- policy or standards research
- comparing external tools before choosing a provider
- gathering source links before SpecFlow `specify` or `plan`

## Layer Boundaries

- `research-engine`: current external research and cited answers.
- `codegraph`: local code symbol/call/impact graph.
- `knowledge-foundation`: curated durable project knowledge.
- `agent-memory`: cross-session recall and preferences.

Do not store raw answer-engine output as canonical project memory without review.

## Workflow

1. Define the research question.
2. Gather source-cited answers.
3. Save source links and short findings in `research.md`, `knowledge-foundation/raw`, or a project-approved notes file.
4. Distill only stable, relevant facts into the plan or curated knowledge.
5. Re-check time-sensitive facts when they affect implementation or spending.

## Privacy

Self-hosted research engines can improve privacy, but configured providers may still call external services.

- Document whether SearxNG, Ollama, OpenAI, Claude, Gemini, Groq, or other providers are used.
- Do not send secrets or private repository data into research queries.
- Keep source citation requirements visible.
