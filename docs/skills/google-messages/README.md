# google-messages

Purpose: browser-assisted SMS/RCS workflow with explicit privacy controls.

## Status
Planned optional package.

## Install intent
- Add pack via installer flag (planned): `--enable-pack google-messages`

## Scope
- Open message web client
- Read conversation snapshots
- Draft/send messages after explicit user confirmation

## Privacy and safety policy
- Disabled by default
- Requires explicit opt-in per project
- Inbound forwarding disabled by default
- No background forwarding without a dedicated confirmation step

## Outputs
- `.ai/reports/google-messages-setup.md`
- `.ai/reports/google-messages-activity.md`