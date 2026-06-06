# Pack Registry

The installer discovers optional packs from:

```text
templates/packs/<pack-id>/pack.json
```

Use the registry to add new installer capabilities without hardcoding every pack id in the installer scripts.

## Inspect Packs

Human-readable list:

```powershell
pwsh ./scripts/install.ps1 -ListPacks
py -3 ./scripts/install.py --list-packs
```

Machine-readable list for future UI wrappers:

```powershell
pwsh ./scripts/install.ps1 -ListPacksJson
py -3 ./scripts/install.py --list-packs-json
```

Check external tools declared by enabled packs:

```powershell
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -EnablePack codegraph,markitdown -CheckTools
py -3 ./scripts/install.py ./project.config.json --enable-pack codegraph,markitdown --check-tools
```

## Metadata

Minimal `pack.json`:

```json
{
  "id": "specflow",
  "name": "SpecFlow / Spec Kit Compatibility",
  "description": "Spec-driven feature lifecycle, artifact layout, checklist gates, and agent workflow guidance.",
  "targets": ["copilot", "claude", "codex"],
  "externalTools": [],
  "defaultEnabled": false
}
```

Fields:

- `id`: stable CLI/config id. Use lowercase kebab-case.
- `name`: display name for CLI/UI lists.
- `description`: short human-readable purpose.
- `targets`: supported install targets.
- `externalTools`: optional external tools the pack may integrate with.
- `defaultEnabled`: metadata flag only. Runtime defaults still come from installer policy.

## Supported Layout

The installer currently understands these pack folders:

```text
templates/packs/<pack-id>/
  pack.json
  shared-docs/
  copilot-config/
    agents/
  codex-global/
    skills/
```

When the `copilot` target is installed:

- `shared-docs/**` is copied to `.ai/shared-docs/**`
- `copilot-config/agents/**` is copied to `.ai/copilot-config/agents/**`

When the `codex` target is installed:

- `codex-global/skills/**` is copied to `<user-codex-home>/skills/**`
- `shared-docs/**` is copied to `.codex/project-context/**`

Pack-specific behavior beyond file copying should remain explicit in the installer scripts and documented in the pack.

## Enable A Pack

```powershell
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -EnablePack specflow -Diff
py -3 ./scripts/install.py ./project.config.json --enable-pack specflow --diff
```

Config form:

```json
{
  "enabledPacks": ["specflow"]
}
```

## Authoring Rules

- Keep packs opt-in unless installer policy explicitly requires them.
- Do not vendor third-party source code into packs.
- Put external tool setup in documentation, not silent install steps.
- Keep generated files reviewable through `-Diff` / `--diff`.
- Do not overwrite user-owned runtime data.
- Add README coverage for user-facing packs.
- Add dry-run smoke coverage before committing a new pack.

## Smoke Checklist

```powershell
py -3 scripts/install.py --list-packs
py -3 scripts/install.py --list-packs-json
pwsh ./scripts/install.ps1 -ListPacks
pwsh ./scripts/install.ps1 -ListPacksJson
py -3 scripts/install.py project.config.example.json --enable-pack <pack-id> --check-tools
py -3 scripts/install.py project.config.example.json --enable-pack <pack-id> --diff
pwsh ./scripts/install.ps1 -ConfigPath project.config.example.json -EnablePack <pack-id> -Diff
```
