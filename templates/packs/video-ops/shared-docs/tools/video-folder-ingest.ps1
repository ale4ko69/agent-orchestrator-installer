<#
.SYNOPSIS
Batch-ingest local video files from a folder and generate metadata + cover images.

.DESCRIPTION
- Scans input folder recursively for video files
- Reads technical metadata via ffprobe
- Builds normalized title/description draft
- Extracts cover frame (middle frame) via ffmpeg
- Generates report files:
  - folder-report.json
  - folder-report.md

.PARAMETER InputDir
Folder with local video files.

.PARAMETER OutputRoot
Output folder for generated artifacts.

.PARAMETER Recurse
Scan nested folders recursively.

.PARAMETER Force
Overwrite generated artifacts if they already exist.
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$InputDir,

  [Parameter(Mandatory = $false)]
  [string]$OutputRoot = ".\output\video-folder-ingest",

  [Parameter(Mandatory = $false)]
  [switch]$Recurse = $true,

  [Parameter(Mandatory = $false)]
  [switch]$Force = $false
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Log {
  param(
    [string]$Message,
    [ValidateSet("INFO", "WARN", "ERROR", "OK")]
    [string]$Level = "INFO"
  )
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $prefix = "[$ts][$Level]"
  switch ($Level) {
    "WARN"  { Write-Host "$prefix $Message" -ForegroundColor Yellow }
    "ERROR" { Write-Host "$prefix $Message" -ForegroundColor Red }
    "OK"    { Write-Host "$prefix $Message" -ForegroundColor Green }
    default { Write-Host "$prefix $Message" }
  }
}

function Resolve-Tool {
  param([string]$Name)
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
  }
}

function Get-SafeName {
  param([string]$Raw)
  if ([string]::IsNullOrWhiteSpace($Raw)) { return "untitled" }
  $invalid = [IO.Path]::GetInvalidFileNameChars()
  $safe = $Raw
  foreach ($ch in $invalid) { $safe = $safe.Replace($ch, "_") }
  $safe = ($safe -replace "\s+", " ").Trim()
  if ($safe.Length -gt 100) { $safe = $safe.Substring(0, 100).Trim() }
  if ([string]::IsNullOrWhiteSpace($safe)) { return "untitled" }
  return $safe
}

function Normalize-TitleFromName {
  param([string]$BaseName)
  $t = $BaseName -replace "[._-]+", " "
  $t = $t -replace "\s+", " "
  $t = $t.Trim()
  if ($t.Length -gt 0) {
    return (Get-Culture).TextInfo.ToTitleCase($t.ToLower())
  }
  return "Untitled Lesson"
}

function Get-VideoMeta {
  param(
    [string]$Ffprobe,
    [string]$File
  )
  if (-not $Ffprobe) { return $null }
  try {
    $raw = & $Ffprobe -v error -show_entries "format=duration,size:stream=index,codec_type,width,height,codec_name,r_frame_rate" -of json $File 2>$null
    if (-not $raw) { return $null }
    return (($raw -join [Environment]::NewLine) | ConvertFrom-Json)
  } catch {
    return $null
  }
}

function Get-MiddleCover {
  param(
    [string]$Ffmpeg,
    [string]$VideoPath,
    [double]$DurationSec,
    [string]$OutputJpg
  )
  if (-not $Ffmpeg) { return $false }
  if (-not (Test-Path -LiteralPath $VideoPath)) { return $false }
  $seek = 1
  if ($DurationSec -gt 3) { $seek = [Math]::Floor($DurationSec / 2) }
  try {
    & $Ffmpeg -y -ss $seek -i $VideoPath -frames:v 1 -q:v 2 $OutputJpg *> $null
    return (Test-Path -LiteralPath $OutputJpg)
  } catch {
    return $false
  }
}

if (-not (Test-Path -LiteralPath $InputDir)) {
  throw "InputDir not found: $InputDir"
}

$ffprobe = Resolve-Tool -Name "ffprobe"
$ffmpeg = Resolve-Tool -Name "ffmpeg"

if (-not $ffprobe) { Write-Log "ffprobe not found. Metadata extraction will be limited." "WARN" }
if (-not $ffmpeg) { Write-Log "ffmpeg not found. Cover extraction will be skipped." "WARN" }

Ensure-Dir $OutputRoot
$coversDir = Join-Path $OutputRoot "covers"
$metaDir = Join-Path $OutputRoot "metadata"
Ensure-Dir $coversDir
Ensure-Dir $metaDir

