# Agent Orchestrator Installer Roadmap

This roadmap tracks features that are intentionally postponed from the current scope.

## Current Scope (Now)

- Cross-platform installer (Windows/Linux) for project agent setup
- Stage-2 project analysis and overview docs generation
- Existing-docs intake (`.md` discovery and synthesis)
- Orchestrator mode presets catalog (`ORCHESTRATOR-MODES.md`)
- Optional pack system with `session-state`, `jira`, and `admin-ui-foundation` packs (`--enable-pack` / `enabledPacks`)
- AdminCore UI baseline mode for admin panels:
  - default `admincore` with strict examples-first policy
  - optional `custom`/`none` modes via config/CLI flags
- Strict Git workflow rules in generated instructions:
  - Always create task branches
  - Never push directly to `main`
  - Merge through Pull Requests only
- Marketing + Paid Media non-China agent pack enabled in templates:
  - Growth, content, SEO, social, AI citation, agentic search optimization
  - App store, video, LinkedIn, X/Twitter, Reddit
  - Tracking/measurement, PPC, paid social, creative, auditing, query analysis, programmatic
- China-specific marketing pack intentionally excluded from default scope

## Postponed Features (Later)

### P0 - SpecFlow / Spec Kit Compatibility Pack

1. Add an optional `specflow` pack inspired by `github/spec-kit`
   - Keep the implementation native to this installer instead of vendoring `spec-kit` wholesale
   - Preserve the current brownfield-first installer model for existing repositories
   - Enable with `--enable-pack specflow` / `enabledPacks`

2. Add executable SpecFlow artifact templates
   - `specs/<work-id>/spec.md`
   - `specs/<work-id>/checklists/requirements.md`
   - `specs/<work-id>/plan.md`
   - `specs/<work-id>/research.md`
   - `specs/<work-id>/data-model.md`
   - `specs/<work-id>/contracts/`
   - `specs/<work-id>/quickstart.md`
   - `specs/<work-id>/tasks.md`

3. Add SpecFlow agent/skill guidance
   - `specflow-specify`
   - `specflow-plan`
   - `specflow-tasks`
   - `specflow-implement`
   - Align Copilot, Claude, and Codex instructions where applicable

4. Add required documentation
   - Document the pack in `README.md` and `README.ru.md`
   - Add dedicated docs for lifecycle, artifact paths, naming rules, checklist gates, and migration from the current lightweight `SPECFLOW-LIFECYCLE.md`
   - Include examples for brownfield feature work in an existing repository

5. Add validation and smoke checks
   - Verify install, update-only, and diff modes with the new pack
   - Ensure generated SpecFlow files do not overwrite user-owned work
   - Add a small smoke scenario showing `specify -> plan -> tasks -> implement`

### P1 - CodeGraph Intelligence Pack

1. Add an optional `codegraph` pack inspired by `colbymchenry/codegraph`
   - Treat CodeGraph as an optional external local tool, not vendored source
   - Preserve the existing lightweight `--analyze-project` docs generator as the default baseline
   - Enable with `--enable-pack codegraph` / `enabledPacks`

2. Add installer support for CodeGraph readiness
   - Detect whether `codegraph` is available on `PATH`
   - Document installation options instead of silently installing third-party tooling by default
   - Provide optional bootstrap guidance for `codegraph install` and `codegraph init -i`
   - Keep `.codegraph/` treated as local generated index/runtime state

3. Add agent guidance for graph-first exploration
   - Update Explore-Agent / `projects-explore` guidance to prefer CodeGraph MCP queries when a valid `.codegraph/` index exists
   - Use CodeGraph for symbol lookup, callers/callees, impact radius, route discovery, and architecture tracing
   - Fall back to `rg` / file reads when CodeGraph is unavailable, stale, or incomplete

4. Add required documentation
   - Document the pack in `README.md` and `README.ru.md`
   - Add dedicated docs for setup, initialization, staleness handling, fallbacks, and supported workflows
   - Explain the difference between this installer's static project overview and CodeGraph's live symbol graph
   - Explain when CodeGraph is useful: large/brownfield repositories, refactors, architecture tracing, route/service impact analysis, onboarding agents into unfamiliar code, and SpecFlow planning
   - Explain when CodeGraph is unnecessary: tiny repositories, one-file fixes, quick docs-only changes, or environments where external tools are not allowed
   - Document that this installer integrates with CodeGraph as an external optional product and does not vendor or copy CodeGraph source code

