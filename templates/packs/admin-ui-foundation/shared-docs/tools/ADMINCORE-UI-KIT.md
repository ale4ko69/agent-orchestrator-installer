# AdminCore UI Kit

## Purpose
Reference rules for composing admin panel UI with AdminCore baseline.

## Source of Truth
- `tools/admincore-canonical/component-examples.json` (primary, canonical mode)
- `tools/admincore-canonical/css-report.json` (primary, canonical mode)
- `assets/admincore/css/admincore-theme.min.css`
- `assets/admincore/css/admincore-user.min.css`
- `tools/ADMINCORE-COMPONENT-CATALOG.md` (legacy mode)
- `assets/admincore/examples/**/*.html` (legacy mode)

## Workflow
1. Select component from `component-examples.json` (`componentNames`/`componentsByType`).
2. Reuse canonical `domElement` as base HTML snippet.
3. Validate classes against `css-report.json` (no unapproved class invention).
4. Apply project-specific data/state behavior.
5. Validate responsiveness and accessibility.

## Chart and Table Guidance
- For charts, prefer patterns from `modules/echarts` examples when imported.
- For tables and forms, follow matching examples from `modules/tables` and `modules/forms`.
- Keep interaction density and spacing consistent with baseline examples.

## Prohibited
- Free-form visual redesign for admin surfaces without user request.
- Unapproved replacement of baseline tokens/components.
- Using legacy catalog/examples when canonical files are present.
