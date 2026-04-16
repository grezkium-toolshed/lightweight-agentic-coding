# Confluence Post: Local AI Cluster vNext Migration

## Why We Are Migrating

We are broadening our setup from a coding-focused OpenCode cluster into a more general **Local AI Cluster** built around **llama.cpp + Qwen 3.5**. This improves portability, reduces configuration drift, supports lower-memory devices, and gives teams a stronger baseline for agentic workflows beyond coding alone.

## What Changed

- `oh-my-opencode` is removed from active runtime flow.
- Root `opencode.jsonc` is now the source template for generated OpenCode runtime config.
- We now use profile-based setup scripts for macOS/Linux and Windows.
- `qwen3-coder-next` remains available as a high-value coding specialist model.
- Curated OpenCode agents and skills are now part of the repo for review, docs, and office workflows.
- NVIDIA NIM and other free cloud fallbacks are part of the supported provider guidance.

## New Hardware Profiles

- `16gb`: 9B profile
- `24gb`: 27B profile
- `32gb`: 35B-A3B profile
- `64gb`: 35B-A3B + coder-next
- `128gb-multi`: 35B-A3B + coder-next + 27B + 9B
- `128gb-qwen122b`: 122B-focused profile
- `128gb-minimax`: MiniMax-focused profile

For 128GB environments, defaults are tuned to keep effective usage at or below **115GB** for stability headroom.

## Migration Steps

### macOS/Linux

```bash
./scripts/setup-models-device.sh --profile 24gb
./scripts/setup-config-device.sh --profile 24gb
./scripts/launch-llama.sh
./scripts/launch-opencode.sh
```

### Windows PowerShell

```powershell
./scripts/setup-models-device.ps1 -Profile 24gb
./scripts/setup-config-device.ps1 -Profile 24gb
./scripts/launch-llama.ps1
./scripts/launch-opencode.ps1
```

## Rollback Plan

1. Keep local backups of previous configs if needed.
2. Switch to a lower profile if memory pressure occurs.
3. Validate health and active profile using `doctor` scripts.

## Operations Checklist

- Confirm `llama-server` and `opencode` are installed.
- Confirm selected profile model files exist.
- Confirm `runtime-config/presets.active.ini` exists.
- Confirm `runtime-config/opencode.active.json` exists.
- Confirm health endpoint is reachable.
- Confirm OpenCode uses the generated `runtime-config/opencode.active.json`.

## Notes for Mixed OS Teams

- Use `.sh` scripts on macOS/Linux.
- Use `.ps1` scripts on Windows.
- Keep profile IDs identical across OSes for parity.
