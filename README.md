# local-ai-cluster

`local-ai-cluster` is a private, replicable local-first AI workstation setup. It helps a technical user turn a laptop, desktop, or small team machine into an OpenCode-ready agentic environment with:

- local models through `llama.cpp` `llama-server`
- optional oMLX/MLX model staging on macOS
- optional hosted model overlays such as OpenCode Go and OpenRouter
- curated OpenCode agents and skills for coding, docs, research, spreadsheets, slides, and PDFs
- one supported setup/control command: `./bin/lac`

This repository is still being prepared for public beta. Keep it private until `RELEASE_CHECKLIST.md` and `docs/release/PRIVATE_UNTIL_RELEASE.md` are complete.

## Deployment Path

Most users should follow this path:

1. Pick a profile from the table below.
2. Install prerequisites.
3. Run `./bin/lac init`.
4. Download local model weights if your profile needs them.
5. Start the runtime.
6. Open OpenCode.
7. Run `doctor` and `smoke` checks.

The main command is:

```bash
./bin/lac init
```

`lac init` detects hardware, recommends a profile, lets you choose cloud overlays, renders runtime config, and prints the exact next commands. Its final summary is the source of truth: it reports `ready`, `blocked`, and `optional` checks, generated file paths, missing API keys, and the next command to run.

Use JSON when scripting:

```bash
./bin/lac init --yes --profile 24gb --cloud openrouter --json
```

## Which Profile Should I Use?

| Machine or use case | Recommended profile | Why |
|---|---|---|
| MacBook Air M4 16GB | `macos-16gb` | Headroom-first Apple Silicon setup with Qwen3.5 9B Q4 and Gemma 4 E4B Q8. |
| 16GB non-Mac, or larger local experiment | `16gb` | Qwen 3.6 27B Q3 starter profile. Heavier than `macos-16gb`. |
| 24GB laptop or workstation | `24gb` | Balanced Qwen 3.6 27B Q4 profile. |
| 32GB workstation | `32gb` | Stronger local coding profile with optional coder specialist. |
| Mac Studio M2 Max 64GB or similar | `64gb` | Main high-headroom local Qwen profile. |
| Gemma-focused 16/24/32/64GB machine | `gemma-16gb`, `gemma-24gb`, `gemma-32gb`, `gemma-64gb` | Use when Gemma licensing, multilingual behavior, or Gemma reasoning is preferred. |
| No local runtime, subscription path | `opencode-go` | Cloud-only OpenCode Go setup. |
| No local runtime, free/trial path | `openrouter` | Cloud-only OpenRouter setup. |
| 128GB multi-model workstation | `128gb-multi` | Broad local model coverage. |
| 128GB Qwen large-model workstation | `128gb-qwen122b` | Focused Qwen 122B path. |
| 128GB MiniMax workstation | `128gb-minimax` | Practical MiniMax M2.7 local profile. |

## Hardware profiles

- `16gb`: Qwen 3.6 27B `UD-Q3_K_XL` starter + embeddings
- `macos-16gb`: Apple Silicon 16GB headroom profile with Qwen3.5 9B Q4 + Gemma 4 E4B Q8 + embeddings
- `24gb`: Qwen 3.6 27B `UD-Q4_K_XL` + `UD-Q3_K_XL` fallback + embeddings
- `32gb`: Qwen 3.6 27B `UD-Q4_K_XL` + optional coder specialist
- `64gb`: Qwen 3.6 35B-A3B `UD-Q8_K_XL` + 27B fallback + coder specialist + embeddings
- `128gb-multi`: multi-model Qwen workstation with Qwen 3.6 35B-A3B Q8, Qwen 3.6 27B Q4/Q3 fallbacks, Qwen3 Coder Next, and embeddings
- `128gb-qwen122b`: large-model Qwen-focused profile
- `128gb-minimax`: MiniMax M2.7 `UD-IQ4_XS` profile for a practical 128GB fit
- `gemma-16gb`: Gemma 4 26B-A4B (Q4) + E4B (Q8) fallback
- `gemma-24gb`: Gemma 4 31B (Q4) + 26B-A4B (Q4) fallback
- `gemma-32gb`: Gemma 4 31B (Q8) + 26B-A4B (Q4) fallback
- `gemma-64gb`: Gemma 4 31B (BF16) + 31B (Q8) + 26B-A4B (Q4)
- `openrouter`: Cloud-only, zero downloads; uses OpenRouter via `opencode.jsonc`
- `opencode-go`: Cloud-only, zero downloads; uses OpenCode Go subscription models via `opencode.jsonc`

