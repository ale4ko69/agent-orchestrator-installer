# Agent Orchestrator Installer

Russian version: [README.ru.md](./README.ru.md)

Cross-platform installer for agent orchestration templates and project analysis docs.

Roadmap (planned features and deferred integrations): [ROADMAP.md](./ROADMAP.md)

## Supported OS
- Windows (PowerShell)
- Linux
- macOS
- WSL

## What It Does
The tool supports two stages:
1. Install agent/rules infrastructure
2. Analyze an existing project and generate overview documentation

## Orchestrator Start (Copy/Paste)
Use this as a single starter command in your AI agent chat after installer setup:

```text
Work strictly as Orchestrator for this project. Read .ai/shared-docs/project-overview.md and all project *.md docs first. Delegate all implementation to subagents asynchronously (run_in_background=true), remain available in chat, provide short progress updates, and report each subagent result immediately. Never code directly as orchestrator. Follow git policy: always task branch -> PR -> merge to main, never direct push to main.
```

Recommended launch context:
- Open AI agent terminal in the target project root.
- Ensure `project-overview.md` exists (run stage-2 analysis if missing).
- Keep orchestrator mode strict: planning/delegation/verification only.

## Included Agent Packs (Current)
- Core engineering orchestration:
  - Orchestrator, SC, UI-UX, UI-Test, CR, DOMAIN, VALIDATION, DOC
- Product planning (optional stage):
  - Product-Manager, Sprint-Prioritizer, Feedback-Synthesizer
- Growth + Marketing:
  - Growth-Hacker, Content-Creator, SEO, Social-Media
  - AI-Citation, Agentic-Search-Optimizer
  - App-Store, Video-Optimization, LinkedIn, Twitter/X, Reddit
- Paid media:
  - Tracking-Measurement, PPC, Paid-Social, Ad-Creative
  - Paid-Media-Auditor, Search-Query-Analyst, Programmatic-Display-Buyer
- Multilingual localization:
  - Language-Translator-Agent (`EN/RU/HEB`)

## Installation Flow
1. Read `project.config.json`
2. Validate required fields (`projectName`, `projectRoot`)
3. Resolve `codexHome` (`<projectRoot>/.ai` if not provided)
4. Copy templates:
   - `copilot-config/agents/*`
   - `shared-docs/dev/*`
   - `shared-docs/rules/*`
5. Render `copilot-config/copilot-instructions.md` with project tokens
6. Render policy docs:
   - `shared-docs/rules/CONSTITUTION.md`
   - `shared-docs/rules/QUALITY-GATES.md`
7. Prompt for second stage:
   - run project overview analysis now
   - if user answers `y/yes`, analysis runs immediately

