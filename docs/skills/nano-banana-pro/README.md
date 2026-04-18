# nano-banana-pro

Purpose: high-quality image generation/editing workflow using a Gemini-based image model.

## Status
Planned optional package.

## Install intent
- Add pack via installer flag (planned): `--enable-pack nano-banana`

## Scope
- Prompt-based generation
- Input-image editing mode
- 1K/2K/4K output workflow (draft -> iterate -> final)

## Runtime requirements
- `uv`
- Python 3.10+
- `google-genai`
- `pillow`
- `GEMINI_API_KEY`

## Safety policy
- API key from environment only
- Output path restricted to workspace

## Outputs
- `.ai/reports/nano-banana-activity.md`