5. Document enable, disable, and update flows
   - Enable for an existing project:
     - `pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -EnablePack codegraph`
     - `py -3 ./scripts/install.py ./project.config.json --enable-pack codegraph`
   - Refresh after the pack is already installed:
     - `pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -EnablePack codegraph -UpdateOnly`
     - `py -3 ./scripts/install.py ./project.config.json --enable-pack codegraph --update-only`
   - Initialize the external CodeGraph project index after enabling:
     - `codegraph install`
     - `codegraph init -i`
   - Update the external CodeGraph CLI separately from this installer:
     - document the official update path from CodeGraph (`npm` or upstream installer, depending on how it was installed)
     - document when to re-run `codegraph init -i` or `codegraph index`
   - Disable the pack from generated agent guidance:
     - document the intended installer flag/config behavior for removing or disabling pack guidance
     - keep local `.codegraph/` index removal as an explicit user action, for example `codegraph uninit`
   - Uninstall external CodeGraph integration separately:
     - document `codegraph uninstall` for removing agent MCP wiring created by CodeGraph itself
     - make clear that this installer should not delete third-party global tool installs automatically

6. Add validation and smoke checks
   - Verify install, update-only, and diff modes with the new pack
   - Confirm `.codegraph/` is ignored or documented as local runtime state
   - Add a smoke scenario for `explore -> impact analysis -> implementation planning`

### P2 - Agent Memory Providers Pack

1. Add an optional `agent-memory` pack inspired by `TencentCloud/TencentDB-Agent-Memory` and `supermemoryai/supermemory`
   - Keep the current `knowledge-foundation` file-based wiki as the default portable baseline
   - Treat TencentDB Agent Memory and Supermemory as optional external memory providers, not vendored source
   - Enable with `--enable-pack agent-memory` / `enabledPacks`
   - Support provider configuration through project config, for example `agentMemory.provider = "local-layered" | "tencentdb" | "supermemory" | "none"`

2. Preserve clear memory layers
   - `knowledge-foundation`: curated project wiki, decisions, task history, open questions, and raw source notes
   - `session-state`: live task execution state for current work
   - `agent-memory`: optional cross-session recall, user/project preferences, long-horizon task traces, and reusable workflow lessons
   - `codegraph`: code symbol/call/impact graph, not user or workflow memory

3. Add local layered memory guidance inspired by TencentDB Agent Memory
   - Document symbolic short-term memory for long tasks: offload verbose logs to files and keep a compact Mermaid task canvas in context
   - Document layered long-term memory: raw conversation/task trace -> atomic facts -> scenarios/workflows -> project/user profile
   - Preserve evidence drill-down through stable ids such as `node_id`, `result_ref`, and raw source references
   - Prefer human-readable Markdown for upper layers and local indexed storage only as an optional future backend

4. Add Supermemory integration guidance
   - Document Supermemory as an external app/API/MCP memory engine for persistent user/project context, profiles, hybrid search, connectors, and document processing
   - Support setup docs for MCP/API usage without storing API keys in repository files
   - Explain project scoping via container/project tags so personal, client, and repository contexts stay separated
   - Treat cloud/API use as opt-in because it may send memory content to an external service

5. Add required documentation
   - Document the pack in `README.md` and `README.ru.md`
   - Add dedicated docs for memory concepts, provider choices, setup, privacy boundaries, retention, export/import, and disable/uninstall flows
   - Explain when agent memory is useful: long-running work, repeated project conventions, recurring user preferences, multi-session tasks, handoffs, and onboarding future agents
   - Explain when agent memory is unnecessary or risky: short one-off tasks, sensitive projects without approval, regulated data, or work where durable recall could preserve stale/incorrect facts
   - Document that this installer integrates with external memory systems and does not copy their source code

6. Document enable, disable, and update flows
   - Enable for an existing project:
     - `pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -EnablePack agent-memory`
     - `py -3 ./scripts/install.py ./project.config.json --enable-pack agent-memory`
   - Refresh after the pack is already installed:
     - `pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -EnablePack agent-memory -UpdateOnly`
     - `py -3 ./scripts/install.py ./project.config.json --enable-pack agent-memory --update-only`
   - Disable generated agent-memory guidance through config/pack selection without deleting user-owned memory data
   - Keep provider-specific uninstall, account deletion, local database cleanup, and MCP removal as explicit user actions
   - Document provider update paths separately from this installer

