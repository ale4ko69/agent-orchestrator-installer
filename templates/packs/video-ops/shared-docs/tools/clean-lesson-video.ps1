<#
.SYNOPSIS
Create a cleaned lesson video by trimming likely intro/outro non-lesson segments.

.DESCRIPTION
- Uses ffprobe to read duration
- Uses ffmpeg blackdetect + silencedetect near start/end windows
- Proposes trim boundaries
- Exports cleaned clip and analysis report

Note:
- Mid-roll ad detection inside the lesson body is heuristic and not guaranteed.
- Final manual review is strongly recommended.

.PARAMETER InputFile
Source video file path.

.PARAMETER OutputFile
Target cleaned video file path.

.PARAMETER IntroWindowSec
Detection window at start (seconds).

.PARAMETER OutroWindowSec
Detection window at end (seconds).

.PARAMETER MinBlackSec
Minimum black segment duration for detection.

.PARAMETER MinSilenceSec
Minimum silence duration for detection.

.PARAMETER Force
Overwrite output file.
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$InputFile,

  [Parameter(Mandatory = $false)]
  [string]$OutputFile = "",

  [Parameter(Mandatory = $false)]
  [int]$IntroWindowSec = 120,

  [Parameter(Mandatory = $false)]
  [int]$OutroWindowSec = 120,

  [Parameter(Mandatory = $false)]
  [double]$MinBlackSec = 1.5,

  [Parameter(Mandatory = $false)]
  [double]$MinSilenceSec = 1.0,

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

function Get-Duration {
  param([string]$Ffprobe, [string]$File)
  $raw = & $Ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 $File 2>$null
  if (-not $raw) { return 0.0 }
  return [double]([string]$raw | Select-Object -First 1)
}

function Get-DetectLog {
  param(
    [string]$Ffmpeg,
    [string[]]$Args
  )
  $log = & $Ffmpeg @Args 2>&1
  return ($log | ForEach-Object { [string]$_ })
}

function Extract-LastBlackEndInWindow {
  param([string[]]$Lines)
  $maxEnd = 0.0
  foreach ($ln in $Lines) {
    if ($ln -match "black_end:(\d+(\.\d+)?)") {
      $v = [double]$matches[1]
      if ($v -gt $maxEnd) { $maxEnd = $v }
    }
  }
  return $maxEnd
}

function Extract-FirstBlackStartInWindow {
  param([string[]]$Lines)
  $minStart = [double]::PositiveInfinity
  foreach ($ln in $Lines) {
    if ($ln -match "black_start:(\d+(\.\d+)?)") {
      $v = [double]$matches[1]
      if ($v -lt $minStart) { $minStart = $v }
    }
  }
  if ([double]::IsInfinity($minStart)) { return $null }
  return $minStart
}

function Extract-LastSilenceEndInWindow {
  param([string[]]$Lines)
  $maxEnd = 0.0
  foreach ($ln in $Lines) {
    if ($ln -match "silence_end:\s*(\d+(\.\d+)?)") {
      $v = [double]$matches[1]
      if ($v -gt $maxEnd) { $maxEnd = $v }
    }
  }
  return $maxEnd
}

function Extract-FirstSilenceStartInWindow {
  param([string[]]$Lines)
  $minStart = [double]::PositiveInfinity
  foreach ($ln in $Lines) {
    if ($ln -match "silence_start:\s*(\d+(\.\d+)?)") {
      $v = [double]$matches[1]
      if ($v -lt $minStart) { $minStart = $v }
    }
  }
  if ([double]::IsInfinity($minStart)) { return $null }
  return $minStart
}

if (-not (Test-Path -LiteralPath $InputFile)) {
  throw "Input file not found: $InputFile"
}

$ffmpeg = Resolve-Tool "ffmpeg"
$ffprobe = Resolve-Tool "ffprobe"
if (-not $ffmpeg -or -not $ffprobe) {
  throw "ffmpeg and ffprobe are required for this script."
}

$src = Resolve-Path $InputFile
$inFile = $src.Path
if ([string]::IsNullOrWhiteSpace($OutputFile)) {
  $dir = Split-Path -Parent $inFile
  $name = [IO.Path]::GetFileNameWithoutExtension($inFile)
  $ext = [IO.Path]::GetExtension($inFile)
  $OutputFile = Join-Path $dir ("{0}.clean{1}" -f $name, $ext)
}
if ((Test-Path -LiteralPath $OutputFile) -and -not $Force) {
  throw "Output file already exists. Use -Force to overwrite: $OutputFile"
}

$duration = Get-Duration -Ffprobe $ffprobe -File $inFile
if ($duration -le 0) { throw "Could not determine video duration." }

$introWindow = [Math]::Min($IntroWindowSec, [Math]::Floor($duration / 2))
$outroWindow = [Math]::Min($OutroWindowSec, [Math]::Floor($duration / 2))
$outroStart = [Math]::Max(0, $duration - $outroWindow)

