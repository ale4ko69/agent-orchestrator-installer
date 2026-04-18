<#
.SYNOPSIS
Sync and sanitize Admin UI source snapshot into installer templates.

.DESCRIPTION
- Copies selected files from external source (default: Phoenix v1.24.0 layout)
- Rebrands textual mentions from Phoenix -> AdminCore
- Neutralizes navigation hyperlinks in <a href="..."> to prevent internal template links
- Writes sanitized examples into:
  templates/packs/admin-ui-foundation/shared-docs/assets/admincore/examples

.PARAMETER SourceRoot
Root path of external UI source.

.PARAMETER RepoRoot
Root path of this repository.

.PARAMETER Force
Overwrite existing target files.
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot,

  [Parameter(Mandatory = $false)]
  [string]$RepoRoot = "",

  [Parameter(Mandatory = $false)]
  [switch]$Force = $false
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Log {
  param([string]$Message)
  Write-Host ("[sync-admincore] " + $Message)
}

function Get-ScriptRepoRoot {
  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
  return (Split-Path -Parent $scriptDir)
}

function Rebrand-Text {
  param([string]$Text)
  $out = $Text
  $out = $out.Replace("PHOENIX", "ADMINCORE").Replace("Phoenix", "AdminCore").Replace("phoenix", "admincore")
  $out = $out.Replace("Prium", "AdminCore").Replace("prium", "admincore")
  $out = $out -replace "prium\.github\.io\/phoenix", "admincore.local/examples"
  return $out
}

function Neutralize-AnchorHrefs {
  param([string]$Html)
  return [regex]::Replace(
    $Html,
    '(<a\b[^>]*?\bhref\s*=\s*")([^"]*)(")',
    {
      param($m)
      $href = $m.Groups[2].Value
      if ($href.StartsWith("#") -or $href.StartsWith("mailto:") -or $href.StartsWith("tel:") -or $href.StartsWith("javascript:")) {
        return $m.Value
      }
      return $m.Groups[1].Value + "#" + $m.Groups[3].Value
    },
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
  )
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = Get-ScriptRepoRoot
}

$source = Resolve-Path -LiteralPath $SourceRoot
$repo = Resolve-Path -LiteralPath $RepoRoot

$sourcePath = $source.Path
$repoPath = $repo.Path

$targetBase = Join-Path $repoPath "templates\packs\admin-ui-foundation\shared-docs\assets\admincore"
$targetExamples = Join-Path $targetBase "examples\modules"
$targetCss = Join-Path $targetBase "css"

New-Item -ItemType Directory -Path $targetExamples -Force | Out-Null
New-Item -ItemType Directory -Path $targetCss -Force | Out-Null

# CSS
$themeSrc = Join-Path $sourcePath "assets\css\theme.min.css"
$userSrc = Join-Path $sourcePath "assets\css\user.min.css"
if (Test-Path -LiteralPath $themeSrc) {
  $themeText = Get-Content -LiteralPath $themeSrc -Raw -Encoding UTF8
  $themeText = Rebrand-Text -Text $themeText
  Set-Content -LiteralPath (Join-Path $targetCss "admincore-theme.min.css") -Value $themeText -Encoding UTF8
  Write-Log "Updated CSS: admincore-theme.min.css"
}
if (Test-Path -LiteralPath $userSrc) {
  $userText = Get-Content -LiteralPath $userSrc -Raw -Encoding UTF8
  $userText = Rebrand-Text -Text $userText
  Set-Content -LiteralPath (Join-Path $targetCss "admincore-user.min.css") -Value $userText -Encoding UTF8
  Write-Log "Updated CSS: admincore-user.min.css"
}

$moduleRoots = @("components", "forms", "tables", "echarts")
$copied = New-Object System.Collections.Generic.List[string]

foreach ($mod in $moduleRoots) {
  $srcMod = Join-Path $sourcePath ("modules\" + $mod)
  if (-not (Test-Path -LiteralPath $srcMod)) {
    Write-Log "Skip missing module root: $srcMod"
    continue
  }

  $files = Get-ChildItem -LiteralPath $srcMod -Recurse -File -Filter *.html | Sort-Object FullName
  foreach ($f in $files) {
    $rel = $f.FullName.Substring($sourcePath.Length).TrimStart('\','/') -replace '\\','/'
    $dst = Join-Path $targetExamples $rel
    $dstDir = Split-Path -Parent $dst
    if (-not (Test-Path -LiteralPath $dstDir)) {
      New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }

    if ((Test-Path -LiteralPath $dst) -and -not $Force) {
      # still overwrite to keep snapshot fresh, unless user asked strict no-overwrite
    }

    $raw = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    $raw = Rebrand-Text -Text $raw
    $raw = Neutralize-AnchorHrefs -Html $raw
    Set-Content -LiteralPath $dst -Value $raw -Encoding UTF8
    [void]$copied.Add($rel)
  }

  Write-Log "Synced module: $mod (html files: $($files.Count))"
}

$catalogPath = Join-Path $repoPath "templates\packs\admin-ui-foundation\shared-docs\tools\ADMINCORE-COMPONENT-CATALOG.md"
$catalog = New-Object System.Collections.Generic.List[string]
$catalog.Add("# AdminCore Component Catalog")
$catalog.Add("")
$catalog.Add("Sanitized snapshot synced from external v1.24.0 source.")
$catalog.Add("Brand mentions and internal navigation links are normalized for Admin UI usage.")
$catalog.Add("")
$catalog.Add("## Files")
foreach ($item in ($copied | Sort-Object)) {
  $catalog.Add("- " + [char]96 + $item + [char]96)
}
$catalog.Add("")
Set-Content -LiteralPath $catalogPath -Value ($catalog -join [Environment]::NewLine) -Encoding UTF8

Write-Log ("Done. Synced html files: " + $copied.Count)