7. Add validation and smoke checks
   - Verify install, update-only, and diff modes with the new pack
   - Confirm memory data directories and secrets are ignored or documented as local/runtime state
   - Add smoke scenarios for `capture -> distill -> recall -> update` and `long task offload -> Mermaid canvas -> evidence drill-down`

### P3 - Optional Integrations (Not in current release)

1. Gastown integration (optional profile)
   - Add installer profile flag (example: `--with-gastown`)
   - Add validation for Gastown prerequisites
   - Generate optional orchestration docs/templates only when enabled

2. Beads integration (optional profile)
   - Add installer profile flag (example: `--with-beads`)
   - Add Beads bootstrap and issue-flow templates
   - Keep Beads artifacts isolated from default install path

3. Combined Gastown + Beads profile
   - Provide compatibility checks
   - Provide guided enable/disable flow
   - Keep default mode dependency-free

### P4 - CI Strengthening

1. Add CI gates pipeline:
   - lint
   - smoke bootstrap
   - publish check
2. Add matrix runs for Windows + Linux
3. Add release readiness checklist

### P5 - Advanced Orchestration

1. Spec-flow command aliases and execution helpers
2. Optional task-to-issues bridge adapters
3. Policy linting for generated agent instruction files

### P6 - Growth Ops Enhancements

1. Prebuilt growth report templates (weekly KPI, CAC/LTV, channel ROI)
2. Optional campaign brief generator for paid + organic sync
3. Automated handoff schema between Product/Growth/Engineering agents

### P7 - Agent Secret Sanitization Pack

1. Track `CloakMCP` as a future optional security/privacy pack for agent workflows
   - Reference: https://github.com/ovitrac/CloakMCP
   - Treat CloakMCP as an external local-first tool, not vendored source
   - Explore generated policy templates, MCP setup docs, and agent guidance for secret scanning/sanitization before LLM exposure
   - Document pack/unpack, vault/runtime data, audit logs, ignore rules, and disable/uninstall boundaries
   - Keep this opt-in only; never rewrite secrets or install hooks automatically without explicit user action

### P8 - AI Tool Config Manager Compatibility

1. Track `cc-switch` as a future compatibility reference for multi-tool AI configuration management
   - Reference: https://github.com/farion1231/cc-switch
   - Treat CC Switch as an external desktop tool, not vendored source
   - Study its provider, MCP, prompts, skills, sessions, proxy/failover, deep-link import, backup, and cross-app sync patterns
   - Document how this installer should coexist with external config managers that edit Claude Code, Codex, Gemini CLI, OpenCode, OpenClaw, and Hermes configs
   - Avoid config ownership conflicts: generated files must keep clear managed blocks, backups, dry-run/diff mode, and explicit update boundaries
   - Consider future export/import helpers for provider-neutral MCP server specs, skill manifests, and prompt presets

### P9 - Document-To-Markdown Ingestion Pack

1. Track `MarkItDown` as a future optional document ingestion helper for project analysis and knowledge workflows
   - Reference: https://github.com/microsoft/markitdown
   - Treat MarkItDown as an external Python tool/library, not vendored source
   - Use it to convert PDFs, Word, PowerPoint, Excel, images/OCR metadata, audio transcripts, HTML, CSV/JSON/XML, ZIP contents, YouTube transcripts, EPubs, and similar source files into Markdown
   - Connect it to `knowledge-foundation` raw inbox and `--analyze-project` existing-docs intake as an opt-in converter
   - Document setup options such as `pip install markitdown[all]` or narrower extras like `[pdf, docx, pptx, xlsx]`
   - Keep Azure Document Intelligence / Azure Content Understanding integrations opt-in because they are cloud/billable services
   - Add security guidance: validate paths, restrict URI schemes/network access, avoid untrusted server-side input, and run with least privileges
   - Add smoke checks for local files and ensure converted Markdown preserves source references and does not overwrite curated wiki files automatically

### P10 - Compound Engineering Interop Pack

