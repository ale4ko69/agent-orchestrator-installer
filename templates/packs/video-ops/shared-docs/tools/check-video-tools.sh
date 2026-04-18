#!/usr/bin/env bash
set -euo pipefail

find_ytdlp() {
  if command -v yt-dlp >/dev/null 2>&1; then
    command -v yt-dlp
    return 0
  fi
  if [ -x "/mnt/c/yt-dlp/yt-dlp.exe" ]; then
    echo "/mnt/c/yt-dlp/yt-dlp.exe"
    return 0
  fi
  return 1
}

find_tool() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi
  return 1
}

yt=""
ffmpeg=""
ffprobe=""

if yt="$(find_ytdlp 2>/dev/null)"; then :; else yt=""; fi
if ffmpeg="$(find_tool ffmpeg 2>/dev/null)"; then :; else ffmpeg=""; fi
if ffprobe="$(find_tool ffprobe 2>/dev/null)"; then :; else ffprobe=""; fi

echo "Video Tools Check"
echo "-----------------"
echo "yt-dlp : ${yt:-NOT FOUND}"
echo "ffmpeg : ${ffmpeg:-NOT FOUND}"
echo "ffprobe: ${ffprobe:-NOT FOUND}"

if [ -n "$yt" ]; then
  "$yt" --version || true
fi
if [ -n "$ffmpeg" ]; then
  "$ffmpeg" -version | head -n 1 || true
fi

if [ -z "$yt" ]; then
  echo "ERROR: yt-dlp is required." >&2
  exit 1
fi

if [ -z "$ffmpeg" ]; then
  echo "WARN: ffmpeg not found. Download-only workflows work, but edit/convert features are limited." >&2
fi