$videoExt = @("*.mp4","*.mkv","*.mov","*.avi","*.webm","*.m4v")
$files = @()
foreach ($ext in $videoExt) {
  $items = Get-ChildItem -LiteralPath $InputDir -File -Filter $ext -Recurse:$Recurse
  if ($items) { $files += $items }
}
$files = $files | Sort-Object FullName -Unique
if ($files.Count -eq 0) { throw "No video files found in: $InputDir" }

Write-Log "Found $($files.Count) video files." "OK"

$results = @()
$i = 1
foreach ($f in $files) {
  Write-Log "[$i/$($files.Count)] Processing $($f.FullName)" "INFO"
  $base = [IO.Path]::GetFileNameWithoutExtension($f.Name)
  $safe = Get-SafeName -Raw ("{0:D3}-{1}" -f $i, $base)
  $title = Normalize-TitleFromName -BaseName $base

  $meta = Get-VideoMeta -Ffprobe $ffprobe -File $f.FullName
  $duration = 0.0
  $size = $f.Length
  $width = $null
  $height = $null
  $codec = $null
  $fps = $null

  if ($meta) {
    if ($meta.format.duration) { $duration = [double]$meta.format.duration }
    if ($meta.format.size) { $size = [int64]$meta.format.size }
    $v = $meta.streams | Where-Object { $_.codec_type -eq "video" } | Select-Object -First 1
    if ($v) {
      $width = $v.width
      $height = $v.height
      $codec = $v.codec_name
      $fps = $v.r_frame_rate
    }
  }

  $coverPath = Join-Path $coversDir "$safe.jpg"
  $coverSaved = $false
  if ((-not (Test-Path -LiteralPath $coverPath)) -or $Force) {
    $coverSaved = Get-MiddleCover -Ffmpeg $ffmpeg -VideoPath $f.FullName -DurationSec $duration -OutputJpg $coverPath
  } else {
    $coverSaved = $true
  }

  $desc = @(
    "Draft summary for lesson/video review."
    "Original file: $($f.Name)"
    "Duration (sec): $([Math]::Round($duration,2))"
    "Resolution: $(if($width -and $height){ "$width x $height" } else { "unknown" })"
    "Codec: $(if($codec){$codec}else{"unknown"})"
    "FPS: $(if($fps){$fps}else{"unknown"})"
    "Use this as baseline text and refine manually with domain-specific context."
  ) -join " "

  $item = [PSCustomObject]@{
    index = $i
    sourcePath = $f.FullName
    fileName = $f.Name
    title = $title
    descriptionDraft = $desc
    durationSeconds = [Math]::Round($duration, 2)
    sizeBytes = $size
    width = $width
    height = $height
    codec = $codec
    fps = $fps
    coverPath = $(if ($coverSaved) { $coverPath } else { "" })
  }

  $itemMetaPath = Join-Path $metaDir "$safe.json"
  ($item | ConvertTo-Json -Depth 8) | Out-File -FilePath $itemMetaPath -Force
  $results += $item
  $i++
}

$reportJson = Join-Path $OutputRoot "folder-report.json"
$reportMd = Join-Path $OutputRoot "folder-report.md"

$obj = [PSCustomObject]@{
  generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  inputDir = (Resolve-Path $InputDir).Path
  outputRoot = (Resolve-Path $OutputRoot).Path
  filesProcessed = $results.Count
  items = $results
}
($obj | ConvertTo-Json -Depth 10) | Out-File -FilePath $reportJson -Force

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Video Folder Ingest Report")
$md.Add("")
$md.Add("- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$md.Add("- Input: $InputDir")
$md.Add("- Files processed: $($results.Count)")
$md.Add("- Output: $OutputRoot")
$md.Add("")
$md.Add("## Items")
$md.Add("")
foreach ($r in $results) {
  $md.Add("### $($r.index). $($r.title)")
  $md.Add("- File: " + [char]96 + $r.sourcePath + [char]96)
  $md.Add("- Duration: $($r.durationSeconds) sec")
  $md.Add("- Resolution: $(if($r.width -and $r.height){ "$($r.width)x$($r.height)" } else { "unknown" })")
  $md.Add("- Codec: $(if($r.codec){$r.codec}else{"unknown"})")
  if ($r.coverPath) { $md.Add("- Cover: " + [char]96 + $r.coverPath + [char]96) }
  $md.Add("- Description draft:")
  $md.Add('```text')
  $md.Add($r.descriptionDraft)
  $md.Add('```')
  $md.Add("")
}
$md -join [Environment]::NewLine | Out-File -FilePath $reportMd -Force

Write-Log "Done. Report JSON: $reportJson" "OK"
Write-Log "Done. Report MD: $reportMd" "OK"
