# Curated Skills

> **Warning:** Do NOT add skills here. This directory is a maintainers' index only. Add new skills to `.opencode/skills/<name>/SKILL.md` for runtime discovery.

This repo provides project-local OpenCode skills under `.opencode/skills/`.
Pack metadata and scenario mapping live in `catalog/workflow-packs.json` and `catalog/scenarios.json`.

The `skills/` directory is the maintainers' index; the runtime-discoverable files live in `.opencode/skills/*/SKILL.md`.

Contract:
- Do not treat `skills/` as a runtime load path.
- Keep canonical runnable skill files in `.opencode/skills/*/SKILL.md`.

Naming overlap policy:
- Some skill names intentionally match agent names (for example `documentation-generator`, `research-synthesizer`).
- Matching names are allowed and expected when an agent orchestrates work and a skill provides the reusable execution contract.
- If both exist, treat the skill as capability-level instructions and the agent as coordination logic.

Required SKILL.md contract:
- Frontmatter keys: `name`, `description`, `license`, `compatibility`, `metadata.audience`, `metadata.output`, `metadata.workflow`.
- Required sections: `What I do`, `When to use me`, `Workflow`, `Guardrails`, `Notes`.

## Skill Index

| Skill | Description | Audience | Output |
|---|---|---|---|
| `docx-workflow` | Create or revise .docx documents using reproducible local tooling | office | docx |
| `pptx-workflow` | Build or revise PowerPoint decks with a clear slide structure and speaker intent | office | pptx |
| `xlsx-workflow` | Create or revise spreadsheets with formulas, structure, and validation notes | office | xlsx |
| `pdf-workflow` | Generate, inspect, or revise PDFs where layout and extractability matter | office | pdf |
| `documentation-generator` | Draft practical setup, rollout, and usage documentation from repository reality | maintainers | markdown-docs |
| `research-synthesizer` | Turn scattered model, provider, and tooling research into concise recommendations | maintainers | recommendation-doc |
| `gsd` | Structured Discuss → Plan → Execute → Verify → Ship workflow to prevent context rot in multi-session work | maintainers | execution-plan-and-status |

These skills make the cluster immediately useful for office and documentation work, not only coding.
