# Video Download And Editing Toolkit

This pack enables repeatable video workflows based on `yt-dlp` and `ffmpeg`.

## Profile Status
- `video-ops` is a **Custom Project profile (opt-in only)**.
- Enable it only for projects that explicitly require media download/edit pipelines.
- Default/general projects should keep this pack disabled.

Profile map and policy:
- `./.ai/shared-docs/rules/VIDEO-OPS-CUSTOM-PROFILE.md`

## Preflight Checks
- Windows PowerShell:
  - `pwsh ./.ai/shared-docs/tools/check-video-tools.ps1`
- Linux/macOS:
  - `bash ./.ai/shared-docs/tools/check-video-tools.sh`

## Playlist Automation Script (PowerShell)
- Full ingest (video + audio + metadata + covers + screenshots):
  - `pwsh ./.ai/shared-docs/tools/playlist-ingest.ps1 -PlaylistUrl "<PLAYLIST_URL>" -OutputRoot "./output/playlist-ingest" -Mode both`
- Metadata only:
  - `pwsh ./.ai/shared-docs/tools/playlist-ingest.ps1 -PlaylistUrl "<PLAYLIST_URL>" -Mode metadata-only`
- Limit first N items:
  - `pwsh ./.ai/shared-docs/tools/playlist-ingest.ps1 -PlaylistUrl "<PLAYLIST_URL>" -Mode both -MaxItems 10`

The script generates:
- `playlist-report.md`
- `playlist-report.json`
- per-video metadata JSON
- cover images (thumbnails)
- screenshots extracted from video files (if ffmpeg is available)

## Local Folder Ingest (PowerShell)
- Process a folder with local videos:
  - `pwsh ./.ai/shared-docs/tools/video-folder-ingest.ps1 -InputDir "D:\MyVideos" -OutputRoot "./output/video-folder-ingest"`

It generates:
- `folder-report.md`
- `folder-report.json`
- per-video metadata JSON files
- cover images extracted from middle frame
- draft title/description for each video

## Lesson Cleanup / Ad-ish Segments (PowerShell)
- Auto-trim likely intro/outro non-lesson parts:
  - `pwsh ./.ai/shared-docs/tools/clean-lesson-video.ps1 -InputFile ".\lesson.mp4" -OutputFile ".\lesson.clean.mp4"`

Notes:
- Mid-roll ad detection inside the lesson is heuristic (not guaranteed).
- For high confidence, combine this with manual review or transcript-based keyword review.

## Download Recipes (yt-dlp)
- Best MP4 compatible:
  - `yt-dlp -f "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/b" -o "./output/%(title)s.%(ext)s" "<URL>"`
- Download with subtitles:
  - `yt-dlp --write-subs --sub-langs "en.*,ru.*,he.*" --embed-subs -o "./output/%(title)s.%(ext)s" "<URL>"`
- Playlist to folder:
  - `yt-dlp -o "./output/%(playlist_title)s/%(playlist_index)02d-%(title)s.%(ext)s" "<PLAYLIST_URL>"`

## Trim/Cut Recipes
- Fast section download (if supported by extractor):
  - `yt-dlp --download-sections "*00:00:30-00:01:45" -o "./output/%(title)s.%(ext)s" "<URL>"`
- Lossless-ish local trim with stream copy:
  - `ffmpeg -ss 00:00:30 -to 00:01:45 -i "input.mp4" -c copy "clip.mp4"`
- Accurate trim (re-encode):
  - `ffmpeg -ss 00:00:30 -to 00:01:45 -i "input.mp4" -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 192k "clip-accurate.mp4"`

## Format Conversion
- MP4 -> WebM:
  - `ffmpeg -i "input.mp4" -c:v libvpx-vp9 -crf 32 -b:v 0 -c:a libopus "output.webm"`
- MP4 -> MOV (editing-friendly):
  - `ffmpeg -i "input.mp4" -c:v prores_ks -profile:v 3 -c:a pcm_s16le "output.mov"`
- Remux MKV -> MP4 (no re-encode):
  - `ffmpeg -i "input.mkv" -c copy "output.mp4"`

## Audio Extraction
- Best audio:
  - `yt-dlp -x --audio-format mp3 --audio-quality 0 -o "./output/%(title)s.%(ext)s" "<URL>"`
- Local video to WAV:
  - `ffmpeg -i "input.mp4" -vn -c:a pcm_s16le "audio.wav"`

## Metadata And Validation
- Media info:
  - `ffprobe -v error -show_streams -show_format "input.mp4"`
- List available formats:
  - `yt-dlp -F "<URL>"`

## Notes
- Some operations require re-encode and may reduce quality.
- Prefer writing outputs into project-local `./output` directory.
- Respect legal/copyright constraints for source content.
