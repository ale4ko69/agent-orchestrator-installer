<#
.SYNOPSIS
Ingest a playlist URL into local video/audio assets with metadata and cover screenshots.

.DESCRIPTION
- Reads playlist entries via yt-dlp
- Optionally downloads video/audio
- Saves per-item metadata JSON
- Downloads cover image (thumbnail)
- Extracts screenshot from downloaded video when ffmpeg is available
- Produces playlist report (Markdown + JSON)

.PARAMETER PlaylistUrl
Playlist URL to process.

.PARAMETER OutputRoot
Root directory for generated content. Defaults to ./output/playlist-ingest

.PARAMETER Mode
Download mode: video, audio, both, metadata-only

.PARAMETER YtDlpPath
Explicit yt-dlp path. If omitted, script checks PATH and then C:\yt-dlp\yt-dlp.exe

.PARAMETER MaxItems
Optional limit for number of playlist entries.

.PARAMETER Force
If set, re-download existing media/covers and overwrite generated outputs.
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$PlaylistUrl,

  [Parameter(Mandatory = $false)]
  [string]$OutputRoot = ".\output\playlist-ingest",

  [Parameter(Mandatory = $false)]
  [ValidateSet("video", "audio", "both", "metadata-only")]
  [string]$Mode = "both",

  [Parameter(Mandatory = $false)]
  [string]$YtDlpPath = "",

  [Parameter(Mandatory = $false)]
  [int]$MaxItems = 0,

  [Parameter(Mandatory = $false)]
  [switch]$Force = $false
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues["Out-File:Encoding"] = "utf8"
$PSDefaultParameterValues["*:Encoding"] = "utf8"
$script:LastYtError = ""

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

function Resolve-YtDlp {
  param([string]$ExplicitPath)
  if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
    if (Test-Path -LiteralPath $ExplicitPath) { return (Resolve-Path $ExplicitPath).Path }
    throw "Provided yt-dlp path does not exist: $ExplicitPath"
  }

  $cmd = Get-Command yt-dlp -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $fallback = "C:\yt-dlp\yt-dlp.exe"
  if (Test-Path -LiteralPath $fallback) { return $fallback }

  throw "yt-dlp not found. Install yt-dlp or provide -YtDlpPath."
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
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
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

