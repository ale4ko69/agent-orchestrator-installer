---
name: markitdown-ingest
description: Convert non-Markdown project source documents into reviewable Markdown intake using MarkItDown when available.
---

# markitdown-ingest

## Goal

Use MarkItDown as an optional external converter for project document ingestion.

## Workflow

1. Confirm MarkItDown is installed and appropriate for the source format.
2. Identify the source file and intended raw output path.
3. Convert to Markdown.
4. Preserve source filename/path/reference metadata.
5. Review the converted output for missing structure, OCR errors, table loss, or unsupported content.
6. Distill only reviewed facts into curated docs or `knowledge-foundation`.

## Output Contract

Return:

1. Source path or reference
2. Converted Markdown path
3. Conversion command
4. Known extraction limitations
5. Suggested next curation target

## Rules

- Do not overwrite curated wiki files directly.
- Do not send sensitive files to cloud conversion services without explicit approval.
- Do not delete original source files.
- Treat converted content as raw intake until reviewed.