1. Track `compound-engineering-plugin` as a future interoperability reference for agent workflow packs
   - Reference: https://github.com/EveryInc/compound-engineering-plugin
   - Treat Compound Engineering as an external plugin/tooling ecosystem, not vendored source
   - Study its compound loop: strategy -> ideate/brainstorm -> plan -> work/debug -> code/doc review -> compound learning
   - Compare its `/ce-*` commands with this installer's SpecFlow, orchestrator modes, review, validation, and knowledge-foundation workflows
   - Study its multi-target install/conversion patterns for Claude Code, Codex, Cursor, Copilot, OpenCode, Gemini CLI, Kiro, Qwen, Droid, and related tools
   - Document coexistence rules: avoid duplicate agent names, prompt conflicts, unmanaged overwrites, and cleanup collisions
   - Consider future bridge docs that map CE artifacts such as `STRATEGY.md`, brainstorms, plans, reviews, pulse reports, and compound notes into this installer's `knowledge-foundation` and SpecFlow packs
   - Keep this optional; do not auto-install CE plugins or agents unless the user explicitly requests that integration

### P11 - Installer Local Web UI And Desktop Wrapper

1. Add a reusable installer UI layer without replacing the CLI
   - Keep `scripts/install.py` and `scripts/install.ps1` as the source-of-truth installer engine
   - Build a Local Web UI first, then optionally wrap the same frontend with Tauri later
   - Avoid building separate UIs for browser and desktop modes

2. Add a thin installer API wrapper
   - Provide local-only endpoints for config loading, config validation, tool readiness checks, dry-run/diff, install, update-only, and analyze-project - initial config validation and run endpoint added
   - Run existing installer commands through a process runner instead of duplicating install logic - active in `installer_ui/server.py`
   - Stream logs to the UI and preserve raw command output for troubleshooting
   - Never execute destructive cleanup or third-party installs without explicit user confirmation

3. Add a first UI wizard
   - Project root picker / manual path entry
   - Project config editor for `project.config.json`
   - Install target selector: `copilot`, `claude`, `codex`
   - Pack selector for current and future packs
   - Mode controls: `diff`, `dry-run`, `install`, `update-only`, `analyze-project`
   - External tool readiness view for optional tools such as CodeGraph, MarkItDown, CloakMCP, and future providers
   - Diff preview and install log console

4. Keep packaging incremental
   - P11.1: local web server plus browser UI - initial scaffold added in `scripts/ui.py` and `installer_ui/`
   - P11.2: reuse the same frontend inside a Tauri desktop shell
   - P11.3: package Windows/macOS/Linux installers only after the local web workflow is stable
   - WebView2 remains a Windows implementation detail through Tauri, not a hard requirement for the whole project

5. Add documentation and validation
   - Document CLI-first architecture and UI wrapper boundaries
   - Document how to start the Local Web UI and how to fall back to CLI
   - Add smoke checks for config validation, diff mode, update-only mode, and failed command log rendering
   - Keep UI-generated config changes reviewable and compatible with existing diff/no-write safety rules

### P12 - Research / Answer Engine References

1. Track `Vane` as a future optional research/search layer reference
   - Reference: https://github.com/ItzCrazyKns/Vane
   - Treat Vane as an external self-hosted answer/search engine, not vendored source
   - Use as inspiration for research workflows before SpecFlow specify/plan work, source citation policies, local answer-engine setup docs, and privacy-focused search through SearxNG/Ollama/cloud provider options
   - Keep separate from CodeGraph, agent-memory, and knowledge-foundation: Vane is a research/search UI and answer engine, not a code symbol graph or durable curated project wiki
   - Consider later docs for integrating self-hosted research engines with project planning, documentation intake, and evidence collection

### P13 - Self-Hosted AI Workspace References

1. Track `Odysseus` as a future optional self-hosted AI workspace reference
   - Reference: https://github.com/pewdiepie-archdaemon/odysseus
   - Treat Odysseus as an external workspace/cockpit, not vendored source
   - Study ideas around local-first chat, agents, model cookbook, deep research, document workspace, memory/skills, email/calendar/tasks, scheduled work, and PWA/mobile access
   - Keep this outside the core installer scope unless the user explicitly wants a self-hosted AI workbench profile
   - Consider future docs for running a broader AI workspace alongside projects installed by this orchestrator

## Design Principles for postponed work

- Integrations remain opt-in and disabled by default
- No hard dependency on Gastown/Beads in baseline installation
- Existing projects must continue to work without migration pressure
- Windows and Linux support must remain parity-tested

