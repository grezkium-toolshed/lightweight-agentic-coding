# QWEN.md — Local AI Cluster

## Project Overview

This repository is a **Local AI Cluster**: a local-first agentic workstation built around **llama.cpp** and **Qwen 3.6**, with **OpenCode** as the primary supported client. It is designed for technical users who want a low-friction setup for:

- Coding and refactoring
- Documentation generation
- Research and synthesis
- Office automation (`.docx`, `.pptx`, `.xlsx`, `.pdf`)
- Startup, home-lab, and team workflows

The architecture is deliberately split into four layers: local runtime, client integrations, curated agents/skills, and documentation.

## Directory Structure

| Path | Purpose |
|---|---|
| `opencode.template.jsonc` | Canonical OpenCode configuration (providers, models, permissions, compaction) |
| `.opencode/agents/` | Curated OpenCode subagents (architecture-reviewer, documentation-generator, reality-checker, release-reviewer, research-synthesizer) |
| `.opencode/skills/` | Curated skills for office workflows (docx, pptx, xlsx, pdf, documentation, research) |
| `scripts/` | Setup, launch, profile-switch, and doctor scripts (`.sh` + `.ps1`) |
| `runtime-config/` | Active presets, logs, and generated runtime state |
| `docs/` | Provider auth, release criteria, security rules, use-case onboarding guides |
| `templates/` | Claude Code integration templates |
| `models/` | Local model storage (gitignored) |

## Key Commands

### macOS / Linux

```bash
# Setup profile (choose: 16gb, 24gb, 32gb, 64gb, 128gb-multi, 128gb-qwen122b, 128gb-minimax)
./scripts/setup-models-device.sh --profile 24gb
./scripts/setup-config-device.sh --profile 24gb

# Launch
./scripts/launch-llama.sh
./scripts/launch-opencode.sh

# Desktop helper
./scripts/launch-opencode-desktop.sh

# Monitor logs
tail -f runtime-config/logs/llama-server.log

# Health check
./scripts/doctor.sh
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/v1/models
```

### Windows (PowerShell)

```powershell
./scripts/setup-models-device.ps1 -Profile 24gb
./scripts/setup-config-device.ps1 -Profile 24gb
./scripts/launch-llama.ps1
./scripts/launch-opencode.ps1

# Monitor logs
Get-Content runtime-config/logs/llama-server.log -Wait -Tail 50
```

## Hardware Profiles

| Profile | Models |
|---|---|
| `16gb` | Qwen 3.6 27B `UD-Q3_K_XL` + embeddings |
| `24gb` | Qwen 3.6 27B `UD-Q4_K_XL` + `UD-Q3_K_XL` fallback + embeddings |
| `32gb` | Qwen 3.6 27B `UD-Q4_K_XL` + optional coder-next |
| `64gb` | Qwen 3.6 35B-A3B `UD-Q8_K_XL` + coder-next + 27B + embeddings |
| `128gb-multi` | Qwen 3.6 35B-A3B `UD-Q8_K_XL` + coder-next + 27B `UD-Q4_K_XL` + 27B `UD-Q3_K_XL` + embeddings |
| `128gb-qwen122b` | Qwen 3.5 122B-focused |
| `128gb-minimax` | MiniMax-focused |
| `gemma-16gb` | Gemma 4 26B-A4B (Q4) + E4B (Q8) fallback |
| `gemma-24gb` | Gemma 4 31B (Q4) + 26B-A4B (Q4) fallback |
| `gemma-32gb` | Gemma 4 31B (Q8) + 26B-A4B (Q4) fallback |
| `gemma-64gb` | Gemma 4 31B (BF16) + 31B (Q8) + 26B-A4B (Q4) |

## Providers

`opencode.template.jsonc` includes five provider blocks:

1. **local-cluster** — llama.cpp via `http://127.0.0.1:8080/v1` (primary)
2. **antigravity** — Antigravity Cloud
3. **z-ai** — Z.AI Cloud
4. **nvidia-nim** — NVIDIA NIM free/trial
5. **openrouter** — OpenRouter free tier

Recommended cloud fallback order: NVIDIA NIM → OpenRouter → z.ai → Antigravity.

## Coding Conventions

- 2-space indentation, no tabs
- LF line endings
- kebab-case or snake_case file names
- JSONC supports `//` comments
- INI sections use lowercase and hyphens
- OpenCode skills must live in `.opencode/skills/<name>/SKILL.md`
- Agent markdown should be narrow and operationally useful

## Error Handling

| Error | Fix |
|---|---|
| `Connection refused` | Start llama-server first |
| `Cannot open file` | Verify `AI_MODELS_DIR` and profile model files |
| Config parse error | Regenerate with `setup-config-device` |
| Missing cloud provider access | Confirm provider-specific API keys and quotas |

## Important Notes

- **This repo is private** until release gates in `docs/release/PRIVATE_UNTIL_RELEASE.md` are complete
- The 128GB tiers follow a `<=115GB` effective memory usage policy
- `qwen3-coder-next` is a specialist model, not the default for every task
- Free cloud model snapshots in `docs/free-coding-models.json` should be refreshed before each beta cut

## Gemma 4 Alternative

Gemma 4 provides an Apache-2.0 licensed alternative with thinking mode (`<|think|>`), multimodal support, and MoE efficiency.

- **Inference defaults** (different from the Qwen baseline): `temp=1.0`, `top_p=0.95`, `top_k=64`, no repeat/presence penalties
- **EOS token**: `<turn|>`
- **Warning**: Do not use CUDA 13.2 runtime with GGUFs — causes degraded outputs
