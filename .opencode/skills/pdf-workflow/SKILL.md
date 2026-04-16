---
name: pdf-workflow
description: Generate, inspect, or revise PDFs where layout and extractability matter
license: MIT
compatibility: opencode
metadata:
  audience: office
  output: pdf
  workflow: pdf-generation-and-extraction
---
## What I do
- Generate basic PDFs from structured content
- Extract and review text from existing PDFs
- Prefer `reportlab` for generation and `pypdf` or `pdfplumber` for inspection

## When to use me
Use this for printable reports, export-ready deliverables, and PDF extraction tasks.

## Workflow
1. Confirm whether the job is generation, inspection, or extraction.
2. Use PDF-native tools rather than treating PDF as plain text.
3. Keep generated layouts simple unless there is a template.
4. Clearly state any fidelity or extraction limits.

## Guardrails
- Do not claim perfect text extraction from scanned or image-heavy PDFs.
- Preserve original files unless the user explicitly requests in-place replacement.
- Flag OCR or layout fidelity constraints before final delivery.

## Notes
- Expected output shape: generated or analyzed PDF artifact plus a concise verification summary.
- Use visual checks when layout correctness materially matters.
