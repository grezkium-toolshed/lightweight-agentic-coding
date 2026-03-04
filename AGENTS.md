# AGENTS

## Overview

This repository provides a public, replicable **OpenCode + llama.cpp** local coding cluster.

Runtime defaults:

- llama.cpp `llama-server`
- OpenCode project config at `opencode.jsonc`
- profile-based model setup via `scripts/setup-*.sh` and `scripts/setup-*.ps1`

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

## CodeStyleGuidelines

- 2-space indentation, no tabs
- LF line endings
- kebab-case or snake_case file names
- JSONC supports `//` comments
- INI sections use lowercase and hyphens

## ErrorHandling

Common issues:

- `Connection refused`: start llama-server first
- `Cannot open file`: verify `AI_MODELS_DIR` and profile model files
- config parse error: regenerate with `setup-config-device`

## TestingStrategy

Manual validation:

1. `./scripts/doctor.sh`
2. `curl http://127.0.0.1:8080/health`
3. `curl http://127.0.0.1:8080/v1/models`
4. launch OpenCode with root config

## ConfigurationFileLocations

- `opencode.jsonc`: canonical OpenCode config
- `runtime-config/presets/<profile>.ini`: template presets
- `runtime-config/presets.active.ini`: active preset
- `runtime-config/active-profile.txt`: selected profile
- `scripts/`: setup, switch, launch, and doctor scripts