Write-Log "Input duration: $([Math]::Round($duration,2)) sec" "OK"
Write-Log "Intro analysis window: 0..$introWindow sec" "INFO"
Write-Log "Outro analysis window: $([Math]::Round($outroStart,2))..$([Math]::Round($duration,2)) sec" "INFO"

$introBlackLog = Get-DetectLog -Ffmpeg $ffmpeg -Args @(
  "-hide_banner","-nostats","-ss","0","-t",$introWindow.ToString(),"-i", $inFile,
  "-vf","blackdetect=d=$MinBlackSec:pix_th=0.10","-an","-f","null","NUL"
)
$introSilenceLog = Get-DetectLog -Ffmpeg $ffmpeg -Args @(
  "-hide_banner","-nostats","-ss","0","-t",$introWindow.ToString(),"-i",$inFile,
  "-af","silencedetect=n=-35dB:d=$MinSilenceSec","-vn","-f","null","NUL"
)

$outroBlackLog = Get-DetectLog -Ffmpeg $ffmpeg -Args @(
  "-hide_banner","-nostats","-ss",$outroStart.ToString(),"-t",$outroWindow.ToString(),"-i",$inFile,
  "-vf","blackdetect=d=$MinBlackSec:pix_th=0.10","-an","-f","null","NUL"
)
$outroSilenceLog = Get-DetectLog -Ffmpeg $ffmpeg -Args @(
  "-hide_banner","-nostats","-ss",$outroStart.ToString(),"-t",$outroWindow.ToString(),"-i",$inFile,
  "-af","silencedetect=n=-35dB:d=$MinSilenceSec","-vn","-f","null","NUL"
)

$introBlackEnd = Extract-LastBlackEndInWindow -Lines $introBlackLog
$introSilenceEnd = Extract-LastSilenceEndInWindow -Lines $introSilenceLog
$introCut = [Math]::Max($introBlackEnd, $introSilenceEnd)
if ($introCut -gt ($introWindow - 1)) { $introCut = 0.0 }

$outroBlackStartLocal = Extract-FirstBlackStartInWindow -Lines $outroBlackLog
$outroSilenceStartLocal = Extract-FirstSilenceStartInWindow -Lines $outroSilenceLog
$candidates = @()
if ($null -ne $outroBlackStartLocal) { $candidates += ($outroStart + $outroBlackStartLocal) }
if ($null -ne $outroSilenceStartLocal) { $candidates += ($outroStart + $outroSilenceStartLocal) }
$outroCut = $duration
if ($candidates.Count -gt 0) { $outroCut = ($candidates | Sort-Object | Select-Object -First 1) }
if ($outroCut -lt ($duration - $outroWindow)) { $outroCut = $duration }

if (($outroCut - $introCut) -lt 10) {
  Write-Log "Detected trim range too short, fallback to full duration." "WARN"
  $introCut = 0.0
  $outroCut = $duration
}

Write-Log ("Proposed lesson range: {0} .. {1} sec" -f [Math]::Round($introCut,2), [Math]::Round($outroCut,2)) "OK"

& $ffmpeg -y -ss $introCut -to $outroCut -i $inFile -c:v libx264 -preset medium -crf 20 -c:a aac -b:a 192k $OutputFile *> $null
if (-not (Test-Path -LiteralPath $OutputFile)) {
  throw "Failed to create output file: $OutputFile"
}

$reportPath = [IO.Path]::ChangeExtension($OutputFile, ".clean-report.md")
$jsonPath = [IO.Path]::ChangeExtension($OutputFile, ".clean-report.json")

$reportObj = [PSCustomObject]@{
  generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  inputFile = $inFile
  outputFile = $OutputFile
  durationInput = [Math]::Round($duration,2)
  proposedStart = [Math]::Round($introCut,2)
  proposedEnd = [Math]::Round($outroCut,2)
  durationOutputExpected = [Math]::Round(($outroCut - $introCut),2)
  notes = @(
    "Mid-roll ad detection is heuristic and not guaranteed.",
    "Manual review is recommended before publishing."
  )
}
($reportObj | ConvertTo-Json -Depth 6) | Out-File -FilePath $jsonPath -Force

$md = @(
  "# Clean Lesson Video Report",
  "",
  "- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
  "- Input: " + [char]96 + $inFile + [char]96,
  "- Output: " + [char]96 + $OutputFile + [char]96,
  "- Input duration: $([Math]::Round($duration,2)) sec",
  "- Proposed start: $([Math]::Round($introCut,2)) sec",
  "- Proposed end: $([Math]::Round($outroCut,2)) sec",
  "- Expected cleaned duration: $([Math]::Round(($outroCut - $introCut),2)) sec",
  "",
  "## Important",
  "- Mid-roll ad detection inside lesson body is heuristic only.",
  "- Review cleaned output and re-run with adjusted windows if needed.",
  ""
)
$md -join [Environment]::NewLine | Out-File -FilePath $reportPath -Force

Write-Log "Cleaned video created: $OutputFile" "OK"
Write-Log "Report: $reportPath" "OK"
Write-Log "Report JSON: $jsonPath" "OK"
