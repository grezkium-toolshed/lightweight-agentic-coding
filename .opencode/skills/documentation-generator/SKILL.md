---
name: documentation-generator
description: Draft practical setup, rollout, and usage documentation from repository reality
license: MIT
compatibility: opencode
metadata:
  audience: maintainers
  output: markdown-docs
  workflow: doc-generation
---
## What I do
- Write docs that match the repo's current files and commands
- Convert implementation details into onboarding, rollout, or migration guides
- Keep structure tight and examples executable

## When to use me
Use this for README updates, internal migration docs, and public-facing setup guidance.

## Workflow
1. Inspect the current repository state and source files before writing.
2. Confirm audience, scope, and required doc sections.
3. Draft docs with executable commands and precise file references.
4. Verify commands, paths, and platform notes against the repo.
5. Deliver concise docs with assumptions and follow-up notes.

## Guardrails
- Never invent scripts, flags, or files that are not present.
- Call out prerequisites and platform differences.
- Prefer concrete commands and file references over generic prose.

## Notes
- Expected output shape: short summary, step-by-step guidance, and validation notes.
- Keep language operational and avoid abstract policy text unless requested.