## Analysis Flow
When analysis is enabled, the tool:
1. Scans repository structure (excluding `.git`, `node_modules`, `dist`, `build`, `.venv`, etc.)
2. Detects manifests/entry points (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Dockerfile`, `docker-compose*`, `Makefile`, CI workflows)
3. Detects all directories containing `.md` files (existing docs intake)
4. Builds module sections:
   - Docs Intake
   - UI
   - Server/API
   - Services/Workers
   - Infra/CI
5. Extracts likely run/build/test commands
6. Produces risks, unknowns, and suggested agent profile
7. Generates one main file:
   - `shared-docs/project-overview.md`
8. Generates machine-readable summary:
   - `shared-docs/analysis-summary.json`
9. Splits large sections to:
   - `shared-docs/modules/docs.md`
   - `shared-docs/modules/ui.md`
   - `shared-docs/modules/server.md`
   - `shared-docs/modules/services.md`
   - `shared-docs/modules/infra.md`

## New/Empty Project Behavior
If a project is new and mostly empty:
- `project-overview.md` is still generated
- `New Project Bootstrap Notes` is added
- unknowns/risks are marked explicitly
- rerun analysis after first scaffold commit

## Flags
- `-DryRun / --dry-run`: preview changes without writing files
- `-UpdateOnly / --update-only`: update existing files only
- `-AnalyzeProject / --analyze-project`: run analysis + generate overview
- `-AnalyzeOnly / --analyze-only`: analysis only, skip template installation
- `-ModuleSplitThreshold / --module-split-threshold`: split threshold for module docs (default: `12`)
- `-AnalyzeProfile / --analyze-profile`: `auto|node|python|go|java|generic` (default: `auto`)
- `-NoSecondStepPrompt / --no-second-step-prompt`: skip stage-2 prompt after install

## Optional Config Fields
In addition to required `projectName` and `projectRoot`, you can set:
- `authProvider`
- `complianceRequirements`
- `a11yLevel`
- `language`
- `framework`
- `database`
- `hosting`
- `sharedTypesPath`

These values are injected into generated policy docs.

## Integrations Scope
- `Gastown` and `Beads` integrations are intentionally postponed for now.
- They are tracked in [ROADMAP.md](./ROADMAP.md) as opt-in future profiles.

## Help (Commands + Descriptions)
- Linux/macOS/WSL:
```bash
python3 scripts/install.py --help
```
- Windows PowerShell:
```powershell
Get-Help .\scripts\install.ps1 -Detailed
```

## Install From GitHub URL (Recommended Bootstrap)

Primary mode (no local installer git repo on your machine):
- download bootstrap entry script
- installer archive is downloaded to `<project>/.tmp/agent-installer`
- scripts run from that extracted copy
- no installer git clone is created in your workspace

### Windows
```powershell
$tmp = Join-Path $env:TEMP "bootstrap-remote.ps1"
Invoke-WebRequest https://raw.githubusercontent.com/ale4ko69/agent-orchestrator-installer/main/scripts/bootstrap-remote.ps1 -OutFile $tmp
pwsh -NoProfile -ExecutionPolicy Bypass -File $tmp
```

### Linux/macOS/WSL
```bash
tmp="/tmp/bootstrap-remote.sh"
curl -fsSL https://raw.githubusercontent.com/ale4ko69/agent-orchestrator-installer/main/scripts/bootstrap-remote.sh -o "$tmp"
bash "$tmp"
```

Bootstrap behavior:
1. Checks whether current folder looks like a project root.
2. Asks user to confirm using current folder.
3. If user declines (or folder is not a project), asks for project path.
4. Generates bootstrap config and runs the installer.

You can also pass project path explicitly:
- Windows: `pwsh -File $tmp -ProjectPath "D:\path\to\project"`
- Linux/macOS/WSL: `bash "$tmp" /path/to/project`

Optional (classic local mode, if you do want local clone of installer repo):
- clone this repo and run `scripts/bootstrap.ps1` or `scripts/bootstrap.sh`

## Usage
### Windows
```powershell
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject -AnalyzeOnly
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject -ModuleSplitThreshold 8
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject -AnalyzeProfile node
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -DryRun -AnalyzeProject
```

PowerShell may be restricted by execution policy. Without admin rights:
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -ConfigPath .\project.config.json -AnalyzeProject
```

No-PowerShell fallback (`cmd` + Python):
```bat
.\scripts\install.cmd .\project.config.json --analyze-project
```

### Linux/macOS/WSL
```bash
bash ./scripts/install.sh ./project.config.json
bash ./scripts/install.sh ./project.config.json --analyze-project
bash ./scripts/install.sh ./project.config.json --analyze-project --analyze-only
bash ./scripts/install.sh ./project.config.json --analyze-project --module-split-threshold 8
bash ./scripts/install.sh ./project.config.json --analyze-project --analyze-profile python
bash ./scripts/install.sh ./project.config.json --dry-run --analyze-project
```

## Do I Need Admin Rights?
Usually no. The scripts:
- read project files
- create/update files only inside `projectRoot/.ai` (or `codexHome`)
- do not install system packages or write system paths

Admin rights may be required only if your project is located in a protected OS directory.

## Generated Structure
```text
<project>/.ai/
  copilot-config/
    copilot-instructions.md
    agents/*.agent.md
  shared-docs/
    dev/*.md
    rules/*.md
    rules/CONSTITUTION.md
    rules/QUALITY-GATES.md
    project-overview.md
    analysis-summary.json
    modules/*.md (optional, when sections are large)
```
