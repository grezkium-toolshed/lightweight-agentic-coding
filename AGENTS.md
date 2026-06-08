# AGENTS

## Overview

This repository provides a private, replicable **Local AI Cluster**.

Runtime defaults:
- llama.cpp `llama-server`
- OpenCode project config at `opencode.template.jsonc`
- profile-based model setup via `./bin/lac`
- Qwen 3.6 or Gemma 4 model families
- curated OpenCode agents under `.opencode/agents/`
- curated OpenCode skills under `.opencode/skills/`

This repo is intentionally private until the release gates in `docs/release/PRIVATE_UNTIL_RELEASE.md` are complete.

## BuildAndDevelopmentCommands

### Launch

```bash
./bin/lac runtime start
./bin/lac client open opencode
```

Windows:

```powershell
./bin/lac.ps1 runtime start
./bin/lac.ps1 client open opencode
```

Compatibility wrappers remain under `scripts/` for existing workflows.

### Profile Setup

```bash
./bin/lac models sync 24gb
./bin/lac profile apply 24gb
./bin/lac profile apply openrouter  # cloud-only
```

Windows:

```powershell
./bin/lac.ps1 models sync 24gb
./bin/lac.ps1 profile apply 24gb
```

## RepositoryIntent

The repo is broader than a coding-focused local setup. It should support:
- coding and refactoring
- documentation generation
- spreadsheets, decks, and office automation
- research and synthesis
- startup, home, and team agent workflows

## CodeStyleGuidelines

- 2-space indentation, no tabs
- LF line endings
- kebab-case or snake_case file names
- JSONC supports `//` comments
- INI sections use lowercase and hyphens
- OpenCode skills must live in `.opencode/skills/<name>/SKILL.md`
- OpenCode agent markdown should stay narrow and operationally useful
- Skill authoring guide: `docs/skills/AUTHORING.md`
- Skill template: `templates/skill/SKILL.md`
- Agent template: `templates/agent/agent.md`

## ErrorHandling

Common issues:
- `Connection refused`: start llama-server first
- `Cannot open file`: verify `AI_MODELS_DIR` and profile model files
- config parse error: re-render with `lac profile apply <profile>` or `lac setup <profile>`
- cloud model not found: run `lac provider verify-models` to check configured free models

## TestingStrategy

Manual validation:
1. `./scripts/doctor.sh`
2. `curl http://127.0.0.1:8080/health`
3. `curl http://127.0.0.1:8080/v1/models`
4. run `./bin/lac profile apply <profile>` to generate runtime config
5. launch OpenCode with generated config
6. verify `.opencode/agents` and `.opencode/skills` are recognized when using OpenCode

## ConfigurationFileLocations

- `opencode.template.jsonc`: source template for generated OpenCode config
- `.opencode/agents/`: curated subagents
- `.opencode/skills/`: curated skills
- `.opencode/dcp.jsonc`: Dynamic Context Pruning plugin config (installed/refreshed as `@tarquinen/opencode-dcp@latest` by device setup)
- `~/.config/opencode/plugins/`: globally installed OpenCode plugins
- `runtime-config/presets/<profile>.ini`: template presets
- `state/runtime/presets.active.ini`: generated active preset
- `state/active/profile.txt`: generated selected profile marker
- `state/clients/opencode/opencode.json`: generated OpenCode runtime config
- `scripts/`: setup, switch, launch, doctor, and sync scripts

## Open Design Integration

Open Design (nexu-io/open-design) provides design skills, craft rules, and brand design systems curated under:
- `.opencode/craft/` — 12 brand-agnostic design rulebooks (typography, color, anti-AI-slop, etc.)
- `.opencode/skills/` — 33 curated design/HTML/image/research skills
- `.opencode/design-systems/` — 20 brand `DESIGN.md` files (Linear, Vercel, Apple, Stripe, etc.)

These work offline without any daemon — ideal for local models.

For the full 155-skill / 150-design-system catalog, optionally install the MCP server:

```bash
curl -fsSL https://open-design.ai/install.sh | sh -s opencode
# Or if od CLI is already installed:
od mcp install opencode
```
