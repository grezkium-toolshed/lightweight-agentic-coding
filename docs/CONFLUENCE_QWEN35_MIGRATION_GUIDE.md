# Confluence Post: Local AI Cluster vNext Migration

## Why We Are Migrating

We are broadening our setup from a coding-focused OpenCode cluster into a more general **Local AI Cluster** built around **llama.cpp + the Qwen local baseline**. This improves portability, reduces configuration drift, supports lower-memory devices, and gives teams a stronger baseline for agentic workflows beyond coding alone.

## What Changed

- `oh-my-opencode` is removed from active runtime flow.
- Root `opencode.jsonc` is now the source template for generated OpenCode runtime config.
- We now use profile-based setup scripts for macOS/Linux and Windows.
- `qwen3-coder-next` remains available as a high-value coding specialist model.
- Curated OpenCode agents and skills are now part of the repo for review, docs, and office workflows.
- NVIDIA NIM and other free cloud fallbacks are part of the supported provider guidance.

## New Hardware Profiles

- `16gb`: small-model Qwen profile
- `24gb`: balanced Qwen profile
- `32gb`: Qwen MoE profile
- `64gb`: Qwen MoE + coder-next
- `128gb-multi`: Qwen multi-model profile
- `128gb-qwen122b`: 122B-focused profile
- `128gb-minimax`: MiniMax M2.7 `UD-IQ4_XS` alternative

For 128GB environments, defaults are tuned to keep effective usage at or below **115GB** for stability headroom.

## Migration Steps

### macOS/Linux

```bash
./bin/lac models sync 24gb
./bin/lac profile apply 24gb
./bin/lac runtime start
./bin/lac client open opencode
```

### Windows PowerShell

```powershell
./bin/lac.ps1 models sync 24gb
./bin/lac.ps1 profile apply 24gb
./bin/lac.ps1 runtime start
./bin/lac.ps1 client open opencode
```

## Rollback Plan

1. Keep local backups of previous configs if needed.
2. Switch to a lower profile if memory pressure occurs.
3. Validate health and active profile using `doctor` scripts.

## Operations Checklist

- Confirm `llama-server` and `opencode` are installed.
- Confirm selected profile model files exist.
- Confirm `state/runtime/presets.active.ini` exists.
- Confirm `state/clients/opencode/opencode.json` exists.
- Confirm health endpoint is reachable.
- Confirm OpenCode uses the generated `state/clients/opencode/opencode.json`.

## Notes for Mixed OS Teams

- Use `.sh` scripts on macOS/Linux.
- Use `.ps1` scripts on Windows.
- Keep profile IDs identical across OSes for parity.
