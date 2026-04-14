# Agent Infrastructure

## Architecture
Hub-and-spoke model:
- Orchestrator in center
- Specialized subagents for execution
- No direct subagent-to-subagent workflow

## Agents
- SC-Agent: implementation
- UI-UX-Agent: default `product-ui` specialist for UX structure, UI components/styles, and accessibility checks
- CR-Agent: code review
- DOMAIN-Agent: architecture/data-flow analysis
- VALIDATION-Agent: API/schema validation
- UI-Test-Agent: browser/UI verification
- DOC-Agent: docs quality and consistency

## Frontend Flow
1. UI-UX-Agent designs/refines UX structure and applies UI changes.
2. UI-Test-Agent verifies behavior in browser scenarios.
3. CR-Agent reviews risky/large UI changes before final acceptance.

## Golden Rules
1. Orchestrator delegates implementation work.
2. Every subagent result must be verified.
3. Work in atomic steps.
4. Keep user in the loop for risky decisions.
