---
name: xlsx-workflow
description: Create or revise spreadsheets with formulas, structure, and validation notes
license: MIT
compatibility: opencode
metadata:
  audience: office
  output: xlsx
  workflow: office-spreadsheet-workflow
---
## What I do
- Create `.xlsx` workbooks for trackers, models, exports, and summaries
- Preserve or add formulas, tabs, headers, and basic formatting
- Prefer `openpyxl` for workbook edits and `pandas` for data shaping when useful

## When to use me
Use this for financial models, status trackers, planning sheets, imports/exports, and structured reporting.

## Workflow
1. Confirm workbook purpose, expected tabs, and key formulas.
2. Determine whether data is source-of-truth or derived.
3. Use `openpyxl` for workbook-safe edits.
4. Use `pandas` when tabular transforms are easier before writing back to Excel.
5. Report formulas or assumptions that may require human review.

## Guardrails
- Do not silently change formulas or references without stating it.
- Preserve existing sheet names when editing an established workbook unless instructed otherwise.
- Flag any ambiguity in date formats, currencies, or aggregation logic.

## Notes
- Expected output shape: workbook updates, formula assumptions, and review flags.
- Prefer stable workbook structure changes over dense formatting tweaks.
