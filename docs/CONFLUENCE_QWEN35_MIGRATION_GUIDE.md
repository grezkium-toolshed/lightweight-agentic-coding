# Confluence Post: lac — Lightweight Agentic Coding vNext Migration

## Why We Are Migrating

We are broadening our setup from a coding-focused OpenCode cluster into a more general **lac** setup built around **llama.cpp + the Qwen local baseline**. This improves portability, reduces configuration drift, supports lower-memory devices, and gives teams a stronger baseline for agentic workflows beyond coding alone.

## What Changed

- `oh-my-opencode` is removed from active runtime flow.
- Root `opencode.template.jsonc` is now the source template for generated OpenCode runtime config.
- We now use the profile-based `lac` CLI for macOS/Linux and Windows, with legacy scripts kept only as compatibility wrappers.
- Qwen 3.6 MTP (27B Q4, 35B-A3B Q6) replaces coder-next in local presets for better tool-call reliability and 1.4-2.2x faster inference via speculative decoding
- Curated OpenCode agents and skills are now part of the repo for review, docs, and office workflows.
- NVIDIA NIM and other free cloud fallbacks are part of the supported provider guidance.
- OpenChamber is now a supported client target for mobile/remote access to the OpenCode agent.

## New Hardware Profiles

- `16gb`: small-model Qwen profile
- `24gb`: balanced Qwen profile
- `32gb`: Qwen 3.6 27B + 27B MTP
- `64gb`: Qwen 3.6 35B-A3B + 35B-A3B MTP
- `128gb-multi`: Qwen 3.6 multi-model + MTP variants
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
3. Validate health and active profile with `./bin/lac doctor` or `./bin/lac smoke`.

## Operations Checklist

- Confirm `llama-server` and `opencode` are installed.
- Confirm selected profile model files exist.
- Confirm `state/runtime/presets.active.ini` exists.
- Confirm `state/clients/opencode/opencode.json` exists.
- Confirm health endpoint is reachable.
- Confirm OpenCode uses the generated `state/clients/opencode/opencode.json`.

## Notes for Mixed OS Teams

- Use `./bin/lac` on macOS/Linux.
- Use `./bin/lac.ps1` on Windows.
- Keep profile IDs identical across OSes for parity.
