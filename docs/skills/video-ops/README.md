# video-ops

Purpose: optional video workflow pack for download, trim, convert, and audio extraction.

## Profile Type
- **Custom Project profile (opt-in only)**.
- Recommended only for teams/projects with explicit media processing needs.
- Not recommended as a default pack for regular app development projects.

## Install intent
- Enable via installer flag: `--enable-pack video-ops`

## What it adds
- `Video-Download-Editor-Agent`
- Tool checks for `yt-dlp`, `ffmpeg`, `ffprobe`
- Command cookbook for:
  - quality-aware download
  - subtitle embedding
  - section trim
  - remux/transcode
  - audio extraction
- Playlist ingest automation script:
  - `playlist-ingest.ps1` (video/audio batch download + metadata + covers + screenshots + report)

## Windows compatibility
- Tool check script supports fallback path:
  - `C:\yt-dlp\yt-dlp.exe`

## Outputs and docs
- `.ai/copilot-config/agents/video-download-editor-agent.agent.md`
- `.ai/shared-docs/tools/VIDEO-DOWNLOAD-EDITING.md`
- `.ai/shared-docs/tools/check-video-tools.ps1`
- `.ai/shared-docs/tools/check-video-tools.sh`
- `.ai/shared-docs/tools/playlist-ingest.ps1`
- `.ai/shared-docs/tools/video-folder-ingest.ps1`
- `.ai/shared-docs/tools/clean-lesson-video.ps1`
- `.ai/shared-docs/rules/VIDEO-OPS-CUSTOM-PROFILE.md`
