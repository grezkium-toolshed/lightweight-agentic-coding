---
name: pptx-workflow
description: Build or revise PowerPoint decks with a clear slide structure and speaker intent
license: MIT
compatibility: opencode
metadata:
  audience: office
  output: pptx
  workflow: office-deck-generation
---
## What I do
- Create `.pptx` decks from outlines or narrative goals
- Update slide copy, section flow, and table content
- Prefer `python-pptx` for repeatable generation
- Keep slide density low and structure explicit

## When to use me
Use this for investor decks, internal updates, roadmap reviews, and workshop materials.

## Workflow
1. Confirm audience, slide count target, and tone.
2. Build a slide outline before generating content.
3. Use `python-pptx` for generation.
4. Keep one message per slide unless the user requests a denser deck.
5. Note any design limitations or template dependencies.

## Guardrails
- Avoid claiming polished visual design unless a template exists or the deck was reviewed visually.
- Keep charts/tables simple unless source data is reliable.
- Treat decks as communication tools, not document dumps.

## Notes
- Expected output shape: audience-aware slide outline, generated deck updates, and limitations.
- If a branded template is required, request it before doing detailed visual work.
