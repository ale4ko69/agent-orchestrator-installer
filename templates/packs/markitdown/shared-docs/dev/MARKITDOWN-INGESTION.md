# MarkItDown Ingestion

MarkItDown is an optional external tool for converting source documents into Markdown.

Reference:

- https://github.com/microsoft/markitdown

This pack does not vendor MarkItDown source code and does not install MarkItDown automatically. It adds guidance for using MarkItDown with project analysis and knowledge workflows.

## Purpose

Use MarkItDown when project context exists in non-Markdown formats:

- PDF
- Word
- PowerPoint
- Excel
- HTML
- CSV / JSON / XML
- ZIP source bundles
- EPub
- image metadata or OCR-supported files
- audio transcripts
- YouTube transcripts

Converted Markdown should enter the raw knowledge inbox or analysis intake first. Curated project facts should be distilled later by an agent or human reviewer.

## Setup

Install MarkItDown using upstream instructions.

Common local setup:

```powershell
pip install "markitdown[all]"
```

Narrower installs may be preferable when only specific formats are needed:

```powershell
pip install "markitdown[pdf,docx,pptx,xlsx]"
```

Cloud-backed Azure integrations must remain opt-in because they may be billable and may send content to external services.

## Workflow

1. Put original source files in a raw inbox or project-approved input folder.
2. Convert source files to Markdown.
3. Preserve source filename, path, URL, or reference id in the converted output.
4. Review the converted Markdown before treating it as canonical.
5. Distill durable facts into `knowledge-foundation` wiki files or project docs.

## Suggested Paths

```text
.ai/knowledge/raw/imports/
.ai/knowledge/raw/converted/
.ai/shared-docs/project-overview.md
```

Do not overwrite curated wiki files automatically.

## Security

- Validate local paths before conversion.
- Restrict URI schemes and network access for untrusted input.
- Run conversion with least privileges.
- Do not run server-side conversion on arbitrary untrusted uploads without sandboxing.
- Keep secrets out of converted Markdown.
- Preserve source references so extracted facts can be audited.
