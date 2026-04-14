# Agent Orchestrator Installer Roadmap

This roadmap tracks features that are intentionally postponed from the current scope.

## Current Scope (Now)

- Cross-platform installer (Windows/Linux) for project agent setup
- Stage-2 project analysis and overview docs generation
- Existing-docs intake (`.md` discovery and synthesis)
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

### P1 - Optional Integrations (Not in current release)

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

### P2 - CI Strengthening

1. Add CI gates pipeline:
   - lint
   - smoke bootstrap
   - publish check
2. Add matrix runs for Windows + Linux
3. Add release readiness checklist

### P3 - Advanced Orchestration

1. Spec-flow command aliases and execution helpers
2. Optional task-to-issues bridge adapters
3. Policy linting for generated agent instruction files

### P4 - Growth Ops Enhancements

1. Prebuilt growth report templates (weekly KPI, CAC/LTV, channel ROI)
2. Optional campaign brief generator for paid + organic sync
3. Automated handoff schema between Product/Growth/Engineering agents

## Design Principles for postponed work

- Integrations remain opt-in and disabled by default
- No hard dependency on Gastown/Beads in baseline installation
- Existing projects must continue to work without migration pressure
- Windows and Linux support must remain parity-tested