The 128GB tiers follow a practical `<=115GB` effective memory posture to preserve operating-system and context headroom.

## Preset Settings

Profiles are not just model names. Each local profile also has a llama.cpp preset with baseline runtime and sampling settings:

- `runtime-config/presets/<profile>.ini` is the source template for that profile.
- `state/runtime/presets.active.ini` is the rendered active preset after `./bin/lac init` or `./bin/lac profile apply <profile>`.
- The preset controls `ctx-size`, `fit-ctx`, `temp`, `top-p`, `top-k`, `min-p`, penalties, batch sizes, cache types, GPU layer offload, and chat template selection.

These defaults are based on Unsloth model guidance for Qwen and Gemma, then adjusted conservatively for local OpenCode use, operating-system headroom, and long-context stability. They are meant to be good starting points, not hidden magic. If a model is too slow or memory pressure is high, inspect the active preset first and reduce `ctx-size`, `fit-ctx`, batch size, or the selected profile.

For the deeper rationale and the current table of shipped settings, see `MODEL_RECOMMENDATIONS.md`.

## Prerequisites

`lac init` and `lac doctor` check prerequisites and print install notes for anything missing. They do not install system tools automatically. `lac models sync <profile>` downloads model weights after the runtime tools are installed.

Required for local profiles:

- Python 3
- `llama-server` from llama.cpp
- OpenCode CLI or OpenCode Desktop
- enough disk space for selected model weights

Recommended:

- `hf` or `huggingface-cli` for Hugging Face model downloads
- Git
- curl

Install commands and notes:

| Prerequisite | macOS | Linux | Windows |
|---|---|---|---|
| Python 3 | `brew install python` | `sudo apt install python3` | `winget install Python.Python.3.12` |
| OpenCode CLI | `curl -fsSL https://opencode.ai/install \| bash` or `npm install -g opencode-ai` | `curl -fsSL https://opencode.ai/install \| bash` or `npm install -g opencode-ai` | `npm install -g opencode-ai` |
| llama.cpp `llama-server` | `brew install llama.cpp` | Build llama.cpp from source and add `llama-server` to `PATH`. | Download a llama.cpp release and add the folder containing `llama-server.exe` to `PATH`. |
| Hugging Face CLI | `python3 -m pip install --user 'huggingface_hub[cli]'` | `python3 -m pip install --user 'huggingface_hub[cli]'` | `py -3 -m pip install --user "huggingface_hub[cli]"` |
| oMLX, optional macOS MLX serving | `brew tap jundot/omlx https://github.com/jundot/omlx` then `brew install omlx` | Not supported; use llama.cpp. | Not supported; use llama.cpp. |

Linux llama.cpp source build reference:

```bash
git clone https://github.com/ggml-org/llama.cpp
cmake -B llama.cpp/build -S llama.cpp -DLLAMA_CURL=ON
cmake --build llama.cpp/build --config Release -j
```

After installing a prerequisite, restart your shell and rerun:

```bash
./bin/lac init --yes --profile <profile>
./bin/lac doctor
```

Optional hosted-provider environment variables:

| Provider | Env var | Typical use |
|---|---|---|
| OpenCode Go | `OPENCODE_GO_API_KEY` | Paid subscription overlay or cloud-only profile. |
| OpenRouter | `OPENROUTER_API_KEY` | Free/trial fallback or cloud-only profile. |
| OpenCode Zen | `OPENCODE_ZEN_API_KEY` | Pay-per-request hosted model catalog. |
| Anthropic | `ANTHROPIC_API_KEY` | Claude API access. Claude.ai subscription does not apply. |
| Codex auth helper | `OPENAI_API_KEY` | Third-party ChatGPT subscription bridge. |
| NVIDIA NIM | `NVIDIA_API_KEY` | NVIDIA hosted endpoints. |
| Antigravity | `ANTIGRAVITY_API_KEY` | Hosted coding fallback. |
| Z.AI | `ZAI_API_KEY` | GLM hosted models. |

## macOS / Linux Setup

Interactive setup:

