---
name: docx-workflow
description: Create or revise .docx documents using reproducible local tooling
license: MIT
compatibility: opencode
metadata:
  audience: office
  output: docx
---
## What I do
- Draft `.docx` documents from structured requirements
- Update existing Word documents while preserving headings and basic formatting
- Prefer `python-docx` for generation and targeted edits
- Call out when layout fidelity or review loops require manual verification

## When to use me
Use this for proposals, project briefs, SOPs, meeting summaries, and internal documentation that must end up as a Word document.

## Workflow
1. Confirm the target file path and whether this is a new document or an edit.
2. Gather the required structure: title, sections, tables, appendices, and any mandatory phrasing.
3. Use `python-docx` for document creation or edits.
4. Keep formatting simple and robust unless the user requests a specific template.
5. Summarize what changed and any limitations.

## Guardrails
- Do not claim pixel-perfect Word layout unless it was visually checked.
- If the repo already includes a document template, reuse it.
- Keep generated content professional and concise.

## Notes
If `python-docx` is unavailable, say so clearly and provide the exact dependency needed.
