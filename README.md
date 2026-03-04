# OpenCode Local Cluster vNext

Public, replicable local AI coding cluster using **OpenCode + llama.cpp** by default.

## What Changed

- `oh-my-opencode` is decommissioned from active setup.
- Root `opencode.jsonc` is now the canonical OpenCode config.
- Profile-based presets and scripts support macOS/Linux and Windows.
- Qwen 3.5 models are the default family for non-coder-specialist roles.
- `qwen3-coder-next` stays as a high-value coding specialist model.
- Default cloud provider blocks are included for Antigravity, z.ai, and OpenRouter free models.

## Hardware Profiles

- `16gb`: Qwen3.5 9B + embeddings
- `24gb`: Qwen3.5 27B + 9B fallback + embeddings
- `32gb`: Qwen3.5 35B-A3B + 27B + optional coder-next
- `64gb`: 35B-A3B + coder-next + 27B + embeddings
- `128gb-qwen122b`: Qwen3.5 122B-focused profile (<=115GB effective usage policy)
- `128gb-minimax`: MiniMax-focused profile (<=115GB effective usage policy)

## Quick Start (macOS/Linux)

```bash
# 1) Download models for your hardware tier
./scripts/setup-models-device.sh --profile 24gb

# 2) Generate active preset + OpenCode model selection
./scripts/setup-config-device.sh --profile 24gb

# 3) Start llama.cpp server
./scripts/launch-llama.sh

# 4) Launch OpenCode
./scripts/launch-opencode.sh
```

Monitor llama-server logs:

```bash
tail -f runtime-config/logs/llama-server.log
```

## Quick Start (Windows PowerShell)

```powershell
# 1) Download models for your hardware tier
./scripts/setup-models-device.ps1 -Profile 24gb

# 2) Generate active preset + OpenCode model selection
./scripts/setup-config-device.ps1 -Profile 24gb

# 3) Start llama.cpp server
./scripts/launch-llama.ps1

# 4) Launch OpenCode
./scripts/launch-opencode.ps1
```

Monitor llama-server logs:

```powershell
Get-Content runtime-config/logs/llama-server.log -Wait -Tail 50
```

## Standard Environment Variables

- `AI_CLUSTER_ROOT`: repository root
- `AI_MODELS_DIR`: local model directory (`$AI_CLUSTER_ROOT/models` default)
- `AI_CLUSTER_PORT`: llama.cpp API port (`8080` default)
- `LLAMA_SERVER_BIN`: custom llama-server binary path

## Default Cloud Providers

`opencode.jsonc` includes ready-to-use provider blocks for:

- `antigravity`
- `z-ai`
- `openrouter` (free model variants)

Local llama.cpp remains the default runtime and default model. Cloud providers are optional and require their own API credentials.

## Free Models Sync (with Kudos)

You can snapshot currently free/available cloud coding models from the community project:

```bash
./scripts/sync-free-cloud-models.sh
```

PowerShell:

```powershell
./scripts/sync-free-cloud-models.ps1
```

Generated outputs:

- `docs/free-coding-models.json`
- `docs/FREE_CLOUD_MODELS.md`

Kudos to **@vava-nessa** for the free model index and NIM helper tooling:
https://github.com/vava-nessa/free-coding-models

## llama.cpp Presets

- Preset templates: `runtime-config/presets/<profile>.ini`
- Active preset: `runtime-config/presets.active.ini`
- Active profile marker: `runtime-config/active-profile.txt`

The presets use llama.cpp server key names only (`ctx-size`, `batch-size`, `ubatch-size`, `n-gpu-layers`, `flash-attn`, etc).

## Validation

```bash
./scripts/doctor.sh
./verify-documentation.sh
```

PowerShell:

```powershell
./scripts/doctor.ps1
```

## Launch Visibility

`scripts/launch-llama.*` now always writes runtime logs to:

- `runtime-config/logs/llama-server.log`

Log rotation policy:

- previous run is moved to `runtime-config/logs/llama-server.log.1`

Optional flags:

- Unix: `./scripts/launch-llama.sh --show-logs`
- Windows: `./scripts/launch-llama.ps1 -ShowLogs`
- Both support disabling hint output (`--no-tail-hint` / `-NoTailHint`)

## Additional Docs

- `ARCHITECTURE_OVERVIEW.md`
- `MODEL_RECOMMENDATIONS.md`
- `CONFIG_SUMMARY.md`
- `REVISION_NOTES.md`
- `docs/CONFLUENCE_QWEN35_MIGRATION_GUIDE.md`
- `docs/FREE_CLOUD_MODELS.md`
