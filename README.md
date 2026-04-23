# local-ai-cluster

Public beta preparation branch for a **Local AI Cluster**: a local-first AI workstation built around **llama.cpp + Qwen 3.6**, with OpenCode as the lead supported local client path and a new v2 CLI contract for setup, rendering, and validation.

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

### Solo coder
Use `24gb` or `32gb` with the `coding` workflow pack for local-first coding and refactoring.

### Research operator
Use `24gb`, `gemma-24gb`, or `openrouter` with the `research` and `office` packs.

### Office automation
Use `16gb`, `24gb`, or `openrouter` with the `office` pack.

### Team pilot
Use `32gb`, `64gb`, or `openrouter` with the `team-rollout` pack.

Scenario mapping lives in `docs/use-cases/SCENARIO_GUIDE.md` and `catalog/scenarios.json`.
Hybrid local-plus-cloud and multi-workspace rollout notes live in `docs/use-cases/HYBRID_WORKSPACES.md`.

## Runtime defaults
- llama.cpp `llama-server`
- OpenCode source template config in `opencode.jsonc`
- generated active runtime state under `state/`
- Qwen 3.6 profile-based local models, staged as GGUF for llama.cpp and with optional MLX artifacts on macOS
- free cloud fallback providers for lower-end hardware
- a first-class repo CLI at `./bin/lac`

## Hardware profiles
- `16gb`: Qwen 3.6 27B `UD-Q3_K_XL` starter + embeddings
- `24gb`: Qwen 3.6 27B `UD-Q4_K_XL` + `UD-Q3_K_XL` fallback + embeddings
- `32gb`: Qwen 3.6 27B `UD-Q4_K_XL` + optional coder specialist
- `64gb`: Qwen 3.6 35B-A3B `UD-Q8_K_XL` + 27B fallback + coder specialist + embeddings
- `128gb-multi`: multi-model Qwen local workstation
- `128gb-qwen122b`: large-model Qwen-focused profile
- `128gb-minimax`: MiniMax M2.7 `UD-IQ4_XS` profile for a practical 128GB fit
- `gemma-16gb`: Gemma 4 26B-A4B (Q4) + E4B (Q8) fallback
- `gemma-24gb`: Gemma 4 31B (Q4) + 26B-A4B (Q4) fallback
- `gemma-32gb`: Gemma 4 31B (Q8) + 26B-A4B (Q4) fallback
- `gemma-64gb`: Gemma 4 31B (BF16) + 31B (Q8) + 26B-A4B (Q4)
- `openrouter`: Cloud-only, zero downloads — uses OpenRouter free tier via `opencode.jsonc`
- `opencode-go`: Cloud-only, zero downloads — uses OpenCode Go subscription models via `opencode.jsonc`

The 128GB tiers follow a practical `<=115GB` effective memory usage policy to preserve headroom.

## Quick start (macOS/Linux)

One-command onboarding (recommended):

```bash
./bin/lac init
```

`lac init` detects your hardware, recommends a local profile, asks which hosted model overlays to enable, and applies the profile. The recommended hybrid path is local Qwen/Gemma plus both OpenCode Go and OpenRouter: Go for reliable subscription capacity, OpenRouter for free/trial fallback. It stops before downloading model weights and prints the exact next commands to run.

Non-interactive / scripted install:

```bash
./bin/lac init --yes --profile 24gb --cloud openrouter
./bin/lac models sync 24gb
./bin/lac runtime start
./bin/lac client open opencode
```

Recommended hybrid install with OpenCode Go and OpenRouter:

```bash
export OPENCODE_GO_API_KEY=...
export OPENROUTER_API_KEY=...
./bin/lac init --yes --profile 32gb --cloud opencode-go,openrouter
./bin/lac models sync 32gb
./bin/lac provider verify opencode-go
./bin/lac provider verify openrouter
./bin/lac runtime start
./bin/lac client open opencode
```

Manual four-step flow (legacy):