```bash
./bin/lac init
```

Expected checkpoint:

- `Status` is either `ready` or `blocked`
- `Selected profile` matches the machine you want to configure
- `Generated` lists state and OpenCode config files
- `Required checks` tells you whether Python, OpenCode, runtime tools, and provider keys are ready
- `Next steps` lists the commands to run next

Headroom-first MacBook Air M4 16GB setup:

```bash
./bin/lac init --yes --profile macos-16gb --cloud openrouter
./bin/lac models sync macos-16gb
./bin/lac runtime start
./bin/lac client open opencode
```

Balanced 24GB local setup:

```bash
./bin/lac init --yes --profile 24gb --cloud openrouter
./bin/lac models sync 24gb
./bin/lac runtime start
./bin/lac client open opencode
```

64GB local workstation setup:

```bash
./bin/lac init --yes --profile 64gb --cloud opencode-go,openrouter
./bin/lac models sync 64gb
./bin/lac runtime start
./bin/lac client open opencode
```

After `runtime start`, expected checkpoint:

```text
llama-server ready at http://127.0.0.1:8080
```

If it does not become ready, run foreground mode:

```bash
./bin/lac runtime start --foreground
```

## Windows PowerShell Setup

Interactive setup:

```powershell
./bin/lac.ps1 init
```

Non-interactive 24GB setup:

```powershell
./bin/lac.ps1 init --yes --profile 24gb --cloud openrouter
./bin/lac.ps1 models sync 24gb
./bin/lac.ps1 runtime start
./bin/lac.ps1 client open opencode
```

Cloud-only OpenRouter setup:

```powershell
$env:OPENROUTER_API_KEY = "..."
./bin/lac.ps1 init --yes --profile openrouter --no-cloud
./bin/lac.ps1 provider verify openrouter
./bin/lac.ps1 client open opencode
```

Windows Desktop note: macOS has an OpenCode Desktop auto-launch helper. On Windows, use the generated config path printed by `lac init` or `profile apply` with the OpenCode app's normal workspace/config flow.

## Common Choices

Local-only:

```bash
./bin/lac init --yes --profile 24gb --no-cloud
./bin/lac models sync 24gb
./bin/lac runtime start
./bin/lac client open opencode
```

Local plus OpenCode Go:

```bash
export OPENCODE_GO_API_KEY=...
./bin/lac init --yes --profile 24gb --cloud opencode-go
./bin/lac models sync 24gb
./bin/lac provider verify opencode-go
./bin/lac runtime start
./bin/lac client open opencode
```

Local plus OpenRouter:

```bash
export OPENROUTER_API_KEY=...
./bin/lac init --yes --profile 24gb --cloud openrouter
./bin/lac models sync 24gb
./bin/lac provider verify openrouter
./bin/lac runtime start
./bin/lac client open opencode
```

Cloud-only OpenCode Go:

```bash
export OPENCODE_GO_API_KEY=...
./bin/lac init --yes --profile opencode-go --no-cloud
./bin/lac provider verify opencode-go
./bin/lac client open opencode
```

Cloud-only OpenRouter:

```bash
export OPENROUTER_API_KEY=...
./bin/lac init --yes --profile openrouter --no-cloud
./bin/lac provider verify openrouter
./bin/lac client open opencode
```

macOS 16GB headroom setup:

```bash
./bin/lac init --yes --profile macos-16gb --cloud opencode-go,openrouter
./bin/lac models sync macos-16gb
./bin/lac runtime start
./bin/lac client open opencode
```

## Verify Deployment

Run:

```bash
./bin/lac doctor
```

Expected checkpoint:

- `Doctor: ok`
- active profile is the profile you selected
- source files exist
- generated state exists after `init` or `profile apply`
- command checks show which tools are installed

For local profiles, also run:

```bash
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/v1/models
./bin/lac smoke
```

Expected checkpoint:

- `/health` responds
- `/v1/models` lists local models from the active profile
- `smoke` reports `ok`

For cloud profiles or overlays, verify providers:

```bash
./bin/lac provider status
./bin/lac provider verify openrouter
./bin/lac provider verify opencode-go
```

Expected checkpoint:

- configured providers show their env vars as ready
- unconfigured providers are listed but inert
- `provider verify` returns `ok`, `skipped`, or `error` with a reason

## Daily Use

Start local runtime:

