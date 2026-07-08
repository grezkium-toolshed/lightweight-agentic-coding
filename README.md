# lac — Lightweight Agentic Coding

[![CI](https://github.com/TuukkaTanner/lightweight-agentic-coding/actions/workflows/ci.yml/badge.svg)](https://github.com/TuukkaTanner/lightweight-agentic-coding/actions/workflows/ci.yml)

Clone, initialize, and start coding with a local AI model. No cloud required.

Built on [llama.cpp](https://github.com/ggml-org/llama.cpp), [Unsloth](https://unsloth.ai) model quantizations, [OpenCode](https://opencode.ai), and [Open Design](https://open-design.ai). With optional support for [oMLX](https://github.com/danielzgtg/omlx).

## Quick Start

```bash
# 1. Lightweight Agentic Coding
git clone https://github.com/TuukkaTanner/lightweight-agentic-coding.git
cd lightweight-agentic-coding
python3 -m pip install .

# 2. Set up your hardware profile (detects and recommends)
lac init

# 3. Download models and start coding
lac models sync
lac runtime start
lac client open opencode
```

That's it. `lac init` writes the active profile, and `lac models sync` uses that profile by default.

### Just want to try it fast?

```bash
lac demo --local    # download a tiny 2.5 GB model and chat locally
lac demo            # or use the OpenRouter free tier (needs an API key, zero downloads)
```

`lac demo` opens the [OpenChamber](https://github.com/openchamber/openchamber) UI, so install that first; `--local` also needs `llama-server` on your PATH. `lac doctor` tells you what's missing.

<details>
<summary>New to Python or pip? (click to expand)</summary>

Make sure Python 3.10+ is installed:

| OS | Check version | If missing |
|---|---|---|
| macOS | `python3 --version` | `brew install python` |
| Linux | `python3 --version` | `sudo apt install python3 python3-pip` |
| Windows | `py -3 --version` | `winget install Python.Python.3.12` |

Then install lac:

**macOS / Linux:** `python3 -m pip install --user ./lightweight-agentic-coding`

**Windows:** `py -3 -m pip install ./lightweight-agentic-coding`

The `python3 -m pip` form always works — it doesn't depend on `pip` being on your PATH.
</details>

## What just happened?

The three commands above do this:

1. **`lac init`** — detects your hardware (RAM, GPU) and picks the best model profile for your machine. Generates config for OpenCode and llama.cpp.
2. **`lac models sync`** — downloads model weights for the active profile (resumable, shows progress).
3. **`lac runtime start` + `lac client open opencode`** — starts the local AI server (`llama-server` on port 8080) and opens OpenCode connected to it.

You're now running a local AI coding agent on your own machine. No data leaves your computer unless you configure a cloud provider.

## Which Profile?

| Machine | Profile | What you get |
|---|---|---|
| Any machine, demo | `micro` | Tiny CPU-only model (~2.5 GB), instant chat |
| MacBook Air M4 16GB | `macos-16gb` | Balanced Apple Silicon profile |
| 16GB laptop | `16gb` | Qwen 3.6 27B starter |
| 24GB laptop/workstation | `24gb` | The sweet spot — recommended starting point |
| 32GB workstation | `32gb` | Stronger local coding with MTP |
| Cloud-only, free | `openrouter` | Zero downloads, uses free tier models |

<details>
<summary>All profiles (power users, Gemma, cloud-only)</summary>

| Profile | What you get |
|---|---|
| `64gb` | Qwen 3.6 35B-A3B Q8 + MTP |
| `128gb-multi` | Multi-model Qwen workstation |
| `128gb-qwen122b` | Large-model Qwen-focused |
| `128gb-minimax` | MiniMax M2.7 (IQ4_XS) |
| `128gb-ds4-flash` | DeepSeek V4 Flash via ds4/DwarfStar (see below) |
| `gemma-16gb` | Gemma 4 26B-A4B (Q4) |
| `gemma-24gb` | Gemma 4 31B (Q4) + 26B-A4B (Q4) |
| `gemma-32gb` | Gemma 4 31B (Q8) + 26B-A4B (Q4) |
| `gemma-64gb` | Gemma 4 31B (BF16) multi-model |
| `opencode-go` | Cloud-only, OpenCode Go subscription |
</details>

### 128GB machines (Mac Studio, DGX Spark)

The flagship large-memory profile is **`128gb-ds4-flash`** — DeepSeek V4 Flash served through
[antirez's ds4/DwarfStar](https://github.com/antirez/ds4) runtime, aimed at 128GB+ unified-memory
machines. lac invokes `ds4-server` but does not install it; build it first and put it on your PATH:

```bash
git clone https://github.com/antirez/ds4
# Mac Studio / Apple Silicon:
cd ds4 && make
# DGX Spark / CUDA:
cd ds4 && make cuda-generic
export DS4_BIN="$PWD/ds4-server"

lac models sync 128gb-ds4-flash   # ~80 GB download
lac profile apply 128gb-ds4-flash
lac runtime start
```

> **Platform notes.** The Apple Silicon path (Mac Studio / Mac Pro, 128GB+) is the maintainer's
> own target hardware. The DGX Spark / CUDA path is spec'd from published details and welcomes
> community validation — CI can't exercise the external `ds4-server` binary on either. If you run
> one, [hardware profile reports](.github/ISSUE_TEMPLATE/hardware_profile_request.md) are welcome.
> The Qwen-based `128gb-multi` / `128gb-qwen122b` profiles run on the default llama.cpp path and
> don't need ds4.

## Platform support

macOS (Apple Silicon) is the primary tested platform. Linux is exercised by CI for config,
schema, and packaging (not GPU runtime). Windows is best-effort: PowerShell wrappers are provided
and kept in parity, but there is no Windows CI yet. `lac doctor` reports what your platform is
missing.

## Daily use

```bash
lac runtime start                  # Start local server
lac runtime stop                   # Stop local server
lac runtime status                 # Check runtime state
lac client open opencode           # Launch OpenCode CLI
lac client open openchamber        # Launch web UI (http://localhost:3000)
lac doctor                         # Validate setup
```

All commands support `--json` for scripting.

## Next steps

- **Cloud providers** — add OpenRouter, Anthropic API, or OpenCode Go as fallbacks: [`docs/providers/AUTHENTICATION.md`](docs/providers/AUTHENTICATION.md)
- **Advanced profiles** — MTP speculative decoding, oMLX on macOS, hybrid local+cloud: [`docs/architecture.md`](docs/architecture.md)
- **Bundled agents & skills** — architecture/release review, documentation, research synthesis, and office workflows (docx/pptx/xlsx/pdf): [`.opencode/agents/`](.opencode/agents/), [`.opencode/skills/`](.opencode/skills/)
- **Design skills & brand systems (opt-in)** — lac does not bundle these; add the [Open Design](https://open-design.ai) catalog yourself: `curl -fsSL https://open-design.ai/install.sh | sh -s opencode`
- **Free cloud model catalog** — `lac catalog sync-free`, see [`docs/free-coding-models.json`](docs/free-coding-models.json)
- **Model deep dive** — tuning rationale, profile details: [`docs/model-recommendations.md`](docs/model-recommendations.md)

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Connection refused` | Start runtime: `lac runtime start`. Check logs: `tail -f state/logs/llama-server.log` |
| `Cannot open file` | Run `lac models sync <profile>`. Check `AI_MODELS_DIR` and profile config |
| Model sync fails | Re-run the same command. Install Hugging Face CLI for resume support |
| OpenCode misses config | Re-run `lac init`. For Desktop, quit and relaunch after profile switch |
| Cloud provider skipped | Set the provider env var, then `lac provider verify <provider>` |
| Config parse error | Re-render: `lac profile apply <profile>`. Run `lac doctor --strict` |

## Acknowledgments

lac is a thin orchestration layer standing on the shoulders of:

- **[llama.cpp](https://github.com/ggml-org/llama.cpp)** by Georgi Gerganov and contributors — the local inference engine
- **[Unsloth](https://unsloth.ai)** — model quantizations and tuning guidance for Qwen and Gemma families
- **[OpenCode](https://opencode.ai)** — the agentic coding client
- **[Open Design](https://open-design.ai)** by nexu-io — design skills, craft rulebooks, and brand design systems
- **[oMLX](https://github.com/danielzgtg/omlx)** — optional macOS MLX inference backend
- **[ds4/DwarfStar](https://github.com/antirez/ds4)** by Salvatore Sanfilippo — optional 128GB+ Apple Silicon DeepSeek V4 Flash runtime path
- **[OpenChamber](https://github.com/openchamber/openchamber)** by @btriapitsyn — web/mobile/desktop remote access
- **[free-coding-models](https://github.com/vava-nessa/free-coding-models)** by @vava-nessa — free cloud model index and NIM helper tooling
- **[Qwen](https://github.com/QwenLM/Qwen)** and **[Gemma](https://ai.google.dev/gemma)** model families

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for bundled asset
attribution and runtime/model source notes.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for setup, coding style, and submission guidelines.
See [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) for community expectations.
See [`SUPPORT.md`](SUPPORT.md) for issue routing and public-beta support expectations.
