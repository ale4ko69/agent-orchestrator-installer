# Admin UI Profile

## Selected Base
- Value is set by installer: `adminUiBase` (`admincore` by default).
- Source mode is set by installer: `adminUiMode` (`canonical` by default).

## Expected Behavior
- `admincore`: enforce baseline and examples-first workflow.
- `custom`: ask user to provide baseline before coding.
- `none`: no strict admin UI foundation enforcement.
- `canonical` mode: use only canonical JSON inputs (`component-examples.json`, `css-report.json`).
- `legacy` mode: use ZIP/source-imported examples/catalog as fallback.
