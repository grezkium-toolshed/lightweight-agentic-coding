# Skill Authoring Guide

## What is a skill?

A skill is a reusable capability that OpenCode agents can invoke during workflows. Skills encode *how* to do something — not just *what* — making them more reliable than ad-hoc prompting.

## Where skills live

All skills are stored in `.opencode/skills/<name>/` and must include a `SKILL.md` file:

```
.opencode/skills/
  docx-workflow/
    SKILL.md
  my-new-skill/
    SKILL.md
```

## SKILL.md structure

Every skill has two parts:

### Frontmatter (YAML)
```yaml
---
name: skill-name
description: One-line description
license: MIT
compatibility: opencode
metadata:
  audience: who-uses-this
  output: what-it-produces
  workflow: how-it-runs
---
```

- `name`: kebab-case, matches the directory name
- `description`: single sentence, shown in agent UI
- `license`: SPDX identifier (MIT, Apache-2.0, etc.)
- `compatibility`: currently `opencode`
- `metadata.audience`: category like `office`, `developer`, `research`
- `metadata.output`: the primary artifact type
- `metadata.workflow`: concise workflow class (for example `doc-generation`, `research-synthesis`, `analysis-and-review`)

### Body (Markdown)
Use the template at `templates/skill/SKILL.md`. Key sections:

| Section | Purpose |
|---|---|
| **What I do** | 3-5 bullets on core capabilities and tooling |
| **When to use me** | Concrete scenarios, not vague descriptions |
| **Workflow** | Numbered steps the agent follows |
| **Guardrails** | Constraints and escalation rules |
| **Notes** | Dependencies, limitations, edge cases, expected output shape |

All five sections above are required. Additional sections are optional when they add value and remain concise.

## Conventions

- kebab-case directory and `name` field
- 2-space indentation, LF line endings
- Keep skills narrow — one skill, one capability
- Prefer tool-based validation over claims
- Reference existing skills rather than duplicating logic

## Testing a skill

1. Place the `SKILL.md` in `.opencode/skills/<name>/`
2. Launch OpenCode with the repo config
3. Verify the skill appears in the available skills list
4. Trigger it through the appropriate agent or command
