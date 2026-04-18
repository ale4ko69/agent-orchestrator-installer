$ErrorActionPreference = "Stop"

function Resolve-YtDlpPath {
  $cmd = Get-Command yt-dlp -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $fallback = "C:\yt-dlp\yt-dlp.exe"
  if (Test-Path -LiteralPath $fallback) { return $fallback }
  return $null
}

function Resolve-ToolPath([string]$Name) {
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

$yt = Resolve-YtDlpPath
$ffmpeg = Resolve-ToolPath "ffmpeg"
$ffprobe = Resolve-ToolPath "ffprobe"

Write-Host "Video Tools Check"
Write-Host "-----------------"
Write-Host ("yt-dlp : " + ($(if ($yt) { $yt } else { "NOT FOUND" })))
Write-Host ("ffmpeg : " + ($(if ($ffmpeg) { $ffmpeg } else { "NOT FOUND" })))
Write-Host ("ffprobe: " + ($(if ($ffprobe) { $ffprobe } else { "NOT FOUND" })))

if ($yt) {
  try {
    & $yt --version | ForEach-Object { Write-Host "yt-dlp version: $_" }
  } catch {}
}
if ($ffmpeg) {
  try {
    & $ffmpeg -version | Select-Object -First 1 | ForEach-Object { Write-Host $_ }
  } catch {}
}

if (-not $yt) {
  Write-Error "yt-dlp is required. Install or place it at C:\yt-dlp\yt-dlp.exe."
}

if (-not $ffmpeg) {
  Write-Warning "ffmpeg not found. Download-only workflows work, but edit/convert features are limited."
}
