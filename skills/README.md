# Curated Skills

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

Current focus areas:
- `docx-workflow`
- `pptx-workflow`
- `xlsx-workflow`
- `pdf-workflow`
- `documentation-generator`
- `research-synthesizer`
- `gsd`

These skills make the cluster immediately useful for office and documentation work, not only coding.