function Invoke-YtDlpJson {
  param(
    [string]$YtDlp,
    [string[]]$Args
  )
  $raw = & $YtDlp @Args 2>&1
  if (-not $raw) {
    $script:LastYtError = "yt-dlp returned empty output."
    return $null
  }

  $text = ($raw | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
  try {
    $obj = $text | ConvertFrom-Json -ErrorAction Stop
    $script:LastYtError = ""
    return $obj
  } catch {}

  $lines = @($text -split "`r?`n")
  $jsonCandidate = $lines | Where-Object { $_.TrimStart().StartsWith("{") } | Select-Object -Last 1
  if ($jsonCandidate) {
    try {
      $obj = $jsonCandidate | ConvertFrom-Json -ErrorAction Stop
      $script:LastYtError = ""
      return $obj
    } catch {}
  }

  $script:LastYtError = ($lines | Select-Object -Last 12) -join [Environment]::NewLine
  return $null
}

function Download-Thumbnail {
  param(
    [string]$Url,
    [string]$OutFile,
    [switch]$Overwrite
  )
  if ((Test-Path -LiteralPath $OutFile) -and -not $Overwrite) { return $true }
  try {
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing | Out-Null
    return (Test-Path -LiteralPath $OutFile)
  } catch {
    return $false
  }
}

function Download-Video {
  param(
    [string]$YtDlp,
    [string]$Url,
    [string]$OutputTemplate
  )
  $args = @(
    "--quiet",
    "--no-warnings",
    "--merge-output-format", "mp4",
    "-f", "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/b",
    "--print", "after_move:filepath",
    "-o", $OutputTemplate,
    $Url
  )
  $out = & $YtDlp @args 2>$null
  if (-not $out) { return $null }
  return ($out | Select-Object -Last 1).Trim()
}

function Download-Audio {
  param(
    [string]$YtDlp,
    [string]$Url,
    [string]$OutputTemplate
  )
  $args = @(
    "--quiet",
    "--no-warnings",
    "-x",
    "--audio-format", "mp3",
    "--audio-quality", "0",
    "--print", "after_move:filepath",
    "-o", $OutputTemplate,
    $Url
  )
  $out = & $YtDlp @args 2>$null
  if (-not $out) { return $null }
  return ($out | Select-Object -Last 1).Trim()
}

function Extract-Screenshot {
  param(
    [string]$Ffmpeg,
    [string]$InputFile,
    [string]$OutputImage
  )
  if (-not $Ffmpeg) { return $false }
  if (-not (Test-Path -LiteralPath $InputFile)) { return $false }
  try {
    & $Ffmpeg -y -ss 00:00:01 -i $InputFile -frames:v 1 -q:v 2 $OutputImage *> $null
    return (Test-Path -LiteralPath $OutputImage)
  } catch {
    return $false
  }
}

$ytDlp = Resolve-YtDlp -ExplicitPath $YtDlpPath
$ffmpeg = Resolve-Tool -Name "ffmpeg"

Write-Log "Using yt-dlp: $ytDlp" "OK"
if ($ffmpeg) { Write-Log "Using ffmpeg: $ffmpeg" "OK" } else { Write-Log "ffmpeg not found. Screenshot extraction will be skipped." "WARN" }

try {
  & $ytDlp --version | ForEach-Object { Write-Log "yt-dlp version: $_" "INFO" }
} catch {}

$playlistMeta = Invoke-YtDlpJson -YtDlp $ytDlp -Args @("--flat-playlist", "--dump-single-json", "--no-warnings", $PlaylistUrl)
if (-not $playlistMeta) {
  $msg = "Failed to load playlist metadata from URL: $PlaylistUrl"
  if ($script:LastYtError) { $msg += [Environment]::NewLine + $script:LastYtError }
  throw $msg
}

$playlistTitle = Get-SafeName -Raw ([string]($playlistMeta.title ?? "playlist"))
$playlistId = [string]($playlistMeta.id ?? "unknown")
$playlistDir = Join-Path $OutputRoot ("{0}-{1}" -f $playlistTitle, $playlistId)
$videoDir = Join-Path $playlistDir "video"
$audioDir = Join-Path $playlistDir "audio"
$coverDir = Join-Path $playlistDir "covers"
$shotDir = Join-Path $playlistDir "screenshots"
$metaDir = Join-Path $playlistDir "metadata"

Ensure-Dir $playlistDir
Ensure-Dir $videoDir
Ensure-Dir $audioDir
Ensure-Dir $coverDir
Ensure-Dir $shotDir
Ensure-Dir $metaDir

$entries = @($playlistMeta.entries)
if ($MaxItems -gt 0) { $entries = $entries | Select-Object -First $MaxItems }
if ($entries.Count -eq 0) { throw "Playlist contains no entries." }

Write-Log "Playlist: $playlistTitle ($playlistId)" "OK"
Write-Log "Entries to process: $($entries.Count)" "OK"

$results = @()
$index = 1

foreach ($entry in $entries) {
  $entryId = [string]($entry.id ?? "")
  $entryUrl = [string]($entry.url ?? "")
  $entryWeb = [string]($entry.webpage_url ?? "")
  if ([string]::IsNullOrWhiteSpace($entryWeb)) {
    if ($entryUrl -match "^https?://") { $entryWeb = $entryUrl }
    elseif (-not [string]::IsNullOrWhiteSpace($entryId)) { $entryWeb = "https://www.youtube.com/watch?v=$entryId" }
    else { $entryWeb = $PlaylistUrl }
  }

  Write-Log "[$index/$($entries.Count)] Reading video metadata: $entryWeb" "INFO"
  $videoMeta = Invoke-YtDlpJson -YtDlp $ytDlp -Args @("--dump-json", "--skip-download", "--no-warnings", $entryWeb)
  if (-not $videoMeta) {
    Write-Log "Failed to read metadata for $entryWeb, skipping item." "WARN"
    if ($script:LastYtError) {
      Write-Log $script:LastYtError "WARN"
    }
    $index++
    continue
  }

  $title = Get-SafeName -Raw ([string]($videoMeta.title ?? "video-$index"))
  $description = [string]($videoMeta.description ?? "")
  $thumbnail = [string]($videoMeta.thumbnail ?? "")
  $duration = [int]($videoMeta.duration ?? 0)
  $channel = [string]($videoMeta.uploader ?? "")
  $uploadDate = [string]($videoMeta.upload_date ?? "")

  $prefix = "{0:D3}-{1}" -f $index, $title
  $metaFile = Join-Path $metaDir ("$prefix.json")
  $coverFile = Join-Path $coverDir ("$prefix.jpg")
  $shotFile = Join-Path $shotDir ("$prefix.jpg")
  $videoOutTemplate = Join-Path $videoDir ("$prefix.%(ext)s")
  $audioOutTemplate = Join-Path $audioDir ("$prefix.%(ext)s")

  ($videoMeta | ConvertTo-Json -Depth 20) | Out-File -FilePath $metaFile -Force

  $coverSaved = $false
  if (-not [string]::IsNullOrWhiteSpace($thumbnail)) {
    $coverSaved = Download-Thumbnail -Url $thumbnail -OutFile $coverFile -Overwrite:$Force
  }
  if ($coverSaved) { Write-Log "Saved cover: $coverFile" "OK" } else { Write-Log "Cover not saved for item $index." "WARN" }

  $videoFile = $null
  $audioFile = $null

  if ($Mode -in @("video", "both")) {
    if ((-not $Force) -and (Test-Path -LiteralPath (Join-Path $videoDir "$prefix.mp4"))) {
      $videoFile = Join-Path $videoDir "$prefix.mp4"
      Write-Log "Video exists, skipping: $videoFile" "WARN"
    } else {
      $videoFile = Download-Video -YtDlp $ytDlp -Url $entryWeb -OutputTemplate $videoOutTemplate
      if ($videoFile) { Write-Log "Video saved: $videoFile" "OK" } else { Write-Log "Video download failed for $entryWeb" "WARN" }
    }
  }

  if ($Mode -in @("audio", "both")) {
    if ((-not $Force) -and (Test-Path -LiteralPath (Join-Path $audioDir "$prefix.mp3"))) {
      $audioFile = Join-Path $audioDir "$prefix.mp3"
      Write-Log "Audio exists, skipping: $audioFile" "WARN"
    } else {
      $audioFile = Download-Audio -YtDlp $ytDlp -Url $entryWeb -OutputTemplate $audioOutTemplate
      if ($audioFile) { Write-Log "Audio saved: $audioFile" "OK" } else { Write-Log "Audio download failed for $entryWeb" "WARN" }
    }
  }

  $shotSaved = $false
  if ($videoFile) {
    $shotSaved = Extract-Screenshot -Ffmpeg $ffmpeg -InputFile $videoFile -OutputImage $shotFile
  }
  if ($shotSaved) { Write-Log "Saved screenshot: $shotFile" "OK" }

  $results += [PSCustomObject]@{
    index = $index
    id = [string]($videoMeta.id ?? $entryId)
    title = $title
    url = $entryWeb
    channel = $channel
    durationSeconds = $duration
    uploadDate = $uploadDate
    description = $description
    metadataFile = $metaFile
    coverFile = $(if ($coverSaved) { $coverFile } else { "" })
    screenshotFile = $(if ($shotSaved) { $shotFile } else { "" })
    videoFile = $(if ($videoFile) { $videoFile } else { "" })
    audioFile = $(if ($audioFile) { $audioFile } else { "" })
  }

  $index++
}

$reportJson = Join-Path $playlistDir "playlist-report.json"
$reportMd = Join-Path $playlistDir "playlist-report.md"

$reportObj = [PSCustomObject]@{
  generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  playlistTitle = $playlistTitle
  playlistId = $playlistId
  playlistUrl = $PlaylistUrl
  mode = $Mode
  itemCount = $results.Count
  outputRoot = $playlistDir
  items = $results
}

($reportObj | ConvertTo-Json -Depth 10) | Out-File -FilePath $reportJson -Force

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Playlist Ingest Report")
$md.Add("")
$md.Add("- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$md.Add("- Playlist: $playlistTitle")
$md.Add("- Playlist URL: $PlaylistUrl")
$md.Add("- Mode: $Mode")
$md.Add("- Items processed: $($results.Count)")
$md.Add("- Output: $playlistDir")
$md.Add("")
$md.Add("## Items")
$md.Add("")

foreach ($r in $results) {
  $descShort = $r.description
  if ($descShort.Length -gt 700) { $descShort = $descShort.Substring(0, 700) + "..." }
  $md.Add("### $($r.index). $($r.title)")
  $md.Add("- URL: $($r.url)")
  $md.Add("- Channel: $($r.channel)")
  $md.Add("- Upload date: $($r.uploadDate)")
  $md.Add("- Duration (s): $($r.durationSeconds)")
  $md.Add("- Metadata: " + [char]96 + $r.metadataFile + [char]96)
  if ($r.coverFile) { $md.Add("- Cover: " + [char]96 + $r.coverFile + [char]96) }
  if ($r.screenshotFile) { $md.Add("- Screenshot: " + [char]96 + $r.screenshotFile + [char]96) }
  if ($r.videoFile) { $md.Add("- Video: " + [char]96 + $r.videoFile + [char]96) }
  if ($r.audioFile) { $md.Add("- Audio: " + [char]96 + $r.audioFile + [char]96) }
  $md.Add("- Description:")
  $md.Add('```text')
  $md.Add($descShort)
  $md.Add('```')
  $md.Add("")
}

$md -join [Environment]::NewLine | Out-File -FilePath $reportMd -Force

Write-Log "Done. Report JSON: $reportJson" "OK"
Write-Log "Done. Report MD: $reportMd" "OK"
Write-Log "Playlist output: $playlistDir" "OK"
