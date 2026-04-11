# AGENTS

## Overview

This repository provides a private, replicable **Local AI Cluster**.

Runtime defaults:
- llama.cpp `llama-server`
- OpenCode project config at `opencode.jsonc`
- profile-based model setup via `scripts/setup-*.sh` and `scripts/setup-*.ps1`
- Qwen 3.5 or Gemma 4 model families
- curated OpenCode agents under `.opencode/agents/`
- curated OpenCode skills under `.opencode/skills/`

This repo is intentionally private until the release gates in `docs/release/PRIVATE_UNTIL_RELEASE.md` are complete.

## BuildAndDevelopmentCommands

### Launch

```bash
./scripts/launch-llama.sh
./scripts/launch-opencode.sh
```

Windows:

```powershell
./scripts/launch-llama.ps1
./scripts/launch-opencode.ps1
```

### Profile Setup

```bash
./scripts/setup-models-device.sh --profile 24gb
./scripts/setup-config-device.sh --profile 24gb
```

Windows:

```powershell
./scripts/setup-models-device.ps1 -Profile 24gb
./scripts/setup-config-device.ps1 -Profile 24gb
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
- config parse error: regenerate with `setup-config-device`
- missing cloud provider access: confirm provider-specific API keys and quotas

## TestingStrategy

Manual validation:
1. `./scripts/doctor.sh`
2. `curl http://127.0.0.1:8080/health`
3. `curl http://127.0.0.1:8080/v1/models`
4. launch OpenCode with root config
5. verify `.opencode/agents` and `.opencode/skills` are recognized when using OpenCode

## ConfigurationFileLocations

- `opencode.jsonc`: canonical OpenCode config
- `.opencode/agents/`: curated subagents
- `.opencode/skills/`: curated skills
- `runtime-config/presets/<profile>.ini`: template presets
- `runtime-config/presets.active.ini`: active preset
- `runtime-config/active-profile.txt`: selected profile
- `scripts/`: setup, switch, launch, doctor, and sync scripts
