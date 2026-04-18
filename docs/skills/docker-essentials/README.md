# docker-essentials

Purpose: common Docker run/build/debug workflows for project-level development.

## Status
Planned optional package.

## Install intent
- Add pack via installer flag (planned): `--enable-pack docker-essentials`

## Scope
- Container lifecycle commands
- Image build/tag/push routines
- Logs/inspect/exec troubleshooting
- Compose-based local environments

## Safety policy
- No automatic prune/delete actions
- Destructive operations are suggestion-only with explicit confirmation

## Outputs
- `.ai/shared-docs/tools/DOCKER-ESSENTIALS.md`