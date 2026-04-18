<#
.SYNOPSIS
Installs agent templates and optionally analyzes a project.

.DESCRIPTION
Stage 1: install copilot/shared-docs templates into target project.
Stage 2: optional project analysis with overview docs generation.

.PARAMETER ConfigPath
Path to JSON config file with projectName/projectRoot and optional fields.

.PARAMETER DryRun
Preview all planned file operations without writing changes.

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
Optional comma-separated packs to install (currently: session-state).

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
#>

param(
  [Parameter(Mandatory=$false)]
  [string]$ConfigPath = ".\project.config.json",
  [switch]$DryRun,
  [switch]$UpdateOnly,
  [switch]$AnalyzeProject,
  [switch]$AnalyzeOnly,
  [int]$ModuleSplitThreshold = 12,
  [ValidateSet("auto","node","python","go","java","generic")]
  [string]$AnalyzeProfile = "auto",
  [switch]$NoSecondStepPrompt,
  [string]$EnablePack = ""
)

$ErrorActionPreference = "Stop"

$ExcludedDirs = @('.git','node_modules','dist','build','.venv','venv','target','out','.next','.idea','.vscode','.ai')
$AvailablePacks = @('session-state')

function Read-Config([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "Config not found: $Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
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

function Copy-RootMarkdown-Files([string]$SrcDir, [string]$DstDir, [bool]$IsDryRun, [bool]$IsUpdateOnly, [hashtable]$Stats) {
  if (-not (Test-Path -LiteralPath $SrcDir)) { return }
  $ready = Ensure-Dir -Path $DstDir -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
  if (-not $ready) { return }
  Get-ChildItem -LiteralPath $SrcDir -File | Where-Object { $_.Extension -eq ".md" } | ForEach-Object {
    Copy-File-Safely -Src $_.FullName -Dst (Join-Path $DstDir $_.Name) -IsDryRun $IsDryRun -IsUpdateOnly $IsUpdateOnly -Stats $Stats
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
$enabledPacks = Parse-EnabledPacks -Config $config -CliPacks $EnablePack -SupportedPacks $AvailablePacks

if ([string]::IsNullOrWhiteSpace($projectName) -or [string]::IsNullOrWhiteSpace($projectRoot)) {
  throw "projectName and projectRoot are required"
}

$targetCopilot = Join-Path $codexHome "copilot-config"
$targetAgents = Join-Path $targetCopilot "agents"
$targetDocs = Join-Path $codexHome "shared-docs"

$stats = @{ created_dirs = 0; created_files = 0; updated_files = 0; skipped_files = 0 }

Write-Host "Mode:"
Write-Host "- dry-run: $DryRun"
Write-Host "- update-only: $UpdateOnly"
Write-Host "- analyze-project: $AnalyzeProject"
Write-Host "- analyze-only: $AnalyzeOnly"
Write-Host "- analyze-profile: $AnalyzeProfile"
Write-Host "- enabled packs: $(if ($enabledPacks.Count -gt 0) { $enabledPacks -join ', ' } else { 'none' })"
Write-Host "- target codex home: $codexHome"

if (-not $AnalyzeOnly) {
  Ensure-Dir -Path $targetCopilot -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -Stats $stats | Out-Null
  Ensure-Dir -Path $targetAgents -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -Stats $stats | Out-Null
  Ensure-Dir -Path $targetDocs -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -Stats $stats | Out-Null
  Ensure-Dir -Path (Join-Path $targetDocs "dev") -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -Stats $stats | Out-Null
  Ensure-Dir -Path (Join-Path $targetDocs "rules") -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -Stats $stats | Out-Null

  Copy-Dir-Files -SrcDir (Join-Path $repoRoot "templates/copilot-config/agents") -DstDir $targetAgents -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -Stats $stats
  Copy-Dir-Files -SrcDir (Join-Path $repoRoot "templates/shared-docs/dev") -DstDir (Join-Path $targetDocs "dev") -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -Stats $stats
  Copy-Dir-Files -SrcDir (Join-Path $repoRoot "templates/shared-docs/rules") -DstDir (Join-Path $targetDocs "rules") -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -Stats $stats
  Copy-RootMarkdown-Files -SrcDir (Join-Path $repoRoot "templates/shared-docs") -DstDir $targetDocs -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -Stats $stats

  foreach ($pack in $enabledPacks) {
    $packRoot = Join-Path $repoRoot "templates/packs/$pack"
    if (-not (Test-Path -LiteralPath $packRoot)) { continue }
    $packAgents = Join-Path $packRoot "copilot-config/agents"
    $packDev = Join-Path $packRoot "shared-docs/dev"
    $packRules = Join-Path $packRoot "shared-docs/rules"
    $packShared = Join-Path $packRoot "shared-docs"

    if (Test-Path -LiteralPath $packAgents) {
      Copy-Dir-Files -SrcDir $packAgents -DstDir $targetAgents -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -Stats $stats
    }
    if (Test-Path -LiteralPath $packDev) {
      Copy-Dir-Files -SrcDir $packDev -DstDir (Join-Path $targetDocs "dev") -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -Stats $stats
    }
    if (Test-Path -LiteralPath $packRules) {
      Copy-Dir-Files -SrcDir $packRules -DstDir (Join-Path $targetDocs "rules") -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -Stats $stats
    }
    Copy-RootMarkdown-Files -SrcDir $packShared -DstDir $targetDocs -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -Stats $stats
  }

  $tokens = @{
    "PROJECT_NAME" = $projectName
    "PROJECT_ROOT" = ($projectRoot -replace "\\", "/")
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

  $templatePath = Join-Path $repoRoot "templates/copilot-config/copilot-instructions.md"
  $templateRaw = Get-Content -LiteralPath $templatePath -Raw
  $rendered = Apply-Tokens -Text $templateRaw -Tokens $tokens
  Write-ManagedText -Text $rendered -Dst (Join-Path $targetCopilot "copilot-instructions.md") -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -Stats $stats

  $constitutionPath = Join-Path $repoRoot "templates/_render/CONSTITUTION.md.tpl"
  if (Test-Path -LiteralPath $constitutionPath) {
    $constitutionRaw = Get-Content -LiteralPath $constitutionPath -Raw
    $constitutionRendered = Apply-Tokens -Text $constitutionRaw -Tokens $tokens
    Write-ManagedText -Text $constitutionRendered -Dst (Join-Path $targetDocs "rules/CONSTITUTION.md") -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -Stats $stats
  }

  $qualityPath = Join-Path $repoRoot "templates/_render/QUALITY-GATES.md.tpl"
  if (Test-Path -LiteralPath $qualityPath) {
    $qualityRaw = Get-Content -LiteralPath $qualityPath -Raw
    $qualityRendered = Apply-Tokens -Text $qualityRaw -Tokens $tokens
    Write-ManagedText -Text $qualityRendered -Dst (Join-Path $targetDocs "rules/QUALITY-GATES.md") -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -Stats $stats
  }
}

if (-not $NoSecondStepPrompt -and -not $AnalyzeProject -and -not $AnalyzeOnly -and -not $DryRun) {
  $answer = Read-Host "Run second step now: generate project overview analysis? [y/N]"
  if ($answer -and $answer.Trim().ToLower() -in @("y","yes")) {
    $AnalyzeProject = $true
  }
}

if ($AnalyzeProject) {
  Ensure-Dir -Path $targetDocs -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -Stats $stats | Out-Null
  Analyze-Project -ProjectName $projectName -ProjectRoot $projectRoot -TargetDocs $targetDocs -SplitThreshold ([Math]::Max(1,$ModuleSplitThreshold)) -AnalyzeProfile $AnalyzeProfile -IsDryRun $DryRun -IsUpdateOnly $UpdateOnly -Stats $stats
}

Write-Host ""
Write-Host "Done"
Write-Host "Project: $projectName"
Write-Host "Codex Home: $codexHome"
Write-Host "Agents: $targetAgents"
Write-Host "Docs: $targetDocs"
Write-Host "Summary:"
Write-Host "- dirs created: $($stats.created_dirs)"
Write-Host "- files created: $($stats.created_files)"
Write-Host "- files updated: $($stats.updated_files)"
Write-Host "- files skipped: $($stats.skipped_files)"
if ($DryRun) { Write-Host ""; Write-Host "No files were changed (dry-run)." }


