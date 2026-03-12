# Local AI Cluster vNext

Private, replicable **Local AI Cluster** for agentic work using **llama.cpp + Qwen 3.5** by default, with OpenCode as the strongest local client path.

This repo is being prepared for a future public release, but it should remain private until the release gates in `docs/release/PRIVATE_UNTIL_RELEASE.md` are complete.

## What this repo is for

This is a baseline platform for technical users who want a low-friction local AI workstation for:
- coding and refactoring
- documentation generation
- research and synthesis
- spreadsheets, decks, reports, and office automation
- startup, home-lab, and team workflows

## Runtime defaults

- llama.cpp `llama-server`
- OpenCode project config in `opencode.jsonc`
- Qwen 3.5 profile-based local models
- free cloud fallback providers for lower-end hardware

## Hardware profiles

- `16gb`: Qwen3.5 9B + embeddings
- `24gb`: Qwen3.5 27B + 9B fallback + embeddings
- `32gb`: Qwen3.5 35B-A3B + 27B + optional coder-next
- `64gb`: 35B-A3B + coder-next + 27B + embeddings
- `128gb-multi`: 35B-A3B + coder-next + 27B + 9B + embeddings
- `128gb-qwen122b`: Qwen3.5 122B-focused profile
- `128gb-minimax`: MiniMax-focused profile

The 128GB tiers follow a practical `<=115GB` effective memory usage policy to preserve headroom.

## Quick start (macOS/Linux)

```bash
./scripts/setup-models-device.sh --profile 24gb
./scripts/setup-config-device.sh --profile 24gb
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

## Syncing free model availability

You can refresh the community-maintained free-model snapshot with:

```bash
./scripts/sync-free-cloud-models.sh
```

PowerShell:

```powershell
./scripts/sync-free-cloud-models.ps1
```

Generated files:
- `docs/free-coding-models.json`
- `docs/FREE_CLOUD_MODELS.md`

Kudos to **@vava-nessa** for the free model index and NIM helper tooling:
https://github.com/vava-nessa/free-coding-models

## Important docs

- `ARCHITECTURE_OVERVIEW.md`
- `MODEL_RECOMMENDATIONS.md`
- `CONFIG_SUMMARY.md`
- `REVISION_NOTES.md`
- `docs/providers/README.md`
- `docs/security/THIRD_PARTY_AGENT_INTAKE.md`
- `docs/release/PRIVATE_UNTIL_RELEASE.md`
- `docs/use-cases/STARTUP_HOME_TEAM.md`
