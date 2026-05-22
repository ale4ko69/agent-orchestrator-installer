# Architecture Notes

Purpose:
- capture durable architecture facts, boundaries, integration points, and tradeoffs
- help future agents understand system shape before editing code

Rules:
- Keep this file factual and current.
- Put formal choices in `decisions.md`.
- Put implementation chronology in `task-history.md`.
- Prefer diagrams or links when prose becomes too long.

## System Shape

_Add the current architecture summary here._

## Important Boundaries

| Boundary | Rule | Source |
| --- | --- | --- |
| _Example_ | _Describe ownership, API, data, or runtime boundary._ | _Link to source._ |

## Data And State

_Add notes about persisted state, generated files, caches, migrations, and ownership._

## Integration Points

| Integration | Direction | Notes |
| --- | --- | --- |
| _Example_ | _incoming/outgoing/internal_ | _Describe contract or link to docs._ |

## Operational Notes

_Add setup, runtime, deployment, recovery, or troubleshooting facts that are stable enough to preserve._
