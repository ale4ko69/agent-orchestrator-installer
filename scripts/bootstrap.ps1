param(
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

  $markers = @(
    ".git",
    "package.json",
    "pyproject.toml",
    "requirements.txt",
    "go.mod",
    "Cargo.toml",
    "pom.xml"
  )

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
  $looksLikeProject = Test-ProjectFolder $cwd

  if ($looksLikeProject) {
    $answer = Read-Host "Current folder looks like a project: $cwd`nUse this folder as project root? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($answer) -or $answer.Trim().ToLower() -in @("y","yes")) {
      return $cwd
    }
  } else {
    Write-Host "Current folder does not look like a project root."
  }

  while ($true) {
    $manual = Read-Host "Enter project folder path"
    if ([string]::IsNullOrWhiteSpace($manual)) { continue }
    if (Test-Path -LiteralPath $manual -PathType Container) {
      return (Resolve-Path -LiteralPath $manual).Path
    }
    Write-Host "Path not found: $manual"
  }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$installScript = Join-Path $scriptDir "install.ps1"
if (-not (Test-Path -LiteralPath $installScript)) {
  throw "install.ps1 not found near bootstrap.ps1: $installScript"
}

$resolvedProject = Resolve-ProjectPath -InputPath $ProjectPath
$projectName = Split-Path -Leaf $resolvedProject
$configPath = Join-Path $scriptDir "project.config.bootstrap.json"

$json = @"
{
  "projectName": "$projectName",
  "projectRoot": "$($resolvedProject -replace '\\','/')",
  "codexHome": "$($resolvedProject -replace '\\','/')/.ai",
  "mainBranch": "$MainBranch",
  "taskPrefix": "$TaskPrefix"
}
"@

Set-Content -LiteralPath $configPath -Encoding UTF8 -Value $json

Write-Host "Bootstrap config created: $configPath"
Write-Host "Project: $projectName"
Write-Host "Project root: $resolvedProject"

$psExe = Get-PreferredPowerShell
& $psExe -NoProfile -ExecutionPolicy Bypass -File $installScript -ConfigPath $configPath

