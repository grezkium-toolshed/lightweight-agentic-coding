# lac — private, on-device AI for your work machine

[![CI](https://github.com/TuukkaTanner/lightweight-agentic-coding/actions/workflows/ci.yml/badge.svg)](https://github.com/TuukkaTanner/lightweight-agentic-coding/actions/workflows/ci.yml)

**When your company won't let you put work into ChatGPT or Copilot, `lac` sets up a private AI assistant that runs entirely on your own machine — one command, and nothing leaves the device.** Useful for proofreading, drafting, editing documents, and small local automations, plus coding if that's your thing.

It's best on Apple Silicon Macs (fast, and they usually keep local admin); it runs on ordinary Windows/Linux work laptops too — slower, but private.

Built on [llama.cpp](https://github.com/ggml-org/llama.cpp), [Unsloth](https://unsloth.ai) model quantizations, [OpenCode](https://opencode.ai), and [OpenChamber](https://github.com/openchamber/openchamber). Optional [oMLX](https://github.com/danielzgtg/omlx) on Apple Silicon.

> `lac` stands for "lightweight agentic coding" — it began as a local coding setup and still does that well. The engine is the same; this page just leads with the everyday-work use.

## Get started (one command)

On a Mac, this installs everything you need (Homebrew, llama.cpp, OpenCode, OpenChamber, a small model) and opens a private chat window — nothing leaves your machine:

```bash
git clone https://github.com/TuukkaTanner/lightweight-agentic-coding.git
cd lightweight-agentic-coding
./scripts/bootstrap.sh
```

It's idempotent — re-running skips anything already installed. When it finishes, the [OpenChamber](https://github.com/openchamber/openchamber) chat UI opens at `http://localhost:3000`, backed by a small local model. That's your private assistant.

> A hosted `curl … | bash` one-liner will come with the first tagged release. Windows: `./scripts/bootstrap.ps1` (secondary — WSL is smoother). `lac doctor` tells you what, if anything, is missing.

<details>
<summary>Prefer to set it up by hand? (click to expand)</summary>

Install [llama.cpp](https://github.com/ggml-org/llama.cpp), [OpenCode](https://opencode.ai), and [OpenChamber](https://github.com/openchamber/openchamber) yourself (see their docs), make sure Python 3.10+ is present, then:

```bash
python3 -m pip install .          # installs the `lac` command
lac init                          # detects your RAM, recommends a profile
lac models sync                   # downloads weights for the active profile
lac runtime start                 # starts the local server (llama-server on :8080)
lac client open openchamber       # opens the chat UI  (or: lac client open opencode)
```

`lac demo --local` is the quick path: it downloads a tiny 2.5 GB model and opens the chat UI in one step.
</details>

## What you get

A local AI assistant running on **your** machine:

- **Private by default** — the model runs on `localhost`; your documents and prompts never leave the device unless you deliberately add a cloud provider.
- **A chat window** (OpenChamber) for everyday work — proofreading, drafting, rewriting, summarizing, small edits — plus an agentic coding CLI (OpenCode) if you want it.
- **Matched to your hardware** — `lac init` detects your RAM and picks a model that fits, from a tiny 4B on a 16 GB laptop up to larger models on a 128 GB MacBook Pro.

## Will this run on my work laptop?

Probably — but speed depends heavily on your hardware. Local models use whatever memory and compute you have; Apple Silicon's unified memory is the sweet spot, and a CPU-only laptop works but is slower.

| Your machine | Model it runs well | What it feels like | Best for |
|---|---|---|---|
| 16 GB Windows/Linux laptop (CPU/iGPU) | 4B (`micro`) | A few tokens/sec — usable, not snappy | Short single-shot tasks: proofread a paragraph, rewrite an email |
| 16 GB Apple Silicon Mac | 4–12B (`macos-16gb`) | Comfortably interactive | Everyday drafting, editing, summarizing |
| 24–32 GB Mac / workstation | up to ~27B (`24gb`, `32gb`) | Fast, strong quality | The sweet spot — daily driver |
| 64–128 GB MacBook Pro (M-series Max) | large MoE models | Near-frontier local quality | Heavier agentic work, big context |

Rule of thumb: **single-shot help (proofreading, drafting) works on almost anything; multi-step _agentic_ automation wants Apple Silicon or a real GPU** — each step is another model call, and CPU latency adds up fast.

## What your IT needs to allow

lac keeps everything local, but it does install and run software. If you need to clear it with IT, here's the honest list — forward this:

- **Installing a few developer tools**: a local model runtime (llama.cpp), the OpenCode/OpenChamber clients, and Python 3.10+. On managed Macs, users usually have the local admin this needs.
- **Running a local server on `localhost`** — a model server on port 8080 and the chat UI on port 3000. Nothing listens on the public network by default.
- **Downloading model weights once** from Hugging Face (a few GB). After that it works fully offline.
- **No cloud egress of your data.** Prompts and documents stay on the device; lac reaches the internet only to download models/tools — and only talks to a cloud AI provider if you explicitly configure one.

## Which profile / model?

`lac init` picks one of these based on detected RAM; you can also choose explicitly.

| Machine | Profile | What you get |
|---|---|---|
| Any machine, instant demo | `micro` | Tiny 4B model (~2.5 GB), runs on CPU, instant chat |
| 16 GB Apple Silicon Mac | `macos-16gb` | Balanced Apple Silicon default |
| 16 GB Windows/Linux laptop | `16gb` | 27B starter (tight — expect slower CPU speeds) |
| 24 GB Mac / workstation | `24gb` | The sweet spot — recommended daily driver |
| 32 GB workstation | `32gb` | Stronger, with MTP speculative decoding |
| Cloud-only, free | `openrouter` | Zero downloads, free-tier hosted models |

<details>
<summary>Advanced: big-memory & power-user profiles</summary>

For 64 GB+ machines, the Gemma family, and specialist runtimes. These are power-user options — the mid-tier above is the daily driver for most people.

| Profile | What you get |
|---|---|
| `64gb` | Qwen 3.6 35B-A3B Q8 + MTP |
| `128gb-multi` | Multi-model Qwen workstation (llama.cpp) |
| `128gb-qwen122b` | Large-model Qwen-focused (llama.cpp) |
| `128gb-minimax` | MiniMax M2.7 (IQ4_XS) |
| `128gb-ds4-flash` | DeepSeek V4 Flash via [antirez's ds4/DwarfStar](https://github.com/antirez/ds4). Needs a separately-built `ds4-server` (`git clone https://github.com/antirez/ds4 && make`; set `DS4_BIN`). The ceiling of what a top-spec 128 GB MacBook Pro runs locally; the CUDA build (`make cuda-generic`) is community-validated. |
| `gemma-16gb` … `gemma-64gb` | Gemma 4 family, various sizes |
| `opencode-go` | Cloud-only, OpenCode Go subscription |

</details>

## Platform support

**macOS (Apple Silicon) is the primary, tested platform** — best performance (unified memory + Metal) and the fewest install hurdles. Linux is CI-checked for config, schema, and packaging (not GPU runtime). Windows is best-effort: PowerShell wrappers are provided and kept in parity, but there's no Windows CI yet, and WSL2 is the smoothest Windows path. `lac doctor` reports what your platform is missing.

## Daily use

```bash
lac runtime start                  # Start local server
lac client open openchamber        # Open the chat UI (http://localhost:3000)
lac client open opencode           # Or the coding agent CLI
lac runtime status                 # Check runtime state
lac runtime stop                   # Stop local server
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
See [`SUPPORT.md`](SUPPORT.md) for issue routing and best-effort community support expectations.
