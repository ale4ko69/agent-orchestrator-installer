# Agent Orchestrator Installer

Russian version: [README.ru.md](./README.ru.md)

Cross-platform installer for agent orchestration templates and project analysis docs.

## Supported OS
- Windows (PowerShell)
- Linux
- macOS
- WSL

## What It Does
The tool supports two stages:
1. Install agent/rules infrastructure
2. Analyze an existing project and generate overview documentation

## Installation Flow
1. Read `project.config.json`
2. Validate required fields (`projectName`, `projectRoot`)
3. Resolve `codexHome` (`<projectRoot>/.ai` if not provided)
4. Copy templates:
   - `copilot-config/agents/*`
   - `shared-docs/dev/*`
   - `shared-docs/rules/*`
5. Render `copilot-config/copilot-instructions.md` with project tokens
6. Prompt for second stage:
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
8. Splits large sections to:
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

If you start from an AI terminal, clone the installer and run bootstrap:

### Windows
```powershell
git clone https://github.com/ale4ko69/agent-orchestrator-installer.git
cd agent-orchestrator-installer\scripts
pwsh -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1
```

### Linux/macOS/WSL
```bash
git clone https://github.com/ale4ko69/agent-orchestrator-installer.git
cd agent-orchestrator-installer/scripts
bash ./bootstrap.sh
```

Bootstrap behavior:
1. Checks whether current folder looks like a project root.
2. Asks user to confirm using current folder.
3. If user declines (or folder is not a project), asks for project path.
4. Generates bootstrap config and runs the installer.

You can also pass project path explicitly:
- Windows: `.\bootstrap.ps1 -ProjectPath "D:\path\to\project"`
- Linux/macOS/WSL: `bash ./bootstrap.sh /path/to/project`

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
    project-overview.md
    modules/*.md (optional, when sections are large)
```
