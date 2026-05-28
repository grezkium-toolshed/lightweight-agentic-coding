# local-ai-cluster

A private, replicable local-first AI workstation. Turns a laptop or desktop into an OpenCode-ready agentic environment with local models (llama.cpp, optional oMLX), cloud fallbacks, and curated agents and skills for coding, docs, research, and office automation.

> This repo is preparing for public beta. Keep it private until `RELEASE_CHECKLIST.md` and `docs/release/PRIVATE_UNTIL_RELEASE.md` are complete.

## Installation

Requires Python 3.10+. Installs the `lac` CLI tool and bundles all agents, skills, catalogs, and presets.

```bash
# Clone the repository
git clone https://github.com/<user>/ai-coding-cluster

# Install the local-ai-cluster package
python3 -m pip install --upgrade ./ai-coding-cluster
```

For development (editable mode — changes to source reflect immediately without reinstalling):

```bash
python3 -m pip install --upgrade -e ./ai-coding-cluster
```

After install, `lac` is on your PATH and works from any directory.

## Quick Start

```bash
# 1. Choose a profile (interactive, or use --yes --profile <name>)
lac init

# 2. Download model weights for your profile
lac models sync <profile>

# 3. Start the runtime and open your client
lac runtime start
lac client open opencode         # OpenCode CLI (terminal)
lac client open openchamber      # OpenChamber web UI (browser/phone)
lac client open openchamber --desktop  # OpenChamber macOS desktop app
```

`lac init` detects hardware, recommends a profile, renders config, and prints next steps. Its final summary is the source of truth for what is ready, blocked, and optional.

OpenChamber is a web/PWA/desktop GUI for OpenCode that gives you phone and tablet access — see [`docs/providers/OPENCHAMBER.md`](docs/providers/OPENCHAMBER.md) for remote access via Tailscale or Cloudflare tunnel.

## Which Profile?

| Machine | Profile | Notes |
|---|---|---|
| MacBook Air M4 16GB | `macos-16gb` | Headroom-first Apple Silicon |
| 16GB non-Mac | `16gb` | Qwen 3.6 27B Q3 starter |
| 24GB laptop/workstation | `24gb` | Balanced Qwen 3.6 27B Q4 |
| 32GB workstation | `32gb` | Stronger local coding profile |
| 64GB workstation | `64gb` | High-headroom Qwen 3.6 35B-A3B Q8 |
| 128GB multi-model | `128gb-multi` | Broad model coverage |
| Cloud-only, free | `openrouter` | Zero downloads |
| Cloud-only, subscription | `opencode-go` | Zero downloads |

See `MODEL_RECOMMENDATIONS.md` for preset rationale and verification tiers.

<details>
<summary>Full profile list</summary>

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
- `openrouter`: Cloud-only, zero downloads; uses OpenRouter via `opencode.template.jsonc`
- `opencode-go`: Cloud-only, zero downloads; uses OpenCode Go subscription models via `opencode.template.jsonc`

</details>

## Prerequisites

Required: Python 3, `llama-server` (from llama.cpp), OpenCode CLI, Git, curl.

| Tool | macOS | Linux | Windows |
|---|---|---|---|
| Python 3 | `brew install python` | `sudo apt install python3` | `winget install Python.Python.3.12` |
| OpenCode CLI | `curl -fsSL https://opencode.ai/install \| bash` | same | `npm install -g opencode-ai` |
| llama-server | `brew install llama.cpp` | build from source | download release, add to `PATH` |
| Hugging Face CLI | `python3 -m pip install --user 'huggingface_hub[cli]'` | same | `py -3 -m pip install --user "huggingface_hub[cli]"` |
| OpenChamber (optional) | `curl -fsSL https://raw.githubusercontent.com/openchamber/openchamber/main/scripts/install.sh \| bash` | same | same |

Optional cloud provider keys: `OPENCODE_GO_API_KEY`, `OPENROUTER_API_KEY`, `ANTHROPIC_API_KEY`, etc. See `docs/providers/AUTHENTICATION.md`.

## Setup Examples

macOS / Linux (24GB local + OpenRouter fallback):

```bash
lac init --yes --profile 24gb --cloud openrouter
lac models sync 24gb
lac runtime start
lac client open opencode
```

Windows (after `py -m pip install .`):

```powershell
lac init --yes --profile 24gb --cloud openrouter
lac models sync 24gb
lac runtime start
lac client open opencode
```

Cloud-only (no local runtime):

```bash
export OPENROUTER_API_KEY=...
lac init --yes --profile openrouter --no-cloud
lac client open opencode
```

With OpenChamber remote access:

```bash
lac profile apply 64gb
lac runtime start
lac client open openchamber --remote-host http://100.x.x.x:4095
# Phone/tablet: open http://100.x.x.x:3000 in browser
```

