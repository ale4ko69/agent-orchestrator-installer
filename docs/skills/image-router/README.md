# image-router

Purpose: route image generation/edit requests through an external image API provider.

## Status
Planned optional package.

## Install intent
- Add pack via installer flag (planned): `--enable-pack image-router`

## Scope
- Text-to-image generation
- Image-to-image edits
- Model routing and parameter presets

## Safety policy
- API key via environment variable only
- No API key echoing/logging
- Explicit confirmation for paid/high-cost operations

## Outputs
- `.ai/reports/image-router-activity.md`