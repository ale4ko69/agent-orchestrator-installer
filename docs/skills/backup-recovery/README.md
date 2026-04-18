# backup-recovery

Purpose: safe backup and restore flows for agent configuration in user projects.

## Status
Planned optional package.

## Install intent
- Add pack via installer flag (planned): `--enable-pack backup-recovery`

## Core workflow
- Create timestamped backup archives
- Verify archive contents before restore
- Restore only after explicit confirmation

## Safety defaults
- Dry-run first
- Pre-restore snapshot
- No destructive sync modes unless user confirms

## Outputs
- `.ai/reports/backup-run.md`
- `.ai/reports/restore-run.md`