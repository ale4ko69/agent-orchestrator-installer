# Agent Infrastructure

## Architecture
Hub-and-spoke model:
- Orchestrator in center
- Specialized subagents for execution
- No direct subagent-to-subagent workflow

## Agents
- Product-Manager-Agent: product problem framing, outcome metrics, and scope boundaries
- Sprint-Prioritizer-Agent: atomic task breakdown and execution ordering
- Feedback-Synthesizer-Agent: feedback-to-backlog synthesis for next iterations
- Growth-Hacker-Agent: growth experiment strategy across the funnel
- Content-Creator-Agent: campaign content planning and copy production
- SEO-Specialist-Agent: SEO strategy and execution priorities
- Social-Media-Strategist-Agent: cross-platform social strategy
- AI-Citation-Strategist-Agent: AI answer-engine visibility strategy
- Agentic-Search-Optimizer-Agent: AI agent task-completion readiness optimization
- App-Store-Optimizer-Agent: ASO and listing conversion optimization
- Video-Optimization-Specialist-Agent: video discoverability and retention improvements
- LinkedIn-Content-Creator-Agent: LinkedIn-focused thought-leadership content planning
- Twitter-Engager-Agent: X/Twitter engagement strategy
- Reddit-Community-Builder-Agent: Reddit community strategy
- Tracking-Measurement-Specialist-Agent: tracking, attribution, and measurement integrity
- PPC-Campaign-Strategist-Agent: paid search campaign architecture
- Paid-Social-Strategist-Agent: paid social campaign planning
- Ad-Creative-Strategist-Agent: paid creative testing frameworks
- Paid-Media-Auditor-Agent: paid account audit and optimization reporting
- Search-Query-Analyst-Agent: query intent and negative keyword optimization
- Programmatic-Display-Buyer-Agent: display/programmatic buying strategy
- Language-Translator-Agent: multilingual translation and localization support (EN/RU/HEB)
- SC-Agent: implementation
- UI-UX-Agent: default `product-ui` specialist for UX structure, UI components/styles, and accessibility checks
- CR-Agent: code review
- DOMAIN-Agent: architecture/data-flow analysis
- VALIDATION-Agent: API/schema validation
- UI-Test-Agent: browser/UI verification
- DOC-Agent: docs quality and consistency

## Strategy Flow (Optional)
1. Product-Manager-Agent defines problem/goals/non-goals.
2. Sprint-Prioritizer-Agent produces atomic prioritized tasks.
3. Orchestrator starts implementation loop with execution agents.

## Growth Flow (Optional)
1. Tracking-Measurement-Specialist-Agent verifies tracking readiness.
2. Growth-Hacker-Agent defines experiments and KPI targets.
3. Channel-specific marketing/paid-media agents produce execution plans.

## Frontend Flow
1. UI-UX-Agent designs/refines UX structure and applies UI changes.
2. UI-Test-Agent verifies behavior in browser scenarios.
3. CR-Agent reviews risky/large UI changes before final acceptance.

## Golden Rules
1. Orchestrator delegates implementation work.
2. Every subagent result must be verified.
3. Work in atomic steps.
4. Keep user in the loop for risky decisions.
