# OpenCode Local Cluster vNext

Public, replicable local AI coding cluster using **OpenCode + llama.cpp** by default.

## What Changed

- `oh-my-opencode` is decommissioned from active setup.
- Root `opencode.jsonc` is now the canonical OpenCode config.
- Profile-based presets and scripts support macOS/Linux and Windows.
- Qwen 3.5 models are the default family for non-coder-specialist roles.
- `qwen3-coder-next` stays as a high-value coding specialist model.

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

## Standard Environment Variables

- `AI_CLUSTER_ROOT`: repository root
- `AI_MODELS_DIR`: local model directory (`$AI_CLUSTER_ROOT/models` default)
- `AI_CLUSTER_PORT`: llama.cpp API port (`8080` default)
- `LLAMA_SERVER_BIN`: custom llama-server binary path

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

## Legacy Compatibility

Old scripts (`setup-models.sh`, `setup-presets.sh`, `setup-opencode-config.sh`, launcher wrappers) still exist for one transition cycle and delegate to new profile scripts.

## Additional Docs

- `ARCHITECTURE_OVERVIEW.md`
- `MODEL_RECOMMENDATIONS.md`
- `CONFIG_SUMMARY.md`
- `REVISION_NOTES.md`
- `docs/CONFLUENCE_QWEN35_MIGRATION_GUIDE.md`