```bash
./bin/lac models sync 24gb
./bin/lac profile apply 24gb
./bin/lac runtime start
./bin/lac client open opencode
```

On macOS, `models sync` also attempts to stage the recommended Unsloth MLX repos under `models/mlx/` when `hf` or `huggingface-cli` is installed. The default MLX choices are 27B `UD-MLX-6bit` and 35B-A3B `MLX-8bit`; use lower MLX quants only when unified-memory budget is tight. Set `AI_INCLUDE_MLX=0` to skip MLX staging or `AI_INCLUDE_MLX=1` to force it; non-macOS sync remains GGUF-first by default.

Gemma 4 quick start:

```bash
./bin/lac models sync gemma-24gb
./bin/lac profile apply gemma-24gb
./bin/lac runtime start
./bin/lac client open opencode
```

OpenRouter quick start (cloud-only, no downloads):

```bash
./bin/lac profile apply openrouter
./bin/lac client open opencode
```

OpenCode Go subscription overlay:

```bash
export OPENCODE_GO_API_KEY=...
./bin/lac init --yes --profile 24gb --cloud opencode-go
./bin/lac provider verify opencode-go
./bin/lac client open opencode
```

OpenCode Go cloud-only profile:

```bash
export OPENCODE_GO_API_KEY=...
./bin/lac profile apply opencode-go
./bin/lac provider verify opencode-go
./bin/lac client open opencode
```

Desktop helper on macOS:

```bash
./bin/lac client open opencode --desktop
```

The desktop helper uses the generated `state/clients/opencode/opencode.json`, so it works for local-only, hybrid, and cloud-only profiles. If OpenCode Desktop is already running, quit and relaunch it after changing profiles so the generated config is loaded.

Monitor llama-server logs:

```bash
tail -f state/logs/llama-server.log
```

Troubleshoot runtime startup in the foreground:

```bash
./bin/lac runtime start --foreground
```

Foreground mode keeps `llama-server` attached to the terminal, so model-load errors and server logs are visible immediately. Normal `runtime start` runs in the background and writes to `state/logs/llama-server.log`; `runtime start --show-logs` starts in the background and then follows that log file.

## Quick start (Windows PowerShell)

```powershell
./bin/lac.ps1 init
```

Non-interactive:

```powershell
./bin/lac.ps1 init --yes --profile 24gb --cloud openrouter
./bin/lac.ps1 models sync 24gb
./bin/lac.ps1 runtime start
./bin/lac.ps1 client open opencode
```

Manual flow:

```powershell
./bin/lac.ps1 models sync 24gb
./bin/lac.ps1 profile apply 24gb
./bin/lac.ps1 runtime start
./bin/lac.ps1 client open opencode
```

Gemma 4 quick start:

```powershell
./bin/lac.ps1 models sync gemma-24gb
./bin/lac.ps1 profile apply gemma-24gb
./bin/lac.ps1 runtime start
./bin/lac.ps1 client open opencode
```

OpenRouter quick start (cloud-only, no downloads):

```powershell
./bin/lac.ps1 profile apply openrouter
./bin/lac.ps1 client open opencode
```

Desktop helper:

```powershell
./bin/lac.ps1 client open opencode --desktop
```

Desktop auto-launch is implemented for macOS. On Windows, use the generated config path from `./bin/lac.ps1 profile apply <profile>` with the OpenCode app's normal workspace/config flow.

Monitor logs:

```powershell
Get-Content state/logs/llama-server.log -Wait -Tail 50
```

Troubleshoot runtime startup in the foreground:

```powershell
./bin/lac.ps1 runtime start --foreground
```

Foreground mode keeps `llama-server` attached to the terminal. The compatibility wrapper also supports `./scripts/launch-llama.ps1 -Foreground`.

Compatibility wrappers under `scripts/` still exist, but `./bin/lac` is the supported v2 interface.

## Inspecting the catalog

Discover workflow packs, scenarios, and provider readiness directly from the CLI:

