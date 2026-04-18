param(
  [Parameter(Mandatory=$false)]
  [string]$RepoUrl = "https://github.com/ale4ko69/agent-orchestrator-installer",
  [Parameter(Mandatory=$false)]
  [string]$Ref = "main",
  [Parameter(Mandatory=$false)]
  [string]$ProjectPath,
  [Parameter(Mandatory=$false)]
  [string]$MainBranch = "main",
  [Parameter(Mandatory=$false)]
  [string]$TaskPrefix = "TASK"
)

$ErrorActionPreference = "Stop"

function Get-PreferredPowerShell {
  $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
  if ($pwsh) { return $pwsh.Source }
  $ps = Get-Command powershell -ErrorAction SilentlyContinue
  if ($ps) { return $ps.Source }
  throw "Neither pwsh nor powershell was found in PATH."
}

function Test-ProjectFolder([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $false }

  $markers = @(".git","package.json","pyproject.toml","requirements.txt","go.mod","Cargo.toml","pom.xml")
  foreach ($m in $markers) {
    if (Test-Path -LiteralPath (Join-Path $Path $m)) { return $true }
  }
  return $false
}

function Resolve-ProjectPath([string]$InputPath) {
  if ($InputPath) {
    if (-not (Test-Path -LiteralPath $InputPath -PathType Container)) {
      throw "Provided ProjectPath does not exist: $InputPath"
    }
    return (Resolve-Path -LiteralPath $InputPath).Path
  }

  $cwd = (Get-Location).Path
  if (Test-ProjectFolder $cwd) {
    $answer = Read-Host "Current folder looks like a project: $cwd`nUse this folder as project root? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($answer) -or $answer.Trim().ToLower() -in @("y","yes")) { return $cwd }
  } else {
    Write-Host "Current folder does not look like a project root."
  }

  while ($true) {
    $manual = Read-Host "Enter project folder path"
    if ([string]::IsNullOrWhiteSpace($manual)) { continue }
    if (Test-Path -LiteralPath $manual -PathType Container) { return (Resolve-Path -LiteralPath $manual).Path }
    Write-Host "Path not found: $manual"
  }
}

function Normalize-GitHubRepo([string]$Url) {
  $u = $Url.Trim()
  if ($u.EndsWith(".git")) { $u = $u.Substring(0, $u.Length - 4) }
  if ($u.EndsWith("/")) { $u = $u.Substring(0, $u.Length - 1) }
  if ($u -notmatch '^https://github\.com/[^/]+/[^/]+$') {
    throw "RepoUrl must be in format https://github.com/<owner>/<repo>"
  }
  return $u
}

$projectRoot = Resolve-ProjectPath -InputPath $ProjectPath
$projectName = Split-Path -Leaf $projectRoot
$repoBase = Normalize-GitHubRepo -Url $RepoUrl

$tmpRoot = Join-Path $projectRoot ".tmp\agent-installer"
$srcRoot = Join-Path $tmpRoot "src"
$zipPath = Join-Path $tmpRoot "installer.zip"

New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null
if (Test-Path -LiteralPath $srcRoot) { Remove-Item -LiteralPath $srcRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $srcRoot | Out-Null

$zipUrl = "$repoBase/archive/refs/heads/$Ref.zip"
Write-Host "Downloading installer archive: $zipUrl"
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath

Expand-Archive -LiteralPath $zipPath -DestinationPath $srcRoot -Force

$extractedRoot = Get-ChildItem -LiteralPath $srcRoot -Directory | Select-Object -First 1
if (-not $extractedRoot) { throw "Failed to extract installer archive." }

$installScript = Join-Path $extractedRoot.FullName "scripts\install.ps1"
if (-not (Test-Path -LiteralPath $installScript)) {
  throw "install.ps1 not found in extracted archive: $installScript"
}

$configPath = Join-Path $tmpRoot "project.config.bootstrap.json"
$json = @"
{
  "projectName": "$projectName",
  "projectRoot": "$($projectRoot -replace '\\','/')",
  "codexHome": "$($projectRoot -replace '\\','/')/.ai",
  "mainBranch": "$MainBranch",
  "taskPrefix": "$TaskPrefix"
}
"@
Set-Content -LiteralPath $configPath -Encoding UTF8 -Value $json

Write-Host "Bootstrap config created: $configPath"
Write-Host "Project: $projectName"
Write-Host "Project root: $projectRoot"

$psExe = Get-PreferredPowerShell
& $psExe -NoProfile -ExecutionPolicy Bypass -File $installScript -ConfigPath $configPath

