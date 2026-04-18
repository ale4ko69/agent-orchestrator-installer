# google-workspace-gog

Purpose: productivity automation for Gmail, Calendar, Drive, Contacts, Sheets, and Docs via `gog` CLI.

## Status
Planned optional package.

## Install intent
- Installer switch (planned): `--gog`
- Optional granular services: `--gog-services gmail,calendar,drive,sheets,docs`

## Setup flow
- Check `gog` binary availability
- Run OAuth credential setup
- Add selected account/services
- Verify account list

## Safety policy
- Read-only operations are allowed by default
- Send/create/update actions require explicit user confirmation
- No credential/token values are written to reports

## Outputs
- `.ai/reports/google-workspace-setup.md`
- `.ai/reports/google-workspace-activity.md`