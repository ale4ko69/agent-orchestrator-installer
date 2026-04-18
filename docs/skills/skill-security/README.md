# skill-security

Purpose: pre-install security audit for third-party skills and local skill bundles.

## Status
Planned optional package.

## Install intent
- Add pack via installer flag (planned): `--enable-pack skill-security`
- Run static checks before enabling any external skill.

## What it validates
- Dangerous execution patterns (`curl|bash`, dynamic eval, arbitrary shell execution)
- Secret/credential access patterns
- Persistence/system modification patterns
- Overbroad triggers and policy-bypass instructions

## Verdict model
- `critical`: block installation
- `high`: require explicit user confirmation
- `medium/low`: warn and continue with audit trail

## Outputs
- `.ai/reports/skill-security-report.md`
- `.ai/reports/skill-security-report.json`