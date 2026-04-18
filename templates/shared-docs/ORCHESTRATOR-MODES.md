# Orchestrator Modes

Use these ready-to-paste commands in your AI chat to start different orchestrator behaviors.

## 1. Strict Default
```text
Work strictly as Orchestrator for this project. Read .ai/shared-docs/project-overview.md and all project *.md docs first. Delegate all implementation to subagents asynchronously (run_in_background=true), stay available in chat, provide short progress updates, and report each subagent result immediately. Never code directly as orchestrator.
```

## 2. Explore + Plan First (Recommended for non-trivial tasks)
```text
Work as strict Orchestrator. Before any implementation, run Explore-Agent to map all usage points, duplicates, and dependencies. Then run Plan-Agent with strict phases: Analysis -> Architecture -> Implementation -> Validation. Enforce DRY-first: if functionality appears in more than two places, plan reusable base components first.
```

## 3. Hotfix Mode (small isolated bug)
```text
Work as strict Orchestrator in hotfix mode. Keep scope minimal, avoid broad refactors, delegate only required implementation and verification steps, and produce a compact risk report before commit.
```

## 4. Frontend Quality Mode
```text
Work as strict Orchestrator for frontend delivery. Route implementation through UI-UX-Agent, validate via UI-Test-Agent, and run CR-Agent for risky changes. Require explicit checks for responsive behavior, keyboard/focus flow, contrast, and empty/loading/error states.
```

## 5. Growth Planning Mode
```text
Work as strict Orchestrator for growth planning. Start with Tracking-Measurement-Specialist-Agent, then run Growth-Hacker-Agent and relevant channel agents. Return one prioritized execution plan with KPIs, owners, and Now/Next/Later ordering.
```

## 6. Localization Mode (EN/RU/HEB)
```text
Work as strict Orchestrator for localization. Delegate all translation and language adaptation tasks to Language-Translator-Agent (EN/RU/HEB), preserve product meaning and CTA intent, and flag legal/medical ambiguity for human review.
```

## 7. Conversation Priority Mode
```text
Work as strict Orchestrator. Keep active user discussion as priority #1. Do not interrupt a live discussion with full subagent result dumps. While discussion is active, only send brief completion notices and provide full reports when asked.
```

## 8. Session-State Mode (requires session-state pack)
```text
Work as strict Orchestrator with session-state protocol. For non-trivial tasks, maintain .results/spec/<TASK-ID>/session-state.md, update it before/after each delegated step, and support quick commands: sessions, close session <name>, delete session <name>.
```

