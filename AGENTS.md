# AGENTS

## Overview

This repository provides **lac — Lightweight Agentic Coding**.

Runtime defaults:
- llama.cpp `llama-server`
- OpenCode project config at `opencode.template.jsonc`
- profile-based model setup via `./bin/lac`
- Qwen 3.6 or Gemma 4 model families
- curated OpenCode agents under `.opencode/agents/`
- curated OpenCode skills under `.opencode/skills/`

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

The primary goal is the easiest possible **private, on-device AI setup for everyday work** — for people (often on corporate laptops where cloud AI is blocked) who want a local assistant that keeps their data on the machine. Best on Apple Silicon; runs on ordinary laptops too. Beyond that, the same engine supports:
- everyday knowledge work: proofreading, drafting, editing documents, summarizing
- office automation: spreadsheets, decks, docs
- coding and refactoring
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
1. `./bin/lac doctor`
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
- `scripts/`: compatibility wrappers, `verify.sh`/`integration-test.sh` checks, and the build-time data stager (`stage_data.py`)

## Open Design Integration (opt-in)

lac bundles only its own first-party agents and workflow skills. The Open Design
(nexu-io/open-design) catalog — design skills, craft rulebooks, and brand design-system
references — is **not** vendored here; it is fetched on demand so lac does not redistribute
third-party/proprietary content. Install it yourself:

```bash
curl -fsSL https://open-design.ai/install.sh | sh -s opencode
# Or if the od CLI is already installed:
od mcp install opencode
```

Once installed it works offline without a daemon — ideal for local models. See
`THIRD_PARTY_NOTICES.md` for attribution and license notes on that catalog.