```bash
./bin/lac pack list
./bin/lac pack show coding
./bin/lac scenario list
./bin/lac provider list
./bin/lac provider status
```

All CLI commands accept `--json` for machine-readable output.

## Client paths

### OpenCode
Best-supported local path.

Runtime asset surface:
- `.opencode/agents/*.md`
- `.opencode/skills/*/SKILL.md`

Rendered config and reports:
- `state/clients/opencode/opencode.json`
- `state/clients/opencode/manifest.json`

Maintainer index surface:
- `agents/` (index docs only)
- `skills/` (index docs only)

### Claude Code
Supported through `templates/claude-code/` plus the rendered reference adapter under `state/clients/claude-code/`.

### Codex
Supported as a reference adapter under `state/clients/codex-reference/`. It is not a first-class runtime target in this repo.

## Cloud overlay providers

Local llama.cpp is always the baseline. Cloud providers are an optional overlay — each is gated by its own env var and is inert until you set one.

`opencode.jsonc` includes provider blocks for:
- `openrouter` — free tier, rate-limited (`OPENROUTER_API_KEY`)
- `opencode-go` — flat subscription, curated models including Qwen3.6 Plus (`OPENCODE_GO_API_KEY`)
- `opencode-zen` — pay-per-request beta, broader catalog (`OPENCODE_ZEN_API_KEY`)
- `codex-auth` — reuse ChatGPT subscription via `numman-ali/opencode-openai-codex-auth` (`OPENAI_API_KEY`)
- `anthropic` — Claude 4.x family, API key only (`ANTHROPIC_API_KEY`); Claude.ai subscription does NOT work
- `antigravity`, `z-ai`, `nvidia-nim` — additional hosted options

Use local models for private, repeated, or offline work. Use OpenCode Go for reliable subscription capacity, and OpenRouter for free/trial fallback or broad hosted-model experiments. `lac init` walks you through picking local and hosted model layers together.

OpenRouter profile default model naming is pinned to:
- `qwen/qwen3-coder:480b-free`

Authentication expectations are documented in `docs/providers/AUTHENTICATION.md`.
Freshness metadata for provider guidance lives in `catalog/providers.json`.

Current product direction:
- Qwen 3.6 is the target default local family.
- Prefer Qwen 3.6 35B-A3B at `UD-Q8_K_XL` where hardware allows; use dense 27B as the lower-footprint quantized default.
- Gemma 4 remains the strongest multilingual alternative, especially for EU-language-heavy workflows.

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
- `docs/use-cases/SCENARIO_GUIDE.md`
- `docs/use-cases/ONBOARDING_16GB_24GB.md`
- `docs/use-cases/ONBOARDING_32GB_PLUS.md`
- `docs/use-cases/ONBOARDING_CLAUDE_CODE.md`

## Free model snapshot policy

`docs/FREE_CLOUD_MODELS.md` and `docs/free-coding-models.json` stay tracked during beta as a reviewed snapshot of community-maintained free-model availability. Refresh them before each beta cut.

Kudos to **@vava-nessa** for the free model index and NIM helper tooling:
https://github.com/vava-nessa/free-coding-models

## Related projects

These external projects are not part of this repo but may be useful depending on your workflow:

- **[get-shit-done](https://github.com/gsd-build/get-shit-done)** — structured Discuss → Plan → Execute → Verify → Ship workflow with context engineering. This repo includes a lightweight adaptation at `.opencode/skills/gsd/SKILL.md`.
- **[oh-my-opencode-slim](https://github.com/alvinunreal/oh-my-opencode-slim)** — multi-agent orchestration suite with model mixing, auto-delegation, and curated AI workflows. Useful if you want heavier orchestration than this repo provides. Note: requires separate API billing (OpenAI Plus ≠ API credits).

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
- `docs/release/README.md`
- `state/README.md`

## Naming policy

Branding and docs use `local-ai-cluster`. Repository slug and filesystem paths may still use `ai-coding-cluster` during transition. This is expected while pre-release alignment is in progress.
