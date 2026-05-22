# Agent Orchestrator Installer

Russian version: [README.ru.md](./README.ru.md)

`agent-orchestrator-installer` installs reusable AI-agent project scaffolding into an existing repository. It can generate Copilot instructions, Claude Code entry files, Codex project/global assets, shared project rules, optional packs, and a project analysis summary.

The installer is designed for repeatable updates: CLI targets override config targets, `diff` is strict no-write, generated root instructions use managed blocks, and migration removals are quarantined in `.trash/` instead of being deleted immediately.

## Supported Platforms

- Windows PowerShell (`pwsh` preferred, Windows PowerShell supported)
- Linux, macOS, WSL through `scripts/install.sh` / Python
- Python fallback through `scripts/install.py` or `scripts/install.cmd`

## What Gets Installed

Install targets can be used together or separately:

- `copilot`
  - `.ai/copilot-config/copilot-instructions.md`
  - `.ai/copilot-config/agents/*.agent.md`
  - `.ai/shared-docs/**`
- `claude`
  - `CLAUDE.md`
- `codex`
  - `AGENTS.md`
  - `<project>/.codex/agents/*.toml`
  - `<project>/.codex/project-context/**`
  - `<user-codex-home>/skills/projects-*`

If `installTargets` is not configured and no CLI target override is passed, all three targets are installed.

## Quick Start

From a local clone of this installer:

```powershell
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject
```

Python fallback:

```powershell
py -3 ./scripts/install.py ./project.config.json --analyze-project
```

Preview without writing:

```powershell
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -Diff -InstallTargets codex
py -3 ./scripts/install.py ./project.config.json --diff --install-targets codex
```

Codex-only refresh:

```powershell
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -InstallTargets codex -UpdateOnly -NoSecondStepPrompt
```

## Remote Bootstrap

Use this when you do not want to clone the installer repo into the target project.

### Windows

```powershell
$tmp = Join-Path $env:TEMP "bootstrap-remote.ps1"
Invoke-WebRequest https://raw.githubusercontent.com/ale4ko69/agent-orchestrator-installer/main/scripts/bootstrap-remote.ps1 -OutFile $tmp
$ps = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
& $ps -NoProfile -ExecutionPolicy Bypass -File $tmp
```

### Linux/macOS/WSL

```bash
tmp="/tmp/bootstrap-remote.sh"
curl -fsSL https://raw.githubusercontent.com/ale4ko69/agent-orchestrator-installer/main/scripts/bootstrap-remote.sh -o "$tmp"
bash "$tmp"
```

Remote bootstrap stores installer cache under `<project>/.tmp/agent-installer`. Runtime/cache folders are excluded from project analysis and from the reusable template source.

## Configuration

Minimal config:

```json
{
  "projectName": "My Project",
  "projectRoot": "D:/path/to/project",
  "codexHome": "D:/path/to/project/.ai",
  "projectCodexDir": "D:/path/to/project/.codex",
  "userCodexHome": "C:/Users/<user>/.codex",
  "installTargets": ["copilot", "claude", "codex"],
  "installCodexCli": false
}
```

Common optional fields:

- `enabledPacks`: array or comma-separated string.
- `adminUiBase`: `admincore`, `custom`, or `none`; default is `admincore`.
- `adminUiMode`: `canonical` or `legacy`; default is `canonical` in Python/shell entrypoints.
- `adminUiCanonicalDir`: directory containing `component-examples.json` and `css-report.json`; Python/shell entrypoints use it for canonical Admin UI imports.
- `adminUiSourcePath`, `adminUiSourceUrl`, `adminUiSourceSha256`, `adminUiCacheDir`: legacy Admin UI source import.
- `authProvider`, `complianceRequirements`, `a11yLevel`, `language`, `framework`, `database`, `hosting`, `sharedTypesPath`: tokens for generated docs.

See [project.config.example.json](./project.config.example.json).

## Install Targets And Packs

Target selection:

- Config: `"installTargets": ["copilot", "claude", "codex"]`
- PowerShell: `-InstallTargets copilot,claude,codex`
- Python: `--install-targets copilot,claude,codex`

CLI target flags override config targets. They do not merge with config values.

Pack policy:

- `session-state` is always enabled.
- `admin-ui-foundation` is enabled by default unless `adminUiBase=none`.
- `jira` is opt-in.
- `video-ops` is opt-in.

Enable optional packs:

```powershell
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -EnablePack jira,video-ops
py -3 ./scripts/install.py ./project.config.json --enable-pack jira,video-ops
```

## Modes

