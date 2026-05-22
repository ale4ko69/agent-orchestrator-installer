# Admin UI Foundation Policy

This policy is active when `admin-ui-foundation` pack is installed.

## Goal
Use a strict, reusable admin UI foundation (`AdminCore UI`) for admin panels.

## Base Selection
- Default base: `admincore`
- Allowed values: `admincore`, `custom`, `none`
- If base is `custom`, orchestrator must ask user for the approved UI baseline before implementation.
- Default source mode: `canonical`
- Legacy source mode: `legacy` (ZIP/source-import path)

## Hard Rules
- Use only approved AdminCore patterns and wrappers for admin panel UI.
- Do not introduce additional UI frameworks without explicit user approval.
- Before creating a new component, search the component catalog first.
- Reuse first; create new only when no matching pattern exists.

## Mandatory Example Lookup
Before UI implementation, agent must read:
1. `.ai/shared-docs/tools/admincore-canonical/component-examples.json`
2. `.ai/shared-docs/tools/admincore-canonical/css-report.json`
3. `.ai/shared-docs/tools/ADMINCORE-UI-KIT.md`
4. Legacy-only fallback: `.ai/shared-docs/tools/ADMINCORE-COMPONENT-CATALOG.md` + `.ai/shared-docs/assets/admincore/examples/`

## Acceptance Gate
A task fails UI review if:
- existing pattern was available but ignored;
- visual rules diverge from AdminCore baseline without approval;
- ad-hoc component style duplicates existing catalog patterns.
- canonical components exist but agent generated free-form DOM instead.