```bash
./bin/lac runtime start
```

Stop local runtime:

```bash
./bin/lac runtime stop
```

Check runtime:

```bash
./bin/lac runtime status
```

Open OpenCode:

```bash
./bin/lac client open opencode
```

Open OpenCode Desktop on macOS:

```bash
./bin/lac client open opencode --desktop
```

List profiles and catalogs:

```bash
./bin/lac profile list
./bin/lac scenario list
./bin/lac pack list
./bin/lac provider list
```

All commands support JSON output:

```bash
./bin/lac doctor --json
./bin/lac provider status --json
```

## Generated Files And Paths

Source config:

- `opencode.jsonc`: source OpenCode config template
- `runtime-config/profiles.json`: profile manifest
- `runtime-config/presets/<profile>.ini`: local runtime preset templates
- `catalog/providers.json`: provider metadata and freshness
- `catalog/workflow-packs.json`: workflow pack metadata

Generated state:

- `state/active/profile.txt`: selected profile marker
- `state/active/profile.json`: selected profile summary
- `state/runtime/presets.active.ini`: rendered llama.cpp preset
- `state/clients/opencode/opencode.json`: rendered OpenCode config
- `state/clients/opencode/manifest.json`: rendered OpenCode asset manifest
- `state/logs/llama-server.log`: llama.cpp logs
- `state/logs/omlx.log`: oMLX logs when oMLX is active
- `state/reports/doctor.json`: doctor report
- `state/reports/smoke.json`: smoke report

Model storage:

- local GGUF models default to `models/`
- macOS MLX artifacts default to `models/mlx/`
- override with `AI_MODELS_DIR=/path/to/models`

Model download behavior:

- `./bin/lac models sync <profile>` prefers `hf` or `huggingface-cli` when installed, because the Hugging Face CLI has the best resume/cache behavior.
- If the Hugging Face CLI is not installed, the Unix script uses resumable `curl` downloads and preserves `.downloading` files when a transfer fails.
- Sync validates completed files against Hugging Face-reported size metadata when available. The older minimum-size checks are only a fallback when remote metadata cannot be read.
- A failed model no longer stops the whole profile immediately. The sync continues through the remaining models, reports failures at the end, and exits non-zero so rerunning the same command can resume or fill gaps.

## OpenCode Assets

OpenCode is the lead supported client path.

Runtime assets:

- `.opencode/agents/*.md`
- `.opencode/skills/*/SKILL.md`

Included workflows:

- coding and refactoring
- documentation generation
- research synthesis
- `.docx`, `.pptx`, `.xlsx`, and `.pdf` workflows
- release and team-rollout review support

Maintainer index directories:

- `agents/`
- `skills/`

Those index directories document the runtime assets but are not the runtime discovery paths.

## MLX And oMLX On macOS

The default runtime is llama.cpp. On macOS, model sync can also stage MLX artifacts when `hf` or `huggingface-cli` is installed.

Control MLX staging:

```bash
AI_INCLUDE_MLX=0 ./bin/lac models sync 64gb
AI_INCLUDE_MLX=1 ./bin/lac models sync 64gb
```

Select oMLX serving:

```bash
AI_LOCAL_RUNTIME=omlx ./bin/lac profile apply 64gb
AI_LOCAL_RUNTIME=omlx ./bin/lac runtime start
```

`AI_LOCAL_RUNTIME=mlx` is accepted as an alias for `omlx`. If a profile contains a model without a supported MLX mapping, the CLI falls back to llama.cpp rather than rendering an invalid oMLX config. This is intentional for `macos-16gb`: Qwen3.5 9B is the default GGUF model, while Gemma E4B MLX 8-bit is staged as the smaller alternate.

oMLX uses:

- default port `8000`
- env override `AI_OMLX_PORT` or `OMLX_PORT`
- log path `state/logs/omlx.log`

## Troubleshooting

`Connection refused`

- Start the local runtime first: `./bin/lac runtime start`
- Check logs: `tail -f state/logs/llama-server.log`
- Use foreground mode: `./bin/lac runtime start --foreground`

`Cannot open file`

- Confirm models were downloaded: `./bin/lac models sync <profile>`
- Confirm `AI_MODELS_DIR` points to the right folder
- Check the rendered preset: `state/runtime/presets.active.ini`

Model sync reports failed downloads

