---
name: assessment-analysis
description: Analyze staged assessment run exports (json, md, csv) with a local model and produce operator-reviewed recommendation drafts
license: MIT
compatibility: opencode
metadata:
  audience: office
  output: recommendations-md
  workflow: analysis-and-review
---
## What I do
- Analyze an assessment `<run-id>` from its `input/` folder using `manifest.json` as the index of truth — never files outside it
- Use `bash` + python/pandas for files too large to read fully (staging caps them; see notes)
- Write `output/recommendations.md` with fixed sections, each figure traced to a source file
- Produce a meeting-ready summary (markdown; optional `summary.xlsx` via the xlsx-workflow skill)

## When to use me
Use this for assessment run exports — a mix of json, md, csv (and staged xlsx-as-csv) — when the goal is operator-reviewed recommendation drafts. Only run in a workspace staged by `scripts/stage_assessment.py`.

## Workflow
1. Read `input/manifest.json` first; analyze only files listed there. If the manifest is missing or lists no files, report the run as unanalyzable and stop — staging is at fault, not the model.
2. Read small files directly. For any file too large to read fully, use `bash` + python/pandas for counts, aggregations, and sampling — never dump the whole file into context.
3. Write `output/recommendations.md` with exactly these sections:
   - Summary: 3-5 bullets
   - Findings: each with a reference to the source file (and row where applicable)
   - Recommendations: ranked, each with rationale and required action
   - Data gaps: files/fields that were missing, capped, or unusable
   - Confidence: per-finding low/medium/high
4. Never invent numbers: every figure must trace to a file in the manifest; if it cannot be traced, list it under Data gaps.
5. Deliver the draft for operator review — output is always a draft until an operator approves it.

## Guardrails
- Do not analyze files not listed in `manifest.json`; never guess contents of a listed-but-missing file (report it under Data gaps).
- If a tool call fails, retry once; if it fails again, reduce scope (analyze one file or section) instead of retrying forever.
- If the export overflows context, do not push through — tell the operator to re-stage with tighter caps or a split.
- No network use (webfetch is denied in the workspace config); everything stays on the local llama-server endpoint.

## Notes
- Staging: `python3 scripts/stage_assessment.py --export <export-dir> --run-id <id>` from the repo root builds `input/` + `manifest.json` (dedupes, strips binaries, converts non-utf8, caps CSVs to row-sampled views).
- xlsx files are converted to csv at staging; if conversion was impossible, the manifest notes it and the sheet layout must be trivial to read.
- Operators may add `input/notes.md` (previous-run context) before the run; treat it as context, not source data.
- Expected output shape: `output/recommendations.md` with the five fixed sections, optionally `output/summary.xlsx` via xlsx-workflow.
