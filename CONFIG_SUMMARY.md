# Configuration Summary

## Canonical Files

- `opencode.jsonc`: project-level OpenCode config
- `runtime-config/presets/<profile>.ini`: llama.cpp profile templates
- `runtime-config/presets.active.ini`: generated active llama.cpp preset
- `runtime-config/active-profile.txt`: selected profile marker

## Profile Workflow

1. Download profile models:
   - `scripts/setup-models-device.sh --profile <id>`
   - `scripts/setup-models-device.ps1 -Profile <id>`
2. Generate active config:
   - `scripts/setup-config-device.sh --profile <id>`
   - `scripts/setup-config-device.ps1 -Profile <id>`
3. Launch:
   - `scripts/launch-llama.*`
   - `scripts/launch-opencode.*`

## Ports and Endpoints

- Default port: `8080`
- Health: `http://127.0.0.1:8080/health`
- OpenAI-compatible API: `http://127.0.0.1:8080/v1`

## Deprecated Runtime Surface

- `oh-my-opencode` plugin and config files are not part of active runtime.