- `-DryRun` / `--dry-run`: preview planned installer writes. Use `-Diff` / `--diff` when you need a strict no-write run that also refuses missing-config bootstrap.
- `-Diff` / `--diff` / `--diff-mode`: no-write preview mode; it also refuses to create a missing bootstrap config.
- `-UpdateOnly` / `--update-only`: update existing files only; missing files/directories are skipped.
- `-AnalyzeProject` / `--analyze-project`: install and run project analysis.
- `-AnalyzeOnly` / `--analyze-only`: run analysis without installing templates.
- `-NoSecondStepPrompt` / `--no-second-step-prompt`: skip the interactive stage-2 analysis prompt.

## Project Analysis

When analysis is enabled, the installer scans the target project and writes:

- `.ai/shared-docs/project-overview.md`
- `.ai/shared-docs/analysis-summary.json`
- `.ai/shared-docs/modules/*.md` when sections exceed the split threshold

The scan excludes generated/runtime/cache folders:

```text
.git, node_modules, dist, build, .venv, venv, target, out, .next,
.idea, .vscode, .ai, .codex, .claude, .tmp, .trash
```

Analysis looks for manifests and entry points such as `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, Docker files, Makefiles, and CI workflows. It also ingests existing Markdown documentation.

## Generated File Safety

The installer treats user-owned project content carefully:

- `AGENTS.md` and `CLAUDE.md` are updated through managed Markdown blocks:
  - `<!-- BEGIN MANAGED: agent-orchestrator-installer root-agents -->`
  - `<!-- BEGIN MANAGED: agent-orchestrator-installer root-claude -->`
- Text outside managed blocks is preserved.
- Existing unmanaged `AGENTS.md` / `CLAUDE.md` files are skipped as conflicts instead of being overwritten.
- `.ai/agent-orchestrator.lock.json` is written after real write runs and records effective targets, packs, mode, and installer metadata.
- `-DryRun` and `-Diff` never write the lockfile.
- `-UpdateOnly` updates the lockfile only if it already exists.
- Python migration cleanup moves removed legacy files to `<project>/.trash/<date>/...`; explicit trash purging is a separate maintenance command.
- `.trash/` is ignored by git. Use `scripts/cleanup-trash.ps1` explicitly to purge old trash entries.

Trash cleanup:

```powershell
pwsh ./scripts/cleanup-trash.ps1 -DryRun
pwsh ./scripts/cleanup-trash.ps1 -RetentionDays 7
```

## Admin UI Foundation

Default Admin UI behavior:

- `admin-ui-foundation` is enabled unless `adminUiBase=none`.
- `adminUiMode=canonical` is the default.
- Canonical mode reads `component-examples.json` and `css-report.json` from `adminUiCanonicalDir` and copies them into `.ai/shared-docs/tools/admincore-canonical/`.

Legacy mode supports source folder or zip import:

- `-AdminUiSource` / `--admin-ui-source`
- `--admin-ui-source-url`
- `--admin-ui-sha256`
- `--admin-ui-cache-dir`

Use `adminUiBase=none` or `-AdminUiBase none` when the target project should not receive Admin UI assets.

## Generated Structure

Typical all-target output:

```text
<project>/
  AGENTS.md
  CLAUDE.md
  .codex/
    README.md
    agents/*.toml
    project-context/**
  .ai/
    agent-orchestrator.lock.json
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
      modules/*.md
      tools/**
      assets/**
  .tmp/
    agent-installer/**       # remote bootstrap/cache
  .trash/
    YYYY-MM-DD/**            # quarantined replaced/removed files
```

Codex global skills are copied to `<user-codex-home>/skills/projects-*`.

## Commands

PowerShell:

```powershell
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -InstallTargets codex -UpdateOnly -NoSecondStepPrompt
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -Diff -InstallTargets copilot
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject -AdminUiBase none
```

Python:

```powershell
py -3 ./scripts/install.py ./project.config.json
py -3 ./scripts/install.py ./project.config.json --analyze-project
py -3 ./scripts/install.py ./project.config.json --install-targets codex --update-only --no-second-step-prompt
py -3 ./scripts/install.py ./project.config.json --diff --install-targets copilot
py -3 ./scripts/install.py ./project.config.json --analyze-project --admin-ui-base none
```

Shell wrapper:

```bash
bash ./scripts/install.sh ./project.config.json --analyze-project
```

CMD wrapper:

```bat
.\scripts\install.cmd .\project.config.json --analyze-project
```

## Help

```powershell
Get-Help .\scripts\install.ps1 -Detailed
py -3 .\scripts\install.py --help
```

## Orchestrator Starter Prompt

Paste this into your AI coding agent after installing the project pack:

```text
Work strictly as Orchestrator for this project. Read .ai/shared-docs/project-overview.md and all project *.md docs first. Delegate implementation work to subagents asynchronously, remain available in chat, provide short progress updates, and report each subagent result immediately. Follow the project git policy: task branch -> PR -> merge to main.
```

## Roadmap

Future integrations and deferred profiles are tracked in [ROADMAP.md](./ROADMAP.md).
