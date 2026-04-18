# AdminCore UI Kit

## Purpose
Reference rules for composing admin panel UI with AdminCore baseline.

## Source of Truth
- `assets/admincore/css/admincore-theme.min.css`
- `assets/admincore/css/admincore-user.min.css`
- `tools/ADMINCORE-COMPONENT-CATALOG.md`
- `assets/admincore/examples/**/*.html`

## Workflow
1. Locate nearest matching example in catalog.
2. Reuse structural pattern and spacing hierarchy.
3. Apply project-specific data/state behavior.
4. Validate responsiveness and accessibility.

## Chart and Table Guidance
- For charts, prefer patterns from `modules/echarts` examples when imported.
- For tables and forms, follow matching examples from `modules/tables` and `modules/forms`.
- Keep interaction density and spacing consistent with baseline examples.

## Prohibited
- Free-form visual redesign for admin surfaces without user request.
- Unapproved replacement of baseline tokens/components.
