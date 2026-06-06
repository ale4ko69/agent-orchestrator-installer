---
name: research-engine-use
description: Use a self-hosted or external research/answer engine to gather cited evidence before specification, planning, or tool selection.
---

# research-engine-use

## Goal

Gather source-cited research while keeping privacy, freshness, and evidence boundaries explicit.

## Workflow

1. State the research question.
2. Identify whether current external information is needed.
3. Use a configured research/answer engine when available.
4. Preserve source links and research date.
5. Separate facts, quotes, and inference.
6. Distill findings into SpecFlow `research.md`, raw knowledge notes, or planning docs.

## Output Contract

Return:

1. Research question
2. Sources used
3. Findings
4. Inferences
5. Freshness risks
6. Suggested destination for durable notes

## Rules

- Use primary sources for technical, legal, financial, or safety-sensitive claims.
- Do not expose secrets or private repo data.
- Do not present answer-engine output as canonical project knowledge until reviewed.