- Re-run the same command: `./bin/lac models sync <profile>`
- Install Hugging Face CLI for more reliable resume/cache handling: `python3 -m pip install --user 'huggingface_hub[cli]'`
- Check for preserved partial files ending in `.downloading` under `models/`
- The sync may still download later models in the profile even if one earlier model fails; use the final summary to see whether anything remains missing

OpenCode does not see the generated config

- Re-run `./bin/lac init` or `./bin/lac profile apply <profile>`
- Use `./bin/lac client open opencode`
- For OpenCode Desktop, quit and relaunch after switching profiles

Cloud provider is skipped

- Set the provider API key env var
- Run `./bin/lac provider status`
- Run `./bin/lac provider verify <provider>`

Model is too slow or memory pressure is high

- On a 16GB Mac, use `macos-16gb`
- Reduce context in the preset
- Use a hosted overlay for large repo-wide tasks
- Avoid loading multiple large local models at once

Config parse error

- Re-render config: `./bin/lac profile apply <profile>`
- Run `./scripts/verify-config-schema.sh`

OpenRouter free model changed or disappeared

- Free model availability changes often
- Inspect current catalog: `./bin/lac provider models openrouter`
- Refresh before a beta cut: `./bin/lac provider verify openrouter --refresh-catalog`

## Reference Commands

Manual local flow:

```bash
./bin/lac models sync 24gb
./bin/lac profile apply 24gb
./bin/lac runtime start
./bin/lac client open opencode
```

Compatibility wrappers still exist under `scripts/`, but `./bin/lac` and `./bin/lac.ps1` are the supported v2 interfaces.

Useful validation:

```bash
./verify-documentation.sh
./verify-coherence.sh
./scripts/verify-config-schema.sh
./scripts/verify-profiles-sync.sh
./scripts/verify-v2-contract.sh
./scripts/verify-opencode-assets.sh
```

## Project Scope

Stable enough for public beta preparation:

- llama.cpp-first runtime
- profile-based setup
- OpenCode local configuration
- project-local OpenCode agents and skills
- cloud fallback pattern
- `lac init` onboarding

Still evolving:

- provider model lists and free-tier availability
- curated agent and skill breadth
- hosted-model guidance outside the main OpenCode path
- Windows CI coverage

## Related Docs

The README should be enough for first deployment. Use these docs when you need deeper context:

- `ARCHITECTURE_OVERVIEW.md`
- `MODEL_RECOMMENDATIONS.md`
- `CONFIG_SUMMARY.md`
- `docs/providers/AUTHENTICATION.md`
- `docs/providers/README.md`
- `docs/use-cases/SCENARIO_GUIDE.md`
- `docs/use-cases/HYBRID_WORKSPACES.md`
- `docs/use-cases/ONBOARDING_16GB_24GB.md`
- `docs/use-cases/ONBOARDING_32GB_PLUS.md`
- `docs/security/TRUST_MODEL.md`
- `docs/security/THIRD_PARTY_AGENT_INTAKE.md`
- `docs/release/BETA_RELEASE_CRITERIA.md`
- `docs/release/PRIVATE_UNTIL_RELEASE.md`
- `state/README.md`

## Free Model Snapshot Policy

`docs/FREE_CLOUD_MODELS.md` and `docs/free-coding-models.json` stay tracked during beta as a reviewed snapshot of community-maintained free-model availability. Refresh them before each beta cut.

Kudos to **@vava-nessa** for the free model index and NIM helper tooling:
https://github.com/vava-nessa/free-coding-models

## Related Projects

These external projects are not part of this repo but may be useful depending on your workflow:

- [get-shit-done](https://github.com/gsd-build/get-shit-done): structured Discuss -> Plan -> Execute -> Verify -> Ship workflow with context engineering. This repo includes a lightweight adaptation at `.opencode/skills/gsd/SKILL.md`.
- [oh-my-opencode-slim](https://github.com/alvinunreal/oh-my-opencode-slim): multi-agent orchestration suite with model mixing, auto-delegation, and curated AI workflows. Useful if you want heavier orchestration than this repo provides. Separate API billing is required.

## Naming Policy

Branding and docs use `local-ai-cluster`. Repository slug and filesystem paths may still use `ai-coding-cluster` during transition. This is expected while pre-release alignment is in progress.
