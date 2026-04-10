# local-ai-cluster

Public beta preparation branch for a **Local AI Cluster**: a local-first agentic platform built around **llama.cpp + Qwen 3.5**, with OpenCode as the strongest supported local client path.

This repo is not ready for public visibility yet. Use `RELEASE_CHECKLIST.md` and `docs/release/PRIVATE_UNTIL_RELEASE.md` before changing repository visibility.

## What this project is

`local-ai-cluster` is a baseline for technical users who want a low-friction agentic workstation for:
- coding and refactoring
- documentation generation
- research and synthesis
- spreadsheets, decks, reports, and office automation
- startup, home-lab, and team workflows

## Stable versus evolving

### Stable enough for public beta
- llama.cpp-first runtime
- hardware-tier profile setup
- OpenCode local configuration and project-local agents or skills
- free-cloud fallback pattern

### Still evolving
- provider model lists and free-tier availability
- curated agent and skill pack breadth
- hosted-model guidance outside the main OpenCode path

## Choose your starting path

### Lowest friction local path
Use OpenCode with a `16gb` or `24gb` profile and add free cloud fallback only if needed.

### Stronger local path
Use `32gb` or `64gb` profile with Qwen 3.5 35B-A3B as the main general model and `qwen3-coder-next` as a specialist.

### Gemma 4 path
Use Gemma 4 as an alternative model family with Apache-2.0 licensing, thinking mode, and multimodal support. Start with `gemma-24gb` or `gemma-32gb` for the best balance. See `MODEL_RECOMMENDATIONS.md` for benchmarks and guidance.

### Hosted-model path
Use Claude Code via the templates under `templates/claude-code/` when lower setup friction matters more than local-first execution.

## Runtime defaults
- llama.cpp `llama-server`
- OpenCode project config in `opencode.jsonc`
- Qwen 3.5 profile-based local models
- free cloud fallback providers for lower-end hardware

## Hardware profiles
- `16gb`: Qwen 3.5 9B + embeddings
- `24gb`: Qwen 3.5 27B + 9B fallback + embeddings
- `32gb`: Qwen 3.5 35B-A3B + 27B + optional coder-next
- `64gb`: 35B-A3B + coder-next + 27B + embeddings
- `128gb-multi`: 35B-A3B + coder-next + 27B + 9B + embeddings
- `128gb-qwen122b`: Qwen 3.5 122B-focused profile
- `128gb-minimax`: MiniMax-focused profile
- `gemma-16gb`: Gemma 4 26B-A4B (Q4) + E4B (Q8) fallback
- `gemma-24gb`: Gemma 4 31B (Q4) + 26B-A4B (Q4) fallback
- `gemma-32gb`: Gemma 4 31B (Q8) + 26B-A4B (Q4) fallback
- `gemma-64gb`: Gemma 4 31B (BF16) + 31B (Q8) + 26B-A4B (Q4)

The 128GB tiers follow a practical `<=115GB` effective memory usage policy to preserve headroom.

## Quick start (macOS/Linux)

```bash
./scripts/setup-models-device.sh --profile 24gb
./scripts/setup-config-device.sh --profile 24gb
./scripts/launch-llama.sh
./scripts/launch-opencode.sh
```

Gemma 4 quick start:

```bash
./scripts/setup-models-device.sh --profile gemma-24gb
./scripts/setup-config-device.sh --profile gemma-24gb
./scripts/launch-llama.sh
./scripts/launch-opencode.sh
```

Desktop helper on macOS:

```bash
./scripts/launch-opencode-desktop.sh
```

Monitor llama-server logs:

```bash
tail -f runtime-config/logs/llama-server.log
```

## Quick start (Windows PowerShell)

```powershell
./scripts/setup-models-device.ps1 -Profile 24gb
./scripts/setup-config-device.ps1 -Profile 24gb
./scripts/launch-llama.ps1
./scripts/launch-opencode.ps1
```

Gemma 4 quick start:

```powershell
./scripts/setup-models-device.ps1 -Profile gemma-24gb
./scripts/setup-config-device.ps1 -Profile gemma-24gb
./scripts/launch-llama.ps1
./scripts/launch-opencode.ps1
```

Desktop helper:

```powershell
./scripts/launch-opencode-desktop.ps1
```

Monitor logs:

```powershell
Get-Content runtime-config/logs/llama-server.log -Wait -Tail 50
```

## Client paths

### OpenCode
Best-supported local path. Uses `opencode.jsonc`, `.opencode/agents/`, and `.opencode/skills/`.

### Claude Code
Supported through `templates/claude-code/` and reuse of curated agent or skill ideas. This repo does not duplicate the runtime stack for Claude Code.

### Codex
Documented as a pattern reference only for now. It is not a first-class runtime target in this repo.

## Free cloud fallback providers

`opencode.jsonc` includes starter provider blocks for:
- `antigravity`
- `z-ai`
- `nvidia-nim`
- `openrouter`

Use local Qwen 3.5 when you can. Use cloud fallbacks when hardware, onboarding speed, or trial workflows matter more.

Authentication expectations are documented in `docs/providers/AUTHENTICATION.md`.

## OpenCode-specific additions in this repo
- explicit `compaction.auto`, `compaction.prune`, and reserved token buffer
- watcher ignore rules for models, logs, and generated runtime state
- instruction globs for stable repo guidance
- safer shell permissions than `bash = allow`
- curated OpenCode subagents in `.opencode/agents/`
- curated OpenCode skills in `.opencode/skills/`

## Office and workflow skills

This repo includes reusable local skills for:
- `.docx`
- `.pptx`
- `.xlsx`
- `.pdf`
- documentation generation
- research synthesis

These are designed to make the cluster useful for office work immediately, not only coding.

## Onboarding scenarios
- `docs/use-cases/ONBOARDING_16GB_24GB.md`
- `docs/use-cases/ONBOARDING_32GB_PLUS.md`
- `docs/use-cases/ONBOARDING_CLAUDE_CODE.md`

## Free model snapshot policy

`docs/FREE_CLOUD_MODELS.md` and `docs/free-coding-models.json` stay tracked during beta as a reviewed snapshot of community-maintained free-model availability. Refresh them before each beta cut.

Kudos to **@vava-nessa** for the free model index and NIM helper tooling:
https://github.com/vava-nessa/free-coding-models

## Important docs
- `RELEASE_CHECKLIST.md`
- `ARCHITECTURE_OVERVIEW.md`
- `MODEL_RECOMMENDATIONS.md`
- `CONFIG_SUMMARY.md`
- `REVISION_NOTES.md`
- `docs/providers/README.md`
- `docs/providers/AUTHENTICATION.md`
- `docs/security/TRUST_MODEL.md`
- `docs/security/THIRD_PARTY_AGENT_INTAKE.md`
- `docs/release/BETA_RELEASE_CRITERIA.md`