See [`docs/providers/OPENCHAMBER.md`](docs/providers/OPENCHAMBER.md) for Tailscale and Cloudflare tunnel setup.

## Verify

```bash
lac doctor
lac smoke
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/v1/models
```

Expected: `doctor` and `smoke` report `ok`, `/health` responds, `/v1/models` lists active models.

## Daily Use

```bash
lac runtime start                  # Start local server
lac runtime stop                   # Stop local server
lac runtime status                 # Check runtime state
lac client open opencode           # Launch OpenCode CLI (terminal)
lac client open openchamber        # Launch OpenChamber web UI (http://localhost:3000)
lac client open openchamber --desktop  # Launch OpenChamber macOS desktop app
lac client open openchamber --remote-host http://100.x.x.x:4095  # Connect via Tailscale
lac doctor                         # Validate setup
```

All commands support `--json` for scripting.

## Device Setup

Apply a profile and configure your device (oMLX context limits, DCP plugin):

```bash
lac setup <profile>
```

This runs `profile apply`, updates `~/.omlx/settings.json` if oMLX is installed, and installs the Dynamic Context Pruning plugin.

## Free Model Catalog

Sync the upstream free-models index:

```bash
lac catalog sync-free
```

Verify free models are still accessible (requires API keys):

```bash
lac provider verify-models
```

All commands support `--json` for scripting.

## Generated Files

Source (tracked):
- `opencode.template.jsonc` — OpenCode config template
- `runtime-config/presets/<profile>.ini` — llama.cpp preset templates
- `runtime-config/profiles.json` — profile manifest

Generated (in `state/`, ignored by git):
- `state/runtime/presets.active.ini` — rendered llama.cpp preset
- `state/clients/opencode/opencode.json` — rendered OpenCode config
- `state/clients/openchamber/` — OpenChamber adapter config (manifest, env)
- `state/active/profile.txt` — selected profile marker
- `state/logs/llama-server.log` — runtime logs
- `state/reports/doctor.json` — doctor report

Override model storage path with `AI_MODELS_DIR=/path/to/models`.

## oMLX on macOS

Use oMLX instead of llama.cpp:

```bash
AI_LOCAL_RUNTIME=omlx ./bin/lac profile apply 64gb
AI_LOCAL_RUNTIME=omlx ./bin/lac runtime start
```

oMLX uses port `8000` by default. Override with `AI_OMLX_PORT`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Connection refused` | Start runtime: `lac runtime start`. Check logs: `tail -f state/logs/llama-server.log` |
| `Cannot open file` | Run `lac models sync <profile>`. Check `AI_MODELS_DIR` and `state/runtime/presets.active.ini` |
| Model sync fails | Re-run the same command. Install Hugging Face CLI for resume support. Check for `.downloading` partial files |
| OpenCode misses config | Re-run `lac init`. For Desktop, quit and relaunch after profile switch |
| Cloud provider skipped | Set the provider env var, then `lac provider verify <provider>` |
| Config parse error | Re-render: `lac profile apply <profile>`. Run `lac doctor --strict` |

## Project Scope

Stable for beta:
- llama.cpp-first runtime with profile-based setup
- OpenCode local configuration, agents, and skills
- Cloud fallback pattern
- `lac init` onboarding

Still evolving:
- Provider model lists and free-tier availability
- Curated agent and skill breadth
- Windows CI coverage

## Reference

- `ARCHITECTURE_OVERVIEW.md` — system design
- `MODEL_RECOMMENDATIONS.md` — model and profile deep dive
- `CONFIG_SUMMARY.md` — configuration details
- `docs/providers/AUTHENTICATION.md` — provider setup
- `docs/providers/OPENCHAMBER.md` — remote access via OpenChamber (Tailscale, Cloudflare tunnel)
- `docs/use-cases/SCENARIO_GUIDE.md` — use-case guidance
- `docs/security/TRUST_MODEL.md` — security model
- `CONTRIBUTING.md` — contribution guidelines
- `CODE_OF_CONDUCT.md` — community expectations

## Acknowledgments

- **OpenChamber** — powers our web, mobile, and desktop remote access. Built by [@btriapitsyn](https://github.com/btriapitsyn) and contributors. https://github.com/openchamber/openchamber
- **@vava-nessa** — for the free model index tooling used in our cloud model snapshots.

## Free Model Snapshot Policy

`docs/FREE_CLOUD_MODELS.md` and `docs/free-coding-models.json` are reviewed snapshots of free-model availability. Refresh them before each beta cut. Kudos to **@vava-nessa** for the free model index tooling.

## Contributing

- See [`CONTRIBUTING.md`](CONTRIBUTING.md) for setup, coding style, and submission guidelines.
- See [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) for community expectations.

## Naming Policy

Branding and docs use `local-ai-cluster`. Repository slug and filesystem paths may still use `ai-coding-cluster` during transition.
