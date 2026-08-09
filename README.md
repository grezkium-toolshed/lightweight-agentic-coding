# lac — private, on-device AI for your work machine

[![CI](https://github.com/grezkium-toolshed/lightweight-agentic-coding/actions/workflows/ci.yml/badge.svg)](https://github.com/grezkium-toolshed/lightweight-agentic-coding/actions/workflows/ci.yml)

**When your company won't let you put work into ChatGPT or Copilot, `lac` sets up a private AI assistant that runs entirely on your own machine — one command, and nothing leaves the device.** Useful for proofreading, drafting, editing documents, and small local automations, plus coding if that's your thing.

**Supported platform: Apple Silicon MacBooks.** Windows, Linux, Intel Macs, ordinary iGPUs,
Snapdragon/Adreno, and other unverified hardware are experimental and **test at your own risk**.
CI and parser coverage on those platforms is not a physical-runtime support guarantee.

Built on [llama.cpp](https://github.com/ggml-org/llama.cpp), [Unsloth](https://unsloth.ai) model quantizations, [OpenCode](https://opencode.ai), and [OpenChamber](https://github.com/openchamber/openchamber). Optional [oMLX](https://github.com/danielzgtg/omlx) on Apple Silicon.

> `lac` stands for "lightweight agentic coding" — it began as a local coding setup and still does that well. The engine is the same; this page just leads with the everyday-work use.

## Get started (one command)

On a Mac, this installs everything you need (Homebrew, Python, Node.js, pnpm, llama.cpp, OpenCode, OpenChamber, and a small model) and opens a private chat window. If OpenChamber cannot be installed, the same flow falls back to OpenCode:

```bash
git clone https://github.com/grezkium-toolshed/lightweight-agentic-coding.git
cd lightweight-agentic-coding
./scripts/bootstrap.sh
```

It's idempotent — re-running skips anything already installed. When it finishes, the [OpenChamber](https://github.com/openchamber/openchamber) chat UI opens at `http://localhost:3000`, backed by a small local model. That's your private assistant.

A hosted one-liner (same flow, no clone needed):

```bash
curl -fsSL https://raw.githubusercontent.com/grezkium-toolshed/lightweight-agentic-coding/v0.3.0/scripts/bootstrap.sh | bash
```

Windows: `./scripts/bootstrap.ps1` is an experimental path; test it at your own risk. `lac doctor` tells you what, if anything, is missing.

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
- **Matched to your hardware** — `lac init` recommends the strongest validated model that fits the effective accelerator-memory budget with headroom for the OS, runtime, context, and KV cache.

## Will this run on my work laptop?

Probably — but speed depends heavily on the accelerator and its usable memory. `lac init` treats dedicated VRAM, ordinary iGPU budgets, Apple unified memory, and Snapdragon shared memory separately. A 16 GB Windows/Linux laptop whose iGPU can use only 4–6 GB belongs in the 4–6 GB rows, not the 16 GB row. If an iGPU is visible but its budget is not measurable, lac conservatively selects `4gb` and reports low confidence. CPU-only machines may use system RAM.

| Memory target | Typical hardware / memory type | Default profile and model weights | Validation | Realistic workload |
|---:|---|---|---|---|
| 4 GB | 16 GB Windows/Linux laptop with an unmeasured or ~4 GB iGPU budget | `4gb`: Qwen3.5 4B Q4, ~2.6 GB | standard | Chat, proofreading, single-shot edits |
| 6 GB | 16 GB Windows/Linux laptop with a measured ~6 GB iGPU budget | `6gb`: Qwen3.5 9B Q4, ~5.5 GB | standard | Short agentic tasks, drafting, summaries |
| 8 GB | True 8 GB accelerator budget | `8gb`: Qwen3.5 9B Q4, ~5.5 GB | standard | Small-model tool use and short sessions |
| 12 GB | True 12 GB accelerator budget | `12gb`: Qwen3.5 9B Q8, ~9.7 GB | standard | Longer agentic sessions |
| 16 GB | Apple Silicon unified memory | `macos-16gb`: Gemma 4 12B QAT, ~6.4 GB | standard | Everyday work with macOS headroom |
| 16 GB | Dedicated VRAM or CPU-only system RAM | `16gb`: Qwen 3.6 27B IQ3, ~12.2 GB | verified | Constrained larger-model work |
| 24 GB | Dedicated VRAM or unified memory | `24gb`: Qwen 3.6 27B Q4, ~17 GB | verified | General daily driver |
| 32 GB | Dedicated VRAM or unified memory | `32gb`: Qwen 3.6 27B Q4, ~17 GB | standard | Coding, research, and multi-step work |
| 48 GB | Dedicated or Apple unified memory | `48gb`: Qwen 3.6 35B-A3B Q8, ~36 GB | standard, manual only | Candidate local-heavy tier; hardware gate pending |
| 64 GB | Dedicated VRAM or unified memory | `64gb`: Qwen 3.6 35B-A3B Q8, ~36 GB | extended | High-headroom and MTP specialist work |
| 128 GB+ | High-memory unified workstation | `128gb-*`: 36–108 GB defaults | extended | Specialist large-model workflows |

The validation column describes the profile evidence, not platform support. Apple Silicon
MacBooks are the supported platform; every other platform remains experimental until physical
runtime evidence justifies promotion.

The 48 GB tier corresponds to current [MacBook Pro configurations](https://support.apple.com/en-euro/126319), but availability alone is not validation; lac keeps it manual until the recorded smoke-test contract passes.

The target is a safe fit, not maximum memory consumption. For multiple discrete GPUs lac uses the largest single reported budget; multi-GPU selection remains manual. Windows' authoritative target is the OS-provided [DXGI video-memory budget](https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_4/ns-dxgi1_4-dxgi_query_video_memory_info); until that budget is exposed by an available runtime probe, shared GPUs stay conservative. Qualcomm/Adreno is detected separately and reported as experimental acceleration; llama.cpp documents [OpenCL support for Windows 11 ARM64](https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/OPENCL.md), but lac does not promise an NPU path.

## Which profile / model?

`lac init` uses the effective accelerator budget above; you can also choose explicitly. `lac profile list --json` exposes each profile's nominal target, recommendation floor, estimated default weight, automatic-recommendation eligibility, and validation tier.

| Machine | Profile | What you get |
|---|---|---|
| Any machine, lightweight demo | `micro` | Tiny 4B model (~2.5 GB), automatic GPU offload with CPU fallback |
| 4 GB device | `4gb` | Qwen3.5-4B Q4 — chat + light automation |
| 6 GB device | `6gb` | Qwen3.5-9B Q4 with partial offload — smallest practical agentic tier |
| 8 GB device | `8gb` | Qwen3.5-9B Q4/Q6 or Gemma 4 12B QAT (`gemma-8gb`) — the agentic floor |
| 12 GB device | `12gb` | Qwen3.5-9B Q8, 64K context |
| 16 GB dedicated VRAM or CPU-only RAM | `16gb` | Qwen 3.6 27B UD-IQ3_XXS (12.2 GB) |
| 16 GB Apple Silicon Mac | `macos-16gb` | Balanced Apple Silicon default (Gemma 4 12B QAT) |
| 24 GB Mac / workstation | `24gb` | The sweet spot — recommended daily driver |
| 32 GB workstation | `32gb` | Stronger, with MTP speculative decoding |
| 48 GB workstation | `48gb` | 35B-A3B Q8 candidate; explicit selection only pending hardware validation |
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

**Apple Silicon MacBooks are the tested and supported product platform.** Support is
best-effort with no SLA. The 128 GB ds4/DwarfStar path has measured M4 Max MacBook Pro evidence;
the 48 GB profile remains a manual candidate until it passes its own exact-hardware contract.

Windows, Linux, Intel Macs, ordinary iGPUs, Snapdragon/Adreno, and other unverified hardware are
experimental and test-at-your-own-risk. Linux/macOS CI exercises offline contracts and the CLI;
Windows CI exercises parsing, wrappers, and client rendering. Those checks do not validate GPU
drivers, model loading, performance, or deployment on physical hardware. The from-zero bootstrap
and OpenChamber flow on a genuinely clean Apple Silicon MacBook environment remains a release gate.
`lac doctor` reports what your platform is missing.

Installed copies keep mutable data outside the Python package: models and refreshed catalogs use the platform user-data directory, while runtime state uses the platform user-state directory. Override them with `LAC_DATA_ROOT`, `LAC_STATE_ROOT`, or `AI_MODELS_DIR`.

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
- **Product roadmap** — hardware-fit milestones, audience, and explicit non-goals: [`ROADMAP.md`](ROADMAP.md)
- **Advanced profiles** — MTP speculative decoding, oMLX on macOS, hybrid local+cloud: [`docs/architecture.md`](docs/architecture.md)
- **Bundled agents & skills** — architecture/release review, documentation, research synthesis, and office workflows (docx/pptx/xlsx/pdf): [`.opencode/agents/`](.opencode/agents/), [`.opencode/skills/`](.opencode/skills/)
- **Design skills & brand systems (opt-in)** — lac does not bundle these; add the [Open Design](https://open-design.ai) catalog yourself: `curl -fsSL https://open-design.ai/install.sh | sh -s opencode`
- **Ponytail (default-on)** — generated OpenCode configs include the [ponytail](https://github.com/DietrichGebert/ponytail) plugin (laziness ruleset + `/ponytail` commands). Disable per session with `PONYTAIL_DEFAULT_MODE=off`. See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)
- **Qwen 3.8 candidate prep** — placeholder config slots exist, but no profile switches without official artifacts and hardware evidence: [`docs/models/QWEN38_READY.md`](docs/models/QWEN38_READY.md)
- **Free cloud model catalog** — `lac catalog sync-free`, see [`docs/free-coding-models.json`](docs/free-coding-models.json)
- **Model deep dive** — tuning rationale, profile details: [`docs/model-recommendations.md`](docs/model-recommendations.md)
- **Agentic analysis of assessment exports** — model capability review, harness assessment, and the agentic-only-folder workflow (staging script + skill implemented): [`docs/assessments/`](docs/assessments/)

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
- **[ponytail](https://github.com/DietrichGebert/ponytail)** by Dietrich Gebert — laziness ruleset pre-wired into generated OpenCode configs
- **[OpenChamber](https://github.com/openchamber/openchamber)** by @btriapitsyn — web/mobile/desktop remote access
- **[free-coding-models](https://github.com/vava-nessa/free-coding-models)** by @vava-nessa — free cloud model index and NIM helper tooling
- **[Qwen](https://github.com/QwenLM/Qwen)** and **[Gemma](https://ai.google.dev/gemma)** model families

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for bundled asset
attribution and runtime/model source notes.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for setup, coding style, and submission guidelines.
See [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) for community expectations.
See [`SUPPORT.md`](SUPPORT.md) for issue routing and best-effort community support expectations.
