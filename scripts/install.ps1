<#
.SYNOPSIS
Installs agent templates and optionally analyzes a project.

.DESCRIPTION
Stage 1: install copilot/shared-docs templates into target project.
Stage 2: optional project analysis with overview docs generation.
Stage 3: install portable Codex assets and optional user-scope Codex CLI.

.PARAMETER ConfigPath
Path to JSON config file with projectName/projectRoot and optional fields.

.PARAMETER DryRun
Preview all planned file operations without writing changes.

.PARAMETER Diff
Preview install/update changes without writing files or bootstrapping missing config.

.PARAMETER UpdateOnly
Update only existing files/directories. Skip creating missing paths.

.PARAMETER AnalyzeProject
Run project analysis and generate shared-docs/project-overview.md.

.PARAMETER AnalyzeOnly
Run analysis only; skip template installation.

.PARAMETER ModuleSplitThreshold
If a section exceeds this count, details are written to shared-docs/modules/*.md.

.PARAMETER AnalyzeProfile
Analysis profile: auto, node, python, go, java, generic.

.PARAMETER NoSecondStepPrompt
Do not ask interactive stage-2 analysis prompt after install.

.PARAMETER EnablePack
Optional comma-separated packs to install (currently: session-state, jira, admin-ui-foundation, video-ops).
Note: session-state is always auto-enabled; admin-ui-foundation is auto-enabled unless AdminUiBase is set to none.

.PARAMETER AdminUiBase
Admin UI base policy for admin-ui-foundation pack: admincore, custom, or none.

.PARAMETER AdminUiSource
Optional source path for design examples/assets import.

.PARAMETER AdminUiSourceUrl
Optional URL/path to .zip archive with admin UI source snapshot.

.PARAMETER AdminUiSha256
Optional sha256 checksum for admin UI source archive verification.

.PARAMETER AdminUiCacheDir
Optional cache directory for downloaded/extracted admin UI archive.

.PARAMETER InstallCodexCli
Install @openai/codex globally for the current user via npm if it is not already available.

.PARAMETER UserCodexHome
Override the user-level Codex home used for reusable global skills. Default: CODEX_HOME or ~/.codex.

.PARAMETER InstallTargets
Comma-separated install targets: copilot, claude, codex. Default: all.

.EXAMPLE
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json

.EXAMPLE
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject

.EXAMPLE
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject -AnalyzeOnly

.EXAMPLE
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -DryRun -AnalyzeProject

.EXAMPLE
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject -EnablePack session-state

.EXAMPLE
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject -EnablePack session-state,jira

.EXAMPLE
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject -EnablePack admin-ui-foundation -AdminUiBase admincore -AdminUiSource "D:\Design\admin-ui-source\v1.24.0"

.EXAMPLE
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject -EnablePack admin-ui-foundation -AdminUiSourceUrl "https://example.com/admin-ui-v1.24.0.zip" -AdminUiSha256 "<sha256>"

.EXAMPLE
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -InstallCodexCli
#>

param(
  [Parameter(Mandatory=$false)]
  [string]$ConfigPath = ".\project.config.json",
  [switch]$DryRun,
  [switch]$Diff,
  [switch]$UpdateOnly,
  [switch]$AnalyzeProject,
  [switch]$AnalyzeOnly,
  [int]$ModuleSplitThreshold = 12,
  [ValidateSet("auto","node","python","go","java","generic")]
  [string]$AnalyzeProfile = "auto",
  [switch]$NoSecondStepPrompt,
  [string]$EnablePack = "",
  [ValidateSet("admincore","custom","none")]
  [string]$AdminUiBase = "",
  [string]$AdminUiSource = "",
  [string]$AdminUiSourceUrl = "",
  [string]$AdminUiSha256 = "",
  [string]$AdminUiCacheDir = "",
  [switch]$InstallCodexCli,
  [string]$UserCodexHome = "",
  [string]$InstallTargets = ""
)

$ErrorActionPreference = "Stop"

$ExcludedDirs = @('.git','node_modules','dist','build','.venv','venv','target','out','.next','.idea','.vscode','.ai','.codex','.claude','.tmp','.trash')
$AvailablePacks = @('session-state','jira','admin-ui-foundation','video-ops')
$AlwaysRequiredPacks = @('session-state')
$ConditionalRequiredPacks = @('admin-ui-foundation')
$AvailableInstallTargets = @('copilot','claude','codex')

function Read-Config([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "Config not found: $Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Ensure-ConfigFile([string]$Path, [bool]$NoWrite) {
  if (Test-Path -LiteralPath $Path) { return }
  if ($NoWrite) {
    throw "Config not found: $Path. Diff/no-write mode will not create bootstrap config."
  }

  $resolvedPath = [System.IO.Path]::GetFullPath($Path)
  $configDir = Split-Path -Parent $resolvedPath
  if (-not [string]::IsNullOrWhiteSpace($configDir) -and -not (Test-Path -LiteralPath $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
  }

  $projectRoot = if (-not [string]::IsNullOrWhiteSpace($configDir)) { $configDir } else { (Get-Location).Path }
  $projectName = Split-Path -Leaf $projectRoot
  if ([string]::IsNullOrWhiteSpace($projectName)) { $projectName = "project" }
  $userCodexHome = Join-Path $HOME ".codex"

  $json = @"
{
  "projectName": "$projectName",
  "projectRoot": "$($projectRoot -replace '\\','/')",
  "codexHome": "$($projectRoot -replace '\\','/')/.ai",
  "projectCodexDir": "$($projectRoot -replace '\\','/')/.codex",
  "userCodexHome": "$($userCodexHome -replace '\\','/')",
  "installTargets": ["copilot", "claude", "codex"],
  "installCodexCli": false,
  "mainBranch": "main",
  "taskPrefix": "TASK"
}
"@
  Set-Content -LiteralPath $resolvedPath -Value $json -Encoding UTF8
  Write-Host "Config not found. Created bootstrap config: $resolvedPath"
}

function Apply-Tokens([string]$Text, [hashtable]$Tokens) {
  $out = $Text
  foreach ($k in $Tokens.Keys) { $out = $out.Replace("{{$k}}", [string]$Tokens[$k]) }
  return $out
}

function Ensure-Dir([string]$Path, [bool]$IsDryRun, [bool]$IsUpdateOnly, [hashtable]$Stats) {
  if (Test-Path -LiteralPath $Path) { return $true }
  if ($IsUpdateOnly) { Write-Host "[SKIP:update-only] target directory missing: $Path"; return $false }
  if ($IsDryRun) { Write-Host "[DRY-RUN] mkdir -p $Path"; $Stats.created_dirs++; return $true }
  New-Item -ItemType Directory -Force -Path $Path | Out-Null
  $Stats.created_dirs++
  return $true
}

function Write-ManagedText([string]$Text, [string]$Dst, [bool]$IsDryRun, [bool]$IsUpdateOnly, [hashtable]$Stats) {
  $exists = Test-Path -LiteralPath $Dst
  if ($IsUpdateOnly -and -not $exists) { Write-Host "[SKIP:update-only] create file blocked: $Dst"; $Stats.skipped_files++; return }

  if ($IsDryRun) {
    if ($exists) { Write-Host "[DRY-RUN] update file: $Dst"; $Stats.updated_files++ }
    else { Write-Host "[DRY-RUN] create file: $Dst"; $Stats.created_files++ }
    return
  }

  $parent = Split-Path -Parent $Dst
  if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  Set-Content -LiteralPath $Dst -Encoding UTF8 -Value $Text
  if ($exists) { $Stats.updated_files++ } else { $Stats.created_files++ }
}

function Get-ManagedBlockBeginMarker([string]$BlockId) {
  return "<!-- BEGIN MANAGED: agent-orchestrator-installer $BlockId -->"
}

function Get-ManagedBlockEndMarker([string]$BlockId) {
  return "<!-- END MANAGED: agent-orchestrator-installer $BlockId -->"
}

function Get-ManagedBlockSourceHeader([string]$SourceTemplate) {
  return "<!-- Source: $SourceTemplate; pack: core; schema: managed-block-v1 -->"
}

function New-ManagedBlock([string]$BlockId, [string]$Body, [string]$SourceTemplate) {
  $trimmedBody = $Body.TrimEnd("`r","`n")
  return @(
    (Get-ManagedBlockBeginMarker -BlockId $BlockId)
    (Get-ManagedBlockSourceHeader -SourceTemplate $SourceTemplate)
    $trimmedBody
    (Get-ManagedBlockEndMarker -BlockId $BlockId)
    ""
  ) -join "`n"
}

function Test-LegacyRenderedBody([string]$ExistingText, [string]$RenderedBody) {
  if ($ExistingText -eq $RenderedBody) { return $true }
  return ($ExistingText.TrimEnd("`r","`n") -eq $RenderedBody.TrimEnd("`r","`n"))
}

function Write-ManagedBlockFile([string]$Body, [string]$Dst, [string]$BlockId, [string]$SourceTemplate, [bool]$IsDryRun, [bool]$IsUpdateOnly, [hashtable]$Stats) {
  $exists = Test-Path -LiteralPath $Dst
  if ($IsUpdateOnly -and -not $exists) { Write-Host "[SKIP:update-only] create file blocked: $Dst"; $Stats.skipped_files++; return }

  $block = New-ManagedBlock -BlockId $BlockId -Body $Body -SourceTemplate $SourceTemplate
  $nextText = $block

  if ($exists) {
    $existing = Get-Content -LiteralPath $Dst -Raw
    $beginMarker = Get-ManagedBlockBeginMarker -BlockId $BlockId
    $endMarker = Get-ManagedBlockEndMarker -BlockId $BlockId
    $begin = $existing.IndexOf($beginMarker, [System.StringComparison]::Ordinal)
    $end = $existing.IndexOf($endMarker, [System.StringComparison]::Ordinal)
    $hasSingleBegin = ($begin -ge 0 -and $existing.IndexOf($beginMarker, $begin + $beginMarker.Length, [System.StringComparison]::Ordinal) -lt 0)
    $hasSingleEnd = ($end -ge 0 -and $existing.IndexOf($endMarker, $end + $endMarker.Length, [System.StringComparison]::Ordinal) -lt 0)

    if ($hasSingleBegin -and $hasSingleEnd -and $end -gt $begin) {
      $afterEnd = $end + $endMarker.Length
      $prefix = $existing.Substring(0, $begin).TrimEnd("`r","`n")
      $suffix = $existing.Substring($afterEnd).TrimStart("`r","`n")
      $parts = @()
      if ($prefix.Length -gt 0) { $parts += $prefix; $parts += "" }
      $parts += $block.TrimEnd("`r","`n")
      if ($suffix.Length -gt 0) { $parts += ""; $parts += $suffix }
      $nextText = ($parts -join "`n") + "`n"
    } elseif ($begin -lt 0 -and $end -lt 0 -and (Test-LegacyRenderedBody -ExistingText $existing -RenderedBody $Body)) {
      $nextText = $block
    } else {
      Write-Host "[SKIP:conflict] unmanaged local file exists: $Dst"
      $Stats.skipped_files++
      return
    }
  }

  if ($IsDryRun) {
    if ($exists) { Write-Host "[DRY-RUN] update managed block: $Dst"; $Stats.updated_files++ }
    else { Write-Host "[DRY-RUN] create managed block: $Dst"; $Stats.created_files++ }
    return
  }

  $parent = Split-Path -Parent $Dst
  if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  Set-Content -LiteralPath $Dst -Encoding UTF8 -Value $nextText
  if ($exists) { $Stats.updated_files++ } else { $Stats.created_files++ }
}

function Write-ProjectLockfile(
  [string]$ProjectRoot,
  [string]$ConfigPath,
  [string[]]$InstallTargets,
  [string[]]$InstallPacks,
  [bool]$IsDryRun,
  [bool]$IsUpdateOnly,
  [bool]$DiffMode,
  [hashtable]$Stats
) {
  if ($IsDryRun -or $DiffMode) { return }

  $lockfilePath = Join-Path (Join-Path $ProjectRoot ".ai") "agent-orchestrator.lock.json"
  $payload = [ordered]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    installer = [ordered]@{
      name = "agent-orchestrator-installer"
      script = "scripts/install.ps1"
    }
    configPath = (([System.IO.Path]::GetFullPath([string]$ConfigPath)) -replace '\\','/')
    projectPath = (([System.IO.Path]::GetFullPath([string]$ProjectRoot)) -replace '\\','/')
    installTargets = @($InstallTargets)
    updateOnly = $IsUpdateOnly
    diffMode = $DiffMode
    managedFiles = @()
  }

  if ($null -ne $InstallPacks) {
    $payload["installPacks"] = @($InstallPacks)
  }

  $json = $payload | ConvertTo-Json -Depth 8
  Write-ManagedText -Text ($json + "`n") -Dst $lockfilePath -IsDryRun $false -IsUpdateOnly $IsUpdateOnly -Stats $Stats
}

function Copy-File-Safely([string]$Src, [string]$Dst, [bool]$IsDryRun, [bool]$IsUpdateOnly, [hashtable]$Stats) {
  $exists = Test-Path -LiteralPath $Dst
  if ($IsUpdateOnly -and -not $exists) { Write-Host "[SKIP:update-only] create file blocked: $Dst"; $Stats.skipped_files++; return }

  if ($IsDryRun) {
    if ($exists) { Write-Host "[DRY-RUN] update file: $Dst"; $Stats.updated_files++ }
    else { Write-Host "[DRY-RUN] create file: $Dst"; $Stats.created_files++ }
    return
  }

  $parent = Split-Path -Parent $Dst
  if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  Copy-Item -LiteralPath $Src -Destination $Dst -Force
  if ($exists) { $Stats.updated_files++ } else { $Stats.created_files++ }
}

function Copy-Dir-Files([string]$SrcDir, [string]$DstDir, [bool]$IsDryRun, [bool]$IsUpdateOnly, [hashtable]$Stats) {
  if (-not (Test-Path -LiteralPath $SrcDir)) { throw "Template directory not found: $SrcDir" }
  $ready = Ensure-Dir -Path $DstDir -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
  if (-not $ready) { return }

  Get-ChildItem -LiteralPath $SrcDir -File | ForEach-Object {
    Copy-File-Safely -Src $_.FullName -Dst (Join-Path $DstDir $_.Name) -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
  }
}

function Rebrand-AdminCoreText([string]$Text) {
  return $Text.
    Replace("PHOENIX","ADMINCORE").
    Replace("Phoenix","AdminCore").
    Replace("phoenix","admincore").
    Replace("Prium","AdminCore").
    Replace("prium","admincore").
    Replace("prium.github.io/phoenix","admincore.local/examples")
}

function Neutralize-AnchorHrefs([string]$Text) {
  $rx = New-Object System.Text.RegularExpressions.Regex '(<a\b[^>]*?\bhref\s*=\s*")([^"]*)(")', ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $evaluator = [System.Text.RegularExpressions.MatchEvaluator]{
    param($m)
    $href = $m.Groups[2].Value.Trim()
    if ($href.StartsWith("#") -or $href.StartsWith("mailto:") -or $href.StartsWith("tel:") -or $href.StartsWith("javascript:")) {
      return $m.Value
    }
    return $m.Groups[1].Value + "#" + $m.Groups[3].Value
  }
  return $rx.Replace($Text, $evaluator)
}

function Write-RebrandedTextFile([string]$Src, [string]$Dst, [bool]$IsDryRun, [bool]$IsUpdateOnly, [hashtable]$Stats) {
  $raw = Get-Content -LiteralPath $Src -Raw
  $reb = Rebrand-AdminCoreText -Text $raw
  if ([System.IO.Path]::GetExtension($Src).ToLower() -in @(".html",".htm")) {
    $reb = Neutralize-AnchorHrefs -Text $reb
  }
  Write-ManagedText -Text $reb -Dst $Dst -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
}

function Copy-RootMarkdown-Files([string]$SrcDir, [string]$DstDir, [bool]$IsDryRun, [bool]$IsUpdateOnly, [hashtable]$Stats) {
  if (-not (Test-Path -LiteralPath $SrcDir)) { return }
  $ready = Ensure-Dir -Path $DstDir -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
  if (-not $ready) { return }
  Get-ChildItem -LiteralPath $SrcDir -File | Where-Object { $_.Extension -eq ".md" } | ForEach-Object {
    Copy-File-Safely -Src $_.FullName -Dst (Join-Path $DstDir $_.Name) -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
  }
}

function Copy-TreeFiles([string]$SrcRoot, [string]$DstRoot, [bool]$IsDryRun, [bool]$IsUpdateOnly, [hashtable]$Stats) {
  if (-not (Test-Path -LiteralPath $SrcRoot)) { return }
  Get-ChildItem -LiteralPath $SrcRoot -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($SrcRoot.Length).TrimStart('\','/')
    $dst = Join-Path $DstRoot $rel
    Copy-File-Safely -Src $_.FullName -Dst $dst -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
  }
}

function Resolve-UserCodexHome([string]$RawValue) {
  if (-not [string]::IsNullOrWhiteSpace($RawValue)) {
    return [System.IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RawValue))
  }
  if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
    return [System.IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($env:CODEX_HOME))
  }
  return (Join-Path $HOME ".codex")
}

function Install-CodexCliForUser([bool]$ShouldInstall, [bool]$IsDryRun) {
  if (-not $ShouldInstall) { return }

  $codexCmd = Get-Command codex -ErrorAction SilentlyContinue
  if ($codexCmd) {
    Write-Host "Codex CLI already found in PATH."
    return
  }

  $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
  if (-not $npmCmd) {
    throw "npm was not found in PATH, so Codex CLI cannot be installed automatically."
  }

  if ($IsDryRun) {
    Write-Host "[DRY-RUN] would install Codex CLI for current user: npm install -g @openai/codex"
    return
  }

  Write-Host "Installing Codex CLI for current user via npm..."
  & $npmCmd.Source install -g @openai/codex
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to install @openai/codex via npm."
  }
}

function Install-CodexTemplates(
  [string]$RepoRoot,
  [string]$ProjectRoot,
  [string]$UserCodexHomePath,
  [string]$ProjectCodexDir,
  [hashtable]$Tokens,
  [string[]]$InstallTargets,
  [bool]$IsDryRun,
  [bool]$IsUpdateOnly,
  [hashtable]$Stats
) {
  $installCodexTarget = $InstallTargets -contains "codex"
  $installClaudeTarget = $InstallTargets -contains "claude"
  if ((-not $installCodexTarget) -and (-not $installClaudeTarget)) { return }

  $targetGlobalSkills = Join-Path $UserCodexHomePath "skills"
  $targetProjectContext = Join-Path $ProjectCodexDir "project-context"
  $targetProjectAgents = Join-Path $ProjectCodexDir "agents"

  if ($installCodexTarget) {
    Ensure-Dir -Path $targetGlobalSkills -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats | Out-Null
    Ensure-Dir -Path $ProjectCodexDir -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats | Out-Null
    Ensure-Dir -Path $targetProjectContext -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats | Out-Null
    Ensure-Dir -Path (Join-Path $targetProjectContext "dev") -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats | Out-Null
    Ensure-Dir -Path (Join-Path $targetProjectContext "rules") -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats | Out-Null
    Ensure-Dir -Path (Join-Path $targetProjectContext "modules") -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats | Out-Null
    Ensure-Dir -Path $targetProjectAgents -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats | Out-Null

    Copy-TreeFiles -SrcRoot (Join-Path $RepoRoot "templates/codex-global/skills") -DstRoot $targetGlobalSkills -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
    Copy-TreeFiles -SrcRoot (Join-Path $RepoRoot "templates/codex-project/agents") -DstRoot $targetProjectAgents -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
    Copy-TreeFiles -SrcRoot (Join-Path $RepoRoot "templates/codex-project/project-context/dev") -DstRoot (Join-Path $targetProjectContext "dev") -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
    Copy-TreeFiles -SrcRoot (Join-Path $RepoRoot "templates/codex-project/project-context/rules") -DstRoot (Join-Path $targetProjectContext "rules") -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
  }

  if ($installCodexTarget) {
    $codexReadme = Apply-Tokens -Text (Get-Content -LiteralPath (Join-Path $RepoRoot "templates/_render/codex-project-README.md.tpl") -Raw) -Tokens $Tokens
    Write-ManagedText -Text $codexReadme -Dst (Join-Path $ProjectCodexDir "README.md") -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats

    $sourceMap = Apply-Tokens -Text (Get-Content -LiteralPath (Join-Path $RepoRoot "templates/_render/codex-source-map.md.tpl") -Raw) -Tokens $Tokens
    Write-ManagedText -Text $sourceMap -Dst (Join-Path $targetProjectContext "source-map.md") -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats

    $agentsMd = Apply-Tokens -Text (Get-Content -LiteralPath (Join-Path $RepoRoot "templates/_render/AGENTS.md.tpl") -Raw) -Tokens $Tokens
    Write-ManagedBlockFile -Body $agentsMd -Dst (Join-Path $ProjectRoot "AGENTS.md") -BlockId "root-agents" -SourceTemplate "templates/_render/AGENTS.md.tpl" -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
  }

  if ($installClaudeTarget) {
    $claudeMd = Apply-Tokens -Text (Get-Content -LiteralPath (Join-Path $RepoRoot "templates/_render/CLAUDE.md.tpl") -Raw) -Tokens $Tokens
    Write-ManagedBlockFile -Body $claudeMd -Dst (Join-Path $ProjectRoot "CLAUDE.md") -BlockId "root-claude" -SourceTemplate "templates/_render/CLAUDE.md.tpl" -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
  }
}

function Sync-AnalysisIntoCodexProject(
  [string]$TargetDocs,
  [string]$ProjectCodexDir,
  [bool]$IsDryRun,
  [bool]$IsUpdateOnly,
  [hashtable]$Stats
) {
  $projectContext = Join-Path $ProjectCodexDir "project-context"
  Ensure-Dir -Path $projectContext -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats | Out-Null
  Ensure-Dir -Path (Join-Path $projectContext "modules") -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats | Out-Null

  foreach ($name in @("project-overview.md","analysis-summary.json")) {
    $src = Join-Path $TargetDocs $name
    if (Test-Path -LiteralPath $src) {
      Copy-File-Safely -Src $src -Dst (Join-Path $projectContext $name) -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
    }
  }

  $modulesDir = Join-Path $TargetDocs "modules"
  if (Test-Path -LiteralPath $modulesDir) {
    Copy-TreeFiles -SrcRoot $modulesDir -DstRoot (Join-Path $projectContext "modules") -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
  }
}

function Parse-EnabledPacks([object]$Config, [string]$CliPacks, [string[]]$SupportedPacks) {
  $packs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

  if (-not [string]::IsNullOrWhiteSpace($CliPacks)) {
    foreach ($p in ($CliPacks -split ",")) {
      $x = $p.Trim().ToLower()
      if ($x) { [void]$packs.Add($x) }
    }
  }

  if ($Config.PSObject.Properties.Name -contains "enabledPacks") {
    $cfgPacks = $Config.enabledPacks
    if ($cfgPacks -is [string]) {
      foreach ($p in ($cfgPacks -split ",")) {
        $x = $p.Trim().ToLower()
        if ($x) { [void]$packs.Add($x) }
      }
    } elseif ($cfgPacks -is [System.Collections.IEnumerable]) {
      foreach ($p in $cfgPacks) {
        $x = [string]$p
        $x = $x.Trim().ToLower()
        if ($x) { [void]$packs.Add($x) }
      }
    }
  }

  $unknown = @($packs | Where-Object { $SupportedPacks -notcontains $_ })
  if ($unknown.Count -gt 0) {
    throw "Unknown pack(s): $($unknown -join ', '). Supported packs: $($SupportedPacks -join ', ')"
  }

  return @($packs | Sort-Object)
}

function Parse-AdminUiBase([object]$Config, [string]$CliAdminUiBase) {
  $candidate = ""
  if (-not [string]::IsNullOrWhiteSpace($CliAdminUiBase)) {
    $candidate = $CliAdminUiBase.Trim().ToLower()
  } elseif ($Config.PSObject.Properties.Name -contains "adminUiBase" -and -not [string]::IsNullOrWhiteSpace([string]$Config.adminUiBase)) {
    $candidate = ([string]$Config.adminUiBase).Trim().ToLower()
  } else {
    $candidate = "admincore"
  }

  if (@("admincore","custom","none") -notcontains $candidate) {
    throw "Unknown admin UI base: $candidate. Supported: admincore, custom, none"
  }
  return $candidate
}

function Apply-DefaultRequiredPacks([string[]]$Packs, [string]$AdminUiBase) {
  $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($p in $Packs) { [void]$set.Add($p) }
  foreach ($p in $AlwaysRequiredPacks) { [void]$set.Add($p) }
  if ($AdminUiBase -ne "none") {
    foreach ($p in $ConditionalRequiredPacks) { [void]$set.Add($p) }
  }
  return @($set | Sort-Object)
}

function Parse-InstallTargets([object]$Config, [string]$CliTargets, [string[]]$SupportedTargets) {
  $targets = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

  # CLI targets have priority and override config targets.
  if (-not [string]::IsNullOrWhiteSpace($CliTargets)) {
    foreach ($t in ($CliTargets -split ",")) {
      $x = $t.Trim().ToLower()
      if ($x) { [void]$targets.Add($x) }
    }
  } else {
    if ($Config.PSObject.Properties.Name -contains "installTargets") {
      $cfgTargets = $Config.installTargets
      if ($cfgTargets -is [string]) {
        foreach ($t in ($cfgTargets -split ",")) {
          $x = $t.Trim().ToLower()
          if ($x) { [void]$targets.Add($x) }
        }
      } elseif ($cfgTargets -is [System.Collections.IEnumerable]) {
        foreach ($t in $cfgTargets) {
          $x = ([string]$t).Trim().ToLower()
          if ($x) { [void]$targets.Add($x) }
        }
      }
    }
  }

  if ($targets.Count -eq 0) {
    foreach ($t in $SupportedTargets) { [void]$targets.Add($t) }
  }

  $unknown = @($targets | Where-Object { $SupportedTargets -notcontains $_ })
  if ($unknown.Count -gt 0) {
    throw "Unknown install target(s): $($unknown -join ', '). Supported targets: $($SupportedTargets -join ', ')"
  }

  return @($targets | Sort-Object)
}

function Get-FileSha256([string]$Path) {
  $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
  return $hash.Hash.ToLower()
}

function Find-AdminUiSourceRoot([string]$RootPath) {
  if (Test-Path -LiteralPath (Join-Path $RootPath "assets/css/theme.min.css")) {
    return $RootPath
  }
  $dirs = Get-ChildItem -LiteralPath $RootPath -Directory -Recurse -ErrorAction SilentlyContinue
  foreach ($d in $dirs) {
    if (Test-Path -LiteralPath (Join-Path $d.FullName "assets/css/theme.min.css")) {
      return $d.FullName
    }
  }
  return $null
}

function Resolve-AdminUiSource(
  [string]$SourcePathRaw,
  [string]$SourceUrlRaw,
  [string]$SourceSha256,
  [string]$CacheDirRaw,
  [string]$ProjectRoot,
  [bool]$IsDryRun
) {
  if (-not [string]::IsNullOrWhiteSpace($SourcePathRaw) -and (Test-Path -LiteralPath $SourcePathRaw)) {
    return (Resolve-Path $SourcePathRaw).Path
  }

  if ([string]::IsNullOrWhiteSpace($SourceUrlRaw)) {
    return $null
  }

  if ($IsDryRun) {
    Write-Host "[DRY-RUN] would fetch admin UI source archive from: $SourceUrlRaw"
    return $null
  }

  $cacheDir = if (-not [string]::IsNullOrWhiteSpace($CacheDirRaw)) { $CacheDirRaw } else { Join-Path $ProjectRoot ".tmp/admin-ui-cache" }
  $downloadsDir = Join-Path $cacheDir "downloads"
  $extractedDir = Join-Path $cacheDir "extracted"
  New-Item -ItemType Directory -Path $downloadsDir -Force | Out-Null
  New-Item -ItemType Directory -Path $extractedDir -Force | Out-Null

  $zipPath = $null
  if ($SourceUrlRaw -match '^https?://') {
    $fileName = [System.IO.Path]::GetFileName(([System.Uri]$SourceUrlRaw).AbsolutePath)
    if ([string]::IsNullOrWhiteSpace($fileName)) { $fileName = "admin-ui-source.zip" }
    $zipPath = Join-Path $downloadsDir $fileName
    Write-Host "Downloading admin UI archive: $SourceUrlRaw"
    Invoke-WebRequest -Uri $SourceUrlRaw -OutFile $zipPath
  } else {
    $zipPath = $SourceUrlRaw
    if (-not (Test-Path -LiteralPath $zipPath)) {
      throw "Admin UI source URL/path not found: $SourceUrlRaw"
    }
  }

  if ([System.IO.Path]::GetExtension($zipPath).ToLower() -ne ".zip") {
    throw "Admin UI source must be a .zip archive: $zipPath"
  }

  $actualSha = Get-FileSha256 -Path $zipPath
  if (-not [string]::IsNullOrWhiteSpace($SourceSha256)) {
    if ($actualSha -ne $SourceSha256.Trim().ToLower()) {
      throw "Admin UI archive checksum mismatch: expected $($SourceSha256.Trim().ToLower()), got $actualSha"
    }
  }
  Write-Host "Admin UI archive sha256: $actualSha"

  $extractTarget = Join-Path $extractedDir $actualSha
  $marker = Join-Path $extractTarget ".extracted-ok"
  if (-not (Test-Path -LiteralPath $marker)) {
    if (Test-Path -LiteralPath $extractTarget) { Remove-Item -LiteralPath $extractTarget -Recurse -Force }
    New-Item -ItemType Directory -Path $extractTarget -Force | Out-Null
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractTarget -Force
    Set-Content -LiteralPath $marker -Value "ok" -Encoding UTF8
  }

  $root = Find-AdminUiSourceRoot -RootPath $extractTarget
  if (-not $root) {
    throw "Could not find valid admin UI source root in extracted archive. Expected assets/css/theme.min.css."
  }
  Write-Host "Admin UI source root: $root"
  return $root
}

function Install-AdminCoreAssets(
  [string]$TargetDocs,
  [string]$RepoRoot,
  [string]$AdminBase,
  [string]$AdminSourcePath,
  [bool]$IsDryRun,
  [bool]$IsUpdateOnly,
  [hashtable]$Stats
) {
  if ($AdminBase -ne "admincore") { return }

  $kitRoot = Join-Path $RepoRoot "templates/packs/admin-ui-foundation/shared-docs/assets/admincore"
  if (-not (Test-Path -LiteralPath $kitRoot)) { return }

  $targetCss = Join-Path $TargetDocs "assets/admincore/css"
  Ensure-Dir -Path $targetCss -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats | Out-Null

  $bundledTheme = Join-Path $kitRoot "css/admincore-theme.min.css"
  $bundledUser = Join-Path $kitRoot "css/admincore-user.min.css"
  if (Test-Path -LiteralPath $bundledTheme) {
    Copy-File-Safely -Src $bundledTheme -Dst (Join-Path $targetCss "admincore-theme.min.css") -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
  }
  if (Test-Path -LiteralPath $bundledUser) {
    Copy-File-Safely -Src $bundledUser -Dst (Join-Path $targetCss "admincore-user.min.css") -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
  }

  if ([string]::IsNullOrWhiteSpace($AdminSourcePath)) { return }
  if (-not (Test-Path -LiteralPath $AdminSourcePath)) { return }

  $sourceTheme = Join-Path $AdminSourcePath "assets/css/theme.min.css"
  $sourceUser = Join-Path $AdminSourcePath "assets/css/user.min.css"
  if (Test-Path -LiteralPath $sourceTheme) {
    Write-RebrandedTextFile -Src $sourceTheme -Dst (Join-Path $targetCss "admincore-theme.min.css") -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
  }
  if (Test-Path -LiteralPath $sourceUser) {
    Write-RebrandedTextFile -Src $sourceUser -Dst (Join-Path $targetCss "admincore-user.min.css") -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
  }

  $exampleRoot = Join-Path $TargetDocs "assets/admincore/examples"
  $moduleRoots = @(
    (Join-Path $AdminSourcePath "modules/components"),
    (Join-Path $AdminSourcePath "modules/forms"),
    (Join-Path $AdminSourcePath "modules/tables"),
    (Join-Path $AdminSourcePath "modules/echarts")
  )
  $copied = @()
  foreach ($root in $moduleRoots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    Get-ChildItem -LiteralPath $root -Recurse -File -Filter *.html | ForEach-Object {
      $rel = $_.FullName.Substring($AdminSourcePath.Length).TrimStart('\','/') -replace '\\','/'
      $dst = Join-Path $exampleRoot $rel
      Write-RebrandedTextFile -Src $_.FullName -Dst $dst -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
      $copied += $rel
    }
  }

  if ($copied.Count -gt 0) {
    $lines = @(
      "# AdminCore Component Catalog",
      "",
      "Generated from source examples. Use these files as the canonical reference when composing admin UI.",
      "",
      "## Example Files"
    )
    $lines += ($copied | Select-Object -First 250 | ForEach-Object { '- ' + [char]96 + $_ + [char]96 })
    $lines += ""
    Write-ManagedText -Text ($lines -join "`n") -Dst (Join-Path $TargetDocs "tools/ADMINCORE-COMPONENT-CATALOG.md") -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
  }
}

function Get-RelativePath([string]$Base, [string]$Full) {
  $basePath = [System.IO.Path]::GetFullPath($Base)
  $fullPath = [System.IO.Path]::GetFullPath($Full)
  if ($fullPath.StartsWith($basePath)) {
    return $fullPath.Substring($basePath.Length).TrimStart('\','/') -replace '\\','/'
  }
  return $fullPath -replace '\\','/'
}

function Build-Bullets([string[]]$Items, [string]$EmptyText) {
  if (-not $Items -or $Items.Count -eq 0) { return "- $EmptyText" }
  return ($Items | ForEach-Object { "- $($_)" }) -join "`n"
}

function Build-ModuleDoc([string]$Title, [string[]]$Items, [string]$ProjectName) {
  $lines = @(
    "# $Title",
    "",
    "Project: $ProjectName",
    "Updated: $(Get-Date -Format 'yyyy-MM-dd')",
    "",
    "## Findings",
    (Build-Bullets -Items $Items -EmptyText "No findings yet."),
    ""
  )
  return ($lines -join "`n")
}

function Get-ProjectFiles([string]$ProjectRoot) {
  $all = Get-ChildItem -Path $ProjectRoot -Recurse -File -ErrorAction SilentlyContinue
  return $all | Where-Object {
    $path = $_.FullName.ToLower()
    $blocked = $false
    foreach ($d in $ExcludedDirs) {
      if ($path -match "[\\/]$([regex]::Escape($d))[\\/]") { $blocked = $true; break }
    }
    -not $blocked
  }
}

function Analyze-Project(
  [string]$ProjectName,
  [string]$ProjectRoot,
  [string]$TargetDocs,
  [int]$SplitThreshold,
  [string]$AnalyzeProfile,
  [bool]$IsDryRun,
  [bool]$IsUpdateOnly,
  [hashtable]$Stats
) {
  $topDirs = Get-ChildItem -Path $ProjectRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $ExcludedDirs -notcontains $_.Name } |
    Select-Object -ExpandProperty Name

  $files = Get-ProjectFiles -ProjectRoot $ProjectRoot

  $manifestFlags = @{
    packageJson = (Test-Path (Join-Path $ProjectRoot 'package.json'))
    pyproject = (Test-Path (Join-Path $ProjectRoot 'pyproject.toml'))
    requirements = (Test-Path (Join-Path $ProjectRoot 'requirements.txt'))
    goMod = (Test-Path (Join-Path $ProjectRoot 'go.mod'))
    cargo = (Test-Path (Join-Path $ProjectRoot 'Cargo.toml'))
    pom = (Test-Path (Join-Path $ProjectRoot 'pom.xml'))
    dockerfile = (Test-Path (Join-Path $ProjectRoot 'Dockerfile'))
    composeYml = (Test-Path (Join-Path $ProjectRoot 'docker-compose.yml'))
    composeYaml = (Test-Path (Join-Path $ProjectRoot 'docker-compose.yaml'))
    makefile = (Test-Path (Join-Path $ProjectRoot 'Makefile'))
  }

  $readmeExists = $false
  $ciFiles = @()
  $dockerFiles = @()
  $docsMdFiles = @()
  $docsMdDirs = @()
  $uiItems = @()
  $serverItems = @()
  $serviceItems = @()

  $codeExt = @('.js','.ts','.tsx','.jsx','.py','.go','.java','.kt','.rs','.cs','.php')
  $codeFilesCount = 0

  foreach ($f in $files) {
    $rel = Get-RelativePath -Base $ProjectRoot -Full $f.FullName
    $name = $f.Name.ToLower()
    if ($codeExt -contains $f.Extension.ToLower()) { $codeFilesCount++ }
    if ($name.StartsWith('readme')) { $readmeExists = $true }
    if ($rel -like '.github/workflows/*') { $ciFiles += $rel }
    if ($name -eq 'dockerfile' -or $name -eq 'docker-compose.yml' -or $name -eq 'docker-compose.yaml') { $dockerFiles += $rel }
    if ($name.EndsWith('.md')) {
      if ($docsMdFiles.Count -lt 80) { $docsMdFiles += $rel }
      $parent = [System.IO.Path]::GetDirectoryName($rel)
      if ([string]::IsNullOrWhiteSpace($parent)) { $parent = "." }
      $parent = $parent -replace '\\','/'
      $docsMdDirs += $parent
    }

    $low = $rel.ToLower()
    if ($low -match '(ui|frontend|client|web|components|pages)') { $uiItems += $rel }
    if ($low -match '(server|backend|api|route|controller)') { $serverItems += $rel }
    if ($low -match '(services|workers|jobs|queues|consumer|producer|scheduler)') { $serviceItems += $rel }
  }

  foreach ($d in $topDirs) {
    $low = $d.ToLower()
    if ($low -match '^(ui|frontend|client|web|dashboard)$') { $uiItems += "directory: $d" }
    if ($low -match '^(server|backend|api)$') { $serverItems += "directory: $d" }
    if ($low -match '^(services|workers|jobs|queues)$') { $serviceItems += "directory: $d" }
  }

  $uiItems = $uiItems | Select-Object -Unique
  $serverItems = $serverItems | Select-Object -Unique
  $serviceItems = $serviceItems | Select-Object -Unique
  $infraItems = @($dockerFiles + $ciFiles | Select-Object -Unique)
  $docsItems = @($docsMdDirs + $docsMdFiles | Select-Object -Unique)

  $commands = @()
  $packageJsonPath = Join-Path $ProjectRoot 'package.json'
  if (Test-Path $packageJsonPath) {
    try {
      $pkg = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json
      if ($pkg.scripts) {
        $keys = @('dev','start','build','test','lint') | Where-Object { $pkg.scripts.PSObject.Properties.Name -contains $_ }
        if ($keys.Count -gt 0) { $commands += ('npm: ' + (($keys | ForEach-Object { "npm run $_" }) -join ', ')) }
      }
    } catch {}
  }
  $effectiveProfile = $AnalyzeProfile
  if ($effectiveProfile -eq "auto") {
    if ($manifestFlags.packageJson) { $effectiveProfile = "node" }
    elseif ($manifestFlags.pyproject -or $manifestFlags.requirements) { $effectiveProfile = "python" }
    elseif ($manifestFlags.goMod) { $effectiveProfile = "go" }
    elseif ($manifestFlags.pom) { $effectiveProfile = "java" }
    else { $effectiveProfile = "generic" }
  }

  if ($manifestFlags.makefile) { $commands += 'make: inspect targets in Makefile' }
  if ($effectiveProfile -eq "python" -or $manifestFlags.pyproject -or $manifestFlags.requirements) { $commands += 'python: define standard run/test commands' }
  if ($effectiveProfile -eq "go" -or $manifestFlags.goMod) { $commands += 'go: go test ./..., go run ./...' }
  if ($effectiveProfile -eq "java" -and $manifestFlags.pom) { $commands += 'java(maven): mvn test, mvn package' }
  if ($effectiveProfile -eq "node" -and $commands.Count -eq 0) { $commands += 'node: define npm scripts for dev/build/test' }

  $risks = @()
  if ($codeFilesCount -eq 0) { $risks += 'Project looks new or empty: no code files detected.' }
  if (-not $readmeExists) { $risks += 'README not found.' }
  if ($commands.Count -eq 0) { $risks += 'No explicit run/test commands detected.' }
  if ($ciFiles.Count -eq 0) { $risks += 'No CI workflow detected in .github/workflows.' }
  if ($docsItems.Count -eq 0) { $risks += 'No markdown documentation folders/files detected.' }

  $unknowns = @()
  if ($uiItems.Count -eq 0) { $unknowns += 'UI module not clearly detected.' }
  if ($serverItems.Count -eq 0) { $unknowns += 'Server/API module not clearly detected.' }
  if ($serviceItems.Count -eq 0) { $unknowns += 'Service/worker module not clearly detected.' }
  if ($docsItems.Count -eq 0) { $unknowns += 'Project documentation sources are unclear.' }

  $manifests = @()
  if ($manifestFlags.packageJson) { $manifests += 'package.json' }
  if ($manifestFlags.pyproject) { $manifests += 'pyproject.toml' }
  if ($manifestFlags.requirements) { $manifests += 'requirements.txt' }
  if ($manifestFlags.goMod) { $manifests += 'go.mod' }
  if ($manifestFlags.cargo) { $manifests += 'Cargo.toml' }
  if ($manifestFlags.pom) { $manifests += 'pom.xml' }
  if ($manifestFlags.dockerfile) { $manifests += 'Dockerfile' }
  if ($manifestFlags.composeYml) { $manifests += 'docker-compose.yml' }
  if ($manifestFlags.composeYaml) { $manifests += 'docker-compose.yaml' }
  if ($manifestFlags.makefile) { $manifests += 'Makefile' }
  if ($readmeExists) { $manifests += 'README' }
  if ($ciFiles.Count -gt 0) { $manifests += 'CI' }

  $moduleFiles = @{}

  function Section-Or-Link([string]$Title, [string]$Key, [string[]]$Items) {
    if ($Items.Count -gt $SplitThreshold) {
      $rel = "modules/$Key.md"
      $moduleFiles[$rel] = Build-ModuleDoc -Title $Title -Items $Items -ProjectName $ProjectName
      return @(
        "### $Title",
        "- Summary:",
        "  - total findings: $($Items.Count)",
        "  - details: [$rel]($rel)"
      ) -join "`n"
    }
    return @("### $Title", (Build-Bullets -Items $Items -EmptyText 'No findings yet.')) -join "`n"
  }

  $bootstrap = @()
  if ($codeFilesCount -eq 0) {
    $bootstrap = @(
      'Create base folders (`src/`, `tests/`, `docs/`) for your stack.',
      'Add root README with run/build/test commands.',
      'Define minimal CI workflow in `.github/workflows`.',
      'Run analyzer again after first scaffold commit.'
    )
  }

  $overviewLines = @(
    "# Project Overview: $ProjectName",
    "",
    "Updated: $(Get-Date -Format 'yyyy-MM-dd')",
    ("Project root: " + ($ProjectRoot -replace '\\','/') ),
    "",
    "## Project Snapshot",
    "- Analysis profile: **$effectiveProfile**",
    "- Code files detected: **$codeFilesCount**",
    "- Top-level directories: **$($topDirs.Count)**",
    "- Manifests detected: $([string]::Join(', ', $manifests))",
    "",
    "## Repository Map",
    (Build-Bullets -Items $topDirs -EmptyText 'No top-level directories found.'),
    "",
    "## Module Breakdown",
    (Section-Or-Link -Title 'Docs Intake' -Key 'docs' -Items $docsItems),
    "",
    (Section-Or-Link -Title 'UI' -Key 'ui' -Items $uiItems),
    "",
    (Section-Or-Link -Title 'Server/API' -Key 'server' -Items $serverItems),
    "",
    (Section-Or-Link -Title 'Services/Workers' -Key 'services' -Items $serviceItems),
    "",
    (Section-Or-Link -Title 'Infra/CI' -Key 'infra' -Items $infraItems),
    "",
    "## Run/Test/Build Commands",
    (Build-Bullets -Items $commands -EmptyText 'No commands auto-detected. Add them to README and/or package manifests.'),
    "",
    "## Risks",
    (Build-Bullets -Items $risks -EmptyText 'No immediate risks detected.'),
    "",
    "## Unknowns",
    (Build-Bullets -Items $unknowns -EmptyText 'No major unknowns detected.'),
    "",
    "## Suggested Agent Profile",
    "- Default: Orchestrator + SC-Agent + CR-Agent",
    "- Add UI-Test-Agent if UI module exists",
    "- Add VALIDATION-Agent for write APIs and schema-heavy backends",
    ""
  )

  if ($effectiveProfile -eq "node") {
    $overviewLines[($overviewLines.Count-4)] = "- Orchestrator + SC-Agent + CR-Agent"
    $overviewLines[($overviewLines.Count-3)] = "- UI-Test-Agent for React/Vue screens"
    $overviewLines[($overviewLines.Count-2)] = "- VALIDATION-Agent for API payload contracts"
  } elseif ($effectiveProfile -eq "python") {
    $overviewLines[($overviewLines.Count-4)] = "- Orchestrator + SC-Agent + CR-Agent"
    $overviewLines[($overviewLines.Count-3)] = "- Focus SC-Agent on service modules and tests"
    $overviewLines[($overviewLines.Count-2)] = "- Add UI-Test-Agent only if separate frontend exists"
  } elseif ($effectiveProfile -eq "go") {
    $overviewLines[($overviewLines.Count-4)] = "- Orchestrator + SC-Agent + CR-Agent"
    $overviewLines[($overviewLines.Count-3)] = "- Focus SC-Agent on handlers/services and integration tests"
    $overviewLines[($overviewLines.Count-2)] = "- Add VALIDATION-Agent for request validation layers"
  } elseif ($effectiveProfile -eq "java") {
    $overviewLines[($overviewLines.Count-4)] = "- Orchestrator + SC-Agent + CR-Agent"
    $overviewLines[($overviewLines.Count-3)] = "- Focus SC-Agent on controllers/services/repositories"
    $overviewLines[($overviewLines.Count-2)] = "- Add UI-Test-Agent only if UI module is present"
  }

  if ($bootstrap.Count -gt 0) {
    $overviewLines += @("## New Project Bootstrap Notes", (Build-Bullets -Items $bootstrap -EmptyText 'No bootstrap notes.'), "")
  }

  $overviewPath = Join-Path $TargetDocs 'project-overview.md'
  Write-ManagedText -Text ($overviewLines -join "`n") -Dst $overviewPath -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats

  if ($moduleFiles.Count -gt 0) {
    $modulesDir = Join-Path $TargetDocs 'modules'
    $ready = Ensure-Dir -Path $modulesDir -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
    if ($ready) {
      foreach ($k in $moduleFiles.Keys) {
        Write-ManagedText -Text $moduleFiles[$k] -Dst (Join-Path $TargetDocs $k) -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
      }
    }
  }

  $summary = @{
    projectName = $ProjectName
    projectRoot = ($ProjectRoot -replace '\\','/')
    analysisProfile = $effectiveProfile
    codeFilesCount = $codeFilesCount
    topLevelDirectories = $topDirs.Count
    manifestsDetected = $manifests
    moduleItemsCount = @{
      docs = ($docsMdDirs.Count + $docsMdFiles.Count)
      ui = $uiItems.Count
      server = $serverItems.Count
      services = $serviceItems.Count
      infra = ($dockerFiles.Count + $ciFiles.Count)
    }
    generatedAt = (Get-Date -Format 'yyyy-MM-dd')
  } | ConvertTo-Json -Depth 5

  Write-ManagedText -Text ($summary + "`n") -Dst (Join-Path $TargetDocs 'analysis-summary.json') -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$noWriteMode = [bool]($DryRun -or $Diff)
$configCandidatePath = [System.IO.Path]::GetFullPath($ConfigPath)
Ensure-ConfigFile -Path $configCandidatePath -NoWrite $noWriteMode
$configPathResolved = Resolve-Path $ConfigPath
$config = Read-Config -Path $configPathResolved

$projectName = [string]$config.projectName
$projectRoot = [string]$config.projectRoot
$codexHome = if ($config.codexHome) { [string]$config.codexHome } else { Join-Path $projectRoot ".ai" }
$mainBranch = if ($config.mainBranch) { [string]$config.mainBranch } else { "main" }
$taskPrefix = if ($config.taskPrefix) { [string]$config.taskPrefix } else { "TASK" }
$authProvider = if ($config.authProvider) { [string]$config.authProvider } else { "TBD" }
$complianceRequirements = if ($config.complianceRequirements) { [string]$config.complianceRequirements } else { "TBD" }
$a11yLevel = if ($config.a11yLevel) { [string]$config.a11yLevel } else { "WCAG 2.1 AA" }
$language = if ($config.language) { [string]$config.language } else { "TBD" }
$framework = if ($config.framework) { [string]$config.framework } else { "TBD" }
$database = if ($config.database) { [string]$config.database } else { "TBD" }
$hosting = if ($config.hosting) { [string]$config.hosting } else { "TBD" }
$sharedTypesPath = if ($config.sharedTypesPath) { [string]$config.sharedTypesPath } else { "src/shared/types" }
$installCodexCliFlag = if ($InstallCodexCli) { $true } elseif ($config.PSObject.Properties.Name -contains "installCodexCli") { [bool]$config.installCodexCli } else { $false }
$effectiveUserCodexHome = if (-not [string]::IsNullOrWhiteSpace($UserCodexHome)) { Resolve-UserCodexHome -RawValue $UserCodexHome } elseif ($config.PSObject.Properties.Name -contains "userCodexHome" -and -not [string]::IsNullOrWhiteSpace([string]$config.userCodexHome)) { Resolve-UserCodexHome -RawValue ([string]$config.userCodexHome) } else { Resolve-UserCodexHome -RawValue "" }
$projectCodexDir = if ($config.PSObject.Properties.Name -contains "projectCodexDir" -and -not [string]::IsNullOrWhiteSpace([string]$config.projectCodexDir)) { [string]$config.projectCodexDir } else { Join-Path $projectRoot ".codex" }
$installTargetsEffective = Parse-InstallTargets -Config $config -CliTargets $InstallTargets -SupportedTargets $AvailableInstallTargets
$enabledPacks = Parse-EnabledPacks -Config $config -CliPacks $EnablePack -SupportedPacks $AvailablePacks
$effectiveAdminUiBase = Parse-AdminUiBase -Config $config -CliAdminUiBase $AdminUiBase
$effectiveAdminUiSource = if (-not [string]::IsNullOrWhiteSpace($AdminUiSource)) { $AdminUiSource } elseif ($config.PSObject.Properties.Name -contains "adminUiSourcePath") { [string]$config.adminUiSourcePath } else { "" }
$effectiveAdminUiSourceUrl = if (-not [string]::IsNullOrWhiteSpace($AdminUiSourceUrl)) { $AdminUiSourceUrl } elseif ($config.PSObject.Properties.Name -contains "adminUiSourceUrl") { [string]$config.adminUiSourceUrl } else { "" }
$effectiveAdminUiSha256 = if (-not [string]::IsNullOrWhiteSpace($AdminUiSha256)) { $AdminUiSha256 } elseif ($config.PSObject.Properties.Name -contains "adminUiSourceSha256") { [string]$config.adminUiSourceSha256 } else { "" }
$effectiveAdminUiCacheDir = if (-not [string]::IsNullOrWhiteSpace($AdminUiCacheDir)) { $AdminUiCacheDir } elseif ($config.PSObject.Properties.Name -contains "adminUiCacheDir") { [string]$config.adminUiCacheDir } else { "" }
$enabledPacks = Apply-DefaultRequiredPacks -Packs $enabledPacks -AdminUiBase $effectiveAdminUiBase

if ([string]::IsNullOrWhiteSpace($projectName) -or [string]::IsNullOrWhiteSpace($projectRoot)) {
  throw "projectName and projectRoot are required"
}

$targetCopilot = Join-Path $codexHome "copilot-config"
$targetAgents = Join-Path $targetCopilot "agents"
$targetDocs = Join-Path $codexHome "shared-docs"
$resolvedAdminUiSource = $null
if (($enabledPacks -contains "admin-ui-foundation") -and $effectiveAdminUiBase -eq "admincore") {
  $resolvedAdminUiSource = Resolve-AdminUiSource -SourcePathRaw $effectiveAdminUiSource -SourceUrlRaw $effectiveAdminUiSourceUrl -SourceSha256 $effectiveAdminUiSha256 -CacheDirRaw $effectiveAdminUiCacheDir -ProjectRoot $projectRoot -IsDryRun $noWriteMode
}

$stats = @{ created_dirs = 0; created_files = 0; updated_files = 0; skipped_files = 0 }

Write-Host "Mode:"
Write-Host "- dry-run: $DryRun"
Write-Host "- diff: $Diff"
Write-Host "- update-only: $UpdateOnly"
Write-Host "- analyze-project: $AnalyzeProject"
Write-Host "- analyze-only: $AnalyzeOnly"
Write-Host "- analyze-profile: $AnalyzeProfile"
Write-Host "- enabled packs: $(if ($enabledPacks.Count -gt 0) { $enabledPacks -join ', ' } else { 'none' })"
Write-Host "- admin ui base: $effectiveAdminUiBase"
Write-Host "- admin ui source path: $(if (-not [string]::IsNullOrWhiteSpace($effectiveAdminUiSource)) { $effectiveAdminUiSource } else { 'none' })"
Write-Host "- admin ui source url: $(if (-not [string]::IsNullOrWhiteSpace($effectiveAdminUiSourceUrl)) { $effectiveAdminUiSourceUrl } else { 'none' })"
Write-Host "- admin ui source resolved: $(if (-not [string]::IsNullOrWhiteSpace($resolvedAdminUiSource)) { $resolvedAdminUiSource } else { 'none' })"
Write-Host "- target codex home: $codexHome"
Write-Host "- user codex home: $effectiveUserCodexHome"
Write-Host "- project codex dir: $projectCodexDir"
Write-Host "- install codex cli: $installCodexCliFlag"
Write-Host "- install targets: $($installTargetsEffective -join ', ')"

Install-CodexCliForUser -ShouldInstall $installCodexCliFlag -IsDryRun $noWriteMode

if (-not $AnalyzeOnly) {
  if ($installTargetsEffective -contains "copilot") {
    Ensure-Dir -Path $targetCopilot -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats | Out-Null
    Ensure-Dir -Path $targetAgents -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats | Out-Null
    Ensure-Dir -Path $targetDocs -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats | Out-Null
    Ensure-Dir -Path (Join-Path $targetDocs "dev") -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats | Out-Null
    Ensure-Dir -Path (Join-Path $targetDocs "rules") -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats | Out-Null

    Copy-Dir-Files -SrcDir (Join-Path $repoRoot "templates/copilot-config/agents") -DstDir $targetAgents -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats
    Copy-Dir-Files -SrcDir (Join-Path $repoRoot "templates/shared-docs/dev") -DstDir (Join-Path $targetDocs "dev") -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats
    Copy-Dir-Files -SrcDir (Join-Path $repoRoot "templates/shared-docs/rules") -DstDir (Join-Path $targetDocs "rules") -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats
    Copy-RootMarkdown-Files -SrcDir (Join-Path $repoRoot "templates/shared-docs") -DstDir $targetDocs -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats

    foreach ($pack in $enabledPacks) {
      $packRoot = Join-Path $repoRoot "templates/packs/$pack"
      if (-not (Test-Path -LiteralPath $packRoot)) { continue }
      $packAgents = Join-Path $packRoot "copilot-config/agents"
      $packShared = Join-Path $packRoot "shared-docs"

      if (Test-Path -LiteralPath $packAgents) {
        Copy-Dir-Files -SrcDir $packAgents -DstDir $targetAgents -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats
      }
      if (Test-Path -LiteralPath $packShared) {
        Copy-TreeFiles -SrcRoot $packShared -DstRoot $targetDocs -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats
      }
    }

    if ($enabledPacks -contains "admin-ui-foundation") {
      Install-AdminCoreAssets -TargetDocs $targetDocs -RepoRoot $repoRoot -AdminBase $effectiveAdminUiBase -AdminSourcePath $resolvedAdminUiSource -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats
    }
  }

  $tokens = @{
    "PROJECT_NAME" = $projectName
    "PROJECT_ROOT" = ($projectRoot -replace "\\", "/")
    "CODEX_HOME" = ($codexHome -replace "\\", "/")
    "USER_CODEX_HOME" = ($effectiveUserCodexHome -replace "\\", "/")
    "PROJECT_CODEX_DIR" = ($projectCodexDir -replace "\\", "/")
    "MAIN_BRANCH" = $mainBranch
    "TASK_PREFIX" = $taskPrefix
    "DATE" = (Get-Date -Format "yyyy-MM-dd")
    "AUTH_PROVIDER" = $authProvider
    "COMPLIANCE_REQUIREMENTS" = $complianceRequirements
    "A11Y_LEVEL" = $a11yLevel
    "LANGUAGE" = $language
    "FRAMEWORK" = $framework
    "DATABASE" = $database
    "HOSTING" = $hosting
    "SHARED_TYPES_PATH" = $sharedTypesPath
  }

  if ($installTargetsEffective -contains "copilot") {
    $templatePath = Join-Path $repoRoot "templates/copilot-config/copilot-instructions.md"
    $templateRaw = Get-Content -LiteralPath $templatePath -Raw
    $rendered = Apply-Tokens -Text $templateRaw -Tokens $tokens
    Write-ManagedText -Text $rendered -Dst (Join-Path $targetCopilot "copilot-instructions.md") -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats

    $constitutionPath = Join-Path $repoRoot "templates/_render/CONSTITUTION.md.tpl"
    if (Test-Path -LiteralPath $constitutionPath) {
      $constitutionRaw = Get-Content -LiteralPath $constitutionPath -Raw
      $constitutionRendered = Apply-Tokens -Text $constitutionRaw -Tokens $tokens
      Write-ManagedText -Text $constitutionRendered -Dst (Join-Path $targetDocs "rules/CONSTITUTION.md") -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats
    }

    $qualityPath = Join-Path $repoRoot "templates/_render/QUALITY-GATES.md.tpl"
    if (Test-Path -LiteralPath $qualityPath) {
      $qualityRaw = Get-Content -LiteralPath $qualityPath -Raw
      $qualityRendered = Apply-Tokens -Text $qualityRaw -Tokens $tokens
      Write-ManagedText -Text $qualityRendered -Dst (Join-Path $targetDocs "rules/QUALITY-GATES.md") -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats
    }
  }

  Install-CodexTemplates -RepoRoot $repoRoot -ProjectRoot $projectRoot -UserCodexHomePath $effectiveUserCodexHome -ProjectCodexDir $projectCodexDir -Tokens $tokens -InstallTargets $installTargetsEffective -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats
}

if (-not $NoSecondStepPrompt -and -not $AnalyzeProject -and -not $AnalyzeOnly -and -not $noWriteMode) {
  $answer = Read-Host "Run second step now: generate project overview analysis? [y/N]"
  if ($answer -and $answer.Trim().ToLower() -in @("y","yes")) {
    $AnalyzeProject = $true
  }
}

if ($AnalyzeProject -and ($installTargetsEffective -contains "copilot")) {
  Ensure-Dir -Path $targetDocs -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats | Out-Null
  Analyze-Project -ProjectName $projectName -ProjectRoot $projectRoot -TargetDocs $targetDocs -SplitThreshold ([Math]::Max(1,$ModuleSplitThreshold)) -AnalyzeProfile $AnalyzeProfile -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats
  if ($installTargetsEffective -contains "codex") {
    Sync-AnalysisIntoCodexProject -TargetDocs $targetDocs -ProjectCodexDir $projectCodexDir -IsDryRun $noWriteMode -IsUpdateOnly $UpdateOnly -Stats $stats
  }
}

Write-ProjectLockfile -ProjectRoot $projectRoot -ConfigPath $configPathResolved -InstallTargets $installTargetsEffective -InstallPacks $enabledPacks -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -DiffMode $Diff -Stats $stats

Write-Host ""
Write-Host "Done"
Write-Host "Project: $projectName"
Write-Host "Codex Home: $codexHome"
Write-Host "User Codex Home: $effectiveUserCodexHome"
Write-Host "Project Codex Dir: $projectCodexDir"
Write-Host "Agents: $targetAgents"
Write-Host "Docs: $targetDocs"
Write-Host "Summary:"
Write-Host "- dirs created: $($stats.created_dirs)"
Write-Host "- files created: $($stats.created_files)"
Write-Host "- files updated: $($stats.updated_files)"
Write-Host "- files skipped: $($stats.skipped_files)"
if ($noWriteMode) { Write-Host ""; Write-Host "No files were changed ($(if ($Diff) { 'diff' } else { 'dry-run' }))." }


