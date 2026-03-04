# Configuration Summary

## Canonical Files

- `opencode.jsonc`: project-level OpenCode config
- `runtime-config/presets/<profile>.ini`: llama.cpp profile templates
- `runtime-config/presets.active.ini`: generated active llama.cpp preset
- `runtime-config/active-profile.txt`: selected profile marker
- `docs/FREE_CLOUD_MODELS.md`: generated free cloud model snapshot

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

## Launch Logs and Monitoring

- Log file: `runtime-config/logs/llama-server.log`
- Previous launch log: `runtime-config/logs/llama-server.log.1`
- Unix tail: `tail -f runtime-config/logs/llama-server.log`
- Windows tail: `Get-Content runtime-config/logs/llama-server.log -Wait -Tail 50`

## Deprecated Runtime Surface

- `oh-my-opencode` plugin and config files are not part of active runtime.

## Cloud Provider Defaults

`opencode.jsonc` includes optional provider blocks for:

- Antigravity
- z.ai
- OpenRouter free models

Refresh free-model visibility with:

- `scripts/sync-free-cloud-models.sh`
- `scripts/sync-free-cloud-models.ps1`
