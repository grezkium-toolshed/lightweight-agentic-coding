# Model Recommendations

## Local-first baseline

Use Qwen 3.6 as the default local family for general agentic work.

Default quant guidance:
- prefer Unsloth's published `UD-Q8_K_XL` GGUF artifact for Qwen 3.6 35B-A3B where hardware allows
- use dense Qwen 3.6 27B for lower-footprint quantized defaults; it is less sensitive to quantization than 35B-A3B
- stage Unsloth MLX artifacts on macOS when a Hugging Face CLI is available: 27B `UD-MLX-6bit` and 35B-A3B `MLX-8bit` are the preferred defaults
- use lower-bit MLX variants only for constrained unified-memory budgets
- keep low-bit 35B-A3B dynamic quants as optional footprint-saving alternatives, not the default product recommendation

Recommended profile mapping:
- `16gb`: Qwen 3.6 27B `UD-Q3_K_XL`
- `macos-16gb`: Gemma 4 12B `UD-Q4_K_XL` + Qwen3.5 9B `Q4_K_M` + Gemma 4 E4B `Q8_0` for Apple Silicon
- `24gb`: Qwen 3.6 27B `UD-Q4_K_XL`
- `32gb`: Qwen 3.6 27B `UD-Q4_K_XL` + 27B MTP `UD-Q4_K_XL`
- `64gb`: Qwen 3.6 35B-A3B `UD-Q8_K_XL` + 35B-A3B MTP `UD-Q6_K_XL`
- `128gb-ds4-flash`: DeepSeek V4 Flash q2-q4-imatrix through DwarfStar ds4
- `128gb-multi`: multiple practical local models
- `128gb-qwen122b`: Qwen 122B-focused
- `128gb-minimax`: MiniMax M2.7 `UD-IQ4_XS` alternative

## Preset Settings Rationale

The `.ini` presets are part of the recommendation, not incidental config. They combine Unsloth's published model guidance with repo-specific defaults for OpenCode, local agent workflows, and memory headroom:

- Source templates live in `runtime-config/presets/<profile>.ini`.
- The active runtime file is rendered to `state/runtime/presets.active.ini`.
- The important knobs are `ctx-size`, `fit-ctx`, `temp`, `top-p`, `top-k`, `min-p`, `presence-penalty`, `repeat-penalty`, cache type, batch sizes, and chat template.
- Unsloth model docs: [Qwen3.5](https://unsloth.ai/docs/models/qwen3.5) and [Gemma 4](https://unsloth.ai/docs/models/gemma-4).

### Qwen baseline

Qwen3.5 and Qwen 3.6 are treated as the default local coding/general families. For Qwen3.5 small non-thinking mode, Unsloth's general baseline is `temp=0.7`, `top_p=0.8`, `top_k=20`, `min_p=0.0`, `presence_penalty=1.5`, and repeat penalty disabled or `1.0`. The `macos-16gb` Qwen3.5 9B preset follows that shape directly.

The Qwen 3.6 profiles use the same family guidance but are tuned more conservatively for repeatable coding and agent loops:

- 27B Q3/Q4 profiles use `top-p=0.9`, `top-k=40`, modest presence penalties, and `repeat-penalty=1.05`.
- 35B-A3B Q8 profiles keep a slightly higher `temp/top-p` while preserving repeat control.
- Context is selected by hardware tier; the repo does not blindly max every model's theoretical context.

### Gemma baseline

Gemma 4 profiles keep the Unsloth-style Gemma defaults: `temperature=1.0`, `top_p=0.95`, `top_k=64`, `min_p=0.0`, `presence_penalty=0.0`, and `repeat_penalty=1.0`. The Gemma profiles use the Gemma chat template and treat 32K as the practical starting point on small macOS hardware, with larger contexts reserved for higher-memory profiles.

### Main shipped settings

| Profile / model | Artifact family | Context | temp / top-p / top-k | Penalties | Source / rationale |
|---|---|---:|---|---|---|
| `macos-16gb` / Gemma 4 12B Q4 | `UD-Q4_K_XL` | 256K | `1.0 / 0.95 / 64` | presence `0.0`, repeat `1.0` | Unsloth Gemma defaults; encoder-free text+image+audio default for 16GB Apple Silicon. |
| `macos-16gb` / Qwen3.5 9B Q4 fallback | `Q4_K_M` | 32K | `0.7 / 0.8 / 20` | presence `1.5`, repeat `1.0` | Unsloth Qwen small non-thinking baseline; 32K keeps 16GB macOS headroom. |
| `macos-16gb` / Gemma 4 E4B Q8 fallback | `Q8_0` | 32K | `1.0 / 0.95 / 64` | presence `0.0`, repeat `1.0` | Unsloth Gemma defaults; lightest alternate for multilingual and office work. |
| `16gb` / Qwen 3.6 27B Q3 | `UD-Q3_K_XL` | 64K | `0.6 / 0.9 / 40` | presence `0.2`, repeat `1.05` | Repo coding/agent tuning for constrained non-Mac 16GB experiments. |
| `24gb` / Qwen 3.6 27B Q4 | `UD-Q4_K_XL` | 128K | `0.7 / 0.9 / 40` | presence `0.4`, repeat `1.05` | Balanced Qwen default with stronger repeat control for agent loops. |
| `32gb` / Qwen 3.6 27B Q4 | `UD-Q4_K_XL` | 128K | `0.6 / 0.9 / 40` | presence `0.2`, repeat `1.05` | More conservative coding profile, paired with coder specialist. |
| `64gb` / Qwen 3.6 35B-A3B Q8 | `UD-Q8_K_XL` | 256K | `0.7 / 0.92 / 40` | presence `0.5`, repeat `1.05` | Higher-headroom Qwen default while retaining repeat control. |
| `64gb` / Qwen 3.6 27B Q4 fallback | `UD-Q4_K_XL` | 128K | `0.6 / 0.9 / 40` | presence `0.2`, repeat `1.05` | Stable fallback when the 35B-A3B path is too heavy. |
| `gemma-16gb` / Gemma 4 12B Q8 | `UD-Q8_K_XL` | 256K | `1.0 / 0.95 / 64` | presence `0.0`, repeat `1.0` | Unsloth Gemma defaults; encoder-free text+image+audio default for 16GB VRAM. |
| `gemma-16gb` / Gemma 4 12B Q4 fallback | `UD-Q4_K_XL` | 256K | `1.0 / 0.95 / 64` | presence `0.0`, repeat `1.0` | Lighter 12B slot; same multimodal capability at lower RAM. |
| `gemma-16gb` / Gemma 4 E4B Q8 fallback | `Q8_0` | 128K | `1.0 / 0.95 / 64` | presence `0.0`, repeat `1.0` | Smallest Gemma fallback for lightweight multilingual work. |
| `gemma-24gb+` / Gemma 4 26B/31B | `UD-Q4_K_XL`, `Q8_0`, or `BF16` | 256K | `1.0 / 0.95 / 64` | presence `0.0`, repeat `1.0` | Unsloth Gemma defaults; profile chooses quant/context by hardware tier. |
| `32gb+` / Qwen3.6 27B MTP | `UD-Q4_K_XL` (MTP) | 256K | `0.7 / 0.9 / 40` | presence `0.2`, repeat `1.04` | MTP speculative decoding; 1.4-2.2x faster than baseline. `spec-draft-n-max=6` (tunable 1-6). |
| `64gb+` / Qwen3.6 35B-A3B MTP | `UD-Q6_K_XL` (MTP) | 256K | `0.7 / 0.92 / 40` | presence `0.4`, repeat `1.04` | MTP speculative decoding; fast architect replacement for coder-next. ~1GB extra headroom vs non-MTP. |

## 128GB MiniMax alternative

Use `128gb-minimax` when you specifically want MiniMax M2.7 on a 128 GB machine.

Recommended quant for this repo:
- `UD-IQ4_XS`

Why this one:
- Unsloth lists it at about 108 GB, which fits the repo's 128 GB headroom posture much better than `UD-Q4_K_XL`
- it is the practical compromise when you want stronger quality than very low-bit MiniMax options without exceeding the memory budget

## 128GB ds4 DeepSeek V4 Flash path

Use `128gb-ds4-flash` when you have a 128 GB+ Apple Silicon or comparable unified-memory workstation and want DeepSeek V4 Flash through DwarfStar ds4 instead of the oMLX/MTP path.

Recommended default for this repo:
- DeepSeek V4 Flash `q2-q4-imatrix` 0731 (mixed q2/q4 experts, ~97.6 GB) from `antirez/deepseek-v4-gguf`
- local file: `models/ds4/ds4flash.gguf`
- runtime: `ds4-server` on `http://127.0.0.1:8000/v1`
- context: `100000`
- disk KV cache: `state/runtime/ds4-kv`

Why this path exists:
- ds4 is intentionally narrow and DeepSeek V4-specific, which makes it a better fit for this high-memory niche than treating DeepSeek V4 as another generic GGUF slot
- the mixed q2/q4 Flash quant keeps expert precision while staying in the 128 GB class — measured ~39 t/s decode short-context on M5 Max 128GB (no speculative decoding)
- lac users have seen mixed oMLX/MTP behavior on this class of machine, so ds4 is exposed as a first-class runtime rather than a footnote

Lower-memory fallback:
- the 2-bit Flash quant (`DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf`, ~86.7 GB) remains selectable via `DS4_QUANT=<name>` at `lac models sync` time
- keep `q4-imatrix` and PRO variants out of the default profile; they are 256 GB+ or 512 GB-class paths

## MTP specialist models

Use Qwen 3.6 MTP variants as the fast coding and architect replacement. The 27B MTP (Q4) is the best general-purpose fast model, while the 35B-A3B MTP (Q6) provides stronger reasoning at higher speed than the non-MTP baseline. Both support 256K context and deliver 1.4-2.2x faster inference via speculative decoding (`--spec-type draft-mtp --spec-draft-n-max 6`). MTP requires ~1GB extra RAM/VRAM headroom over the non-MTP equivalent.

Qwen Coder Next was removed from local presets in favor of MTP models, as the newer Qwen 3.6 family has better tool-call reliability and MTP provides sufficient generation speed. Cloud provider entries for coder models remain available as fallbacks.

## When to use free cloud fallbacks

Use free or trial-backed cloud providers when:
- hardware is too small for the desired local model
- onboarding speed matters more than full local execution
- a team wants to try the workflow before investing in hardware

Recommended fallback order:
1. NVIDIA NIM
2. OpenRouter free models
3. OpenCode Go (subscription)
4. Anthropic API

## Office and documentation workloads

For office automation, the model matters less than workflow quality and tool support. Smaller Qwen profiles can still be useful if the repo provides strong skills and clear workflow guidance.

## Apple Silicon 16GB

Use `macos-16gb` for MacBook Air M4 16GB-class machines. It prioritizes OS headroom, context room, and interactive responsiveness over maximum parameter count:
- Qwen3.5 9B `Q4_K_M` is the default local coding/general model.
- Gemma 4 E4B `Q8_0` is the smaller alternate for lighter multilingual and local office work.
- Start at 32K context on 16GB macOS; increase only after validating memory pressure.
- Use OpenCode Go or OpenRouter overlays for heavier repository-wide coding tasks.

## Gemma 4 alternative

Gemma 4 is available as an alternative model family with Apache-2.0 licensing, built-in thinking/reasoning mode (`<|think|>`), multimodal support, and MoE efficiency. The 12B model is **encoder-free** — it processes images and audio directly through the LLM without a separate encoder, making it uniquely fast and capable on 16 GB hardware.

### Gemma 4 profile mapping

| Profile | Models |
|---|---|
| `gemma-16gb` | Gemma 4 12B (Q8) + 12B (Q4) + E4B (Q8) fallback |
| `gemma-24gb` | Gemma 4 31B (Q4) + 26B-A4B (Q4) fallback |
| `gemma-32gb` | Gemma 4 31B (Q8) + 26B-A4B (Q4) fallback |
| `gemma-64gb` | Gemma 4 31B (BF16) + 31B (Q8) + 26B-A4B (Q4) |

### Gemma 4 benchmarks

| Variant | MMLU Pro | AIME 2026 | LiveCodeBench v6 | Codeforces ELO | MMMU Pro |
|---|---|---|---|---|---|
| 31B (dense) | 85.2% | 89.2% | 80.0% | 2150 | 76.9% |
| 26B-A4B (MoE) | 82.6% | 88.3% | 77.1% | 1718 | 73.8% |
| **12B (dense, encoder-free)** | **77.2%** | **77.5%** | **72.0%** | **1659** | **69.1%** |

The 12B scores within 2-5% of the 26B-A4B on most benchmarks while running on 16 GB hardware and adding native audio support.

### When to choose Gemma 4 over Qwen 3.6

- **Apache-2.0 license** — Fully permissive, no commercial restrictions
- **Multilingual strength** — Strong fit for multilingual workloads, especially EU-language-heavy usage
- **Thinking mode** — Built-in reasoning with `<|think|>` token control
- **Encoder-free multimodal (12B only)** — Native image and audio without a separate encoder; faster time-to-first-token for multimodal inference
- **16 GB friendly** — The 12B model fits 8 GB at UD-Q4_K_XL and 16 GB at UD-Q8_K_XL, enabling 256K context on modest hardware
- **MoE efficiency** — 26B-A4B activates only 4B params per token
- **256K context** — Available on 12B, 26B-A4B, and 31B variants

### Gemma 4 inference defaults

Use these defaults for Gemma 4 (different from the Qwen baseline):
- `temperature = 1.0`
- `top_p = 0.95`
- `top_k = 64`
- `presence_penalty = 0.0`
- `repeat_penalty = 1.0`
- EOS token: `<turn|>`

**Warning:** Do not use CUDA 13.2 runtime with GGUFs — it causes degraded outputs.

## Profile Verification Tiers

Profiles in `runtime-config/profiles.json` carry a `verification_tier` field:

- `verified` — Tested on real hardware with smoke tests (`./bin/lac doctor` and `./bin/lac smoke`). This is the strongest guarantee.
- `standard` — Template-reviewed and syntactically valid. Preset values are consistent with the model family guidance, but the profile has not been executed on physical hardware in this repo.
- `extended` — Validated on multiple hardware configurations or by community feedback. Used for niche or high-memory profiles where the maintainer has less direct access to matching hardware.

Use `verified` profiles for production or team baselines. `standard` and `extended` profiles are safe to try but should be validated locally before relying on them.

## Low-end tier guide (4-16 GB)

The 4-16 GB market is served by six profiles (`4gb`, `6gb`, `8gb`, `12gb`, `gemma-6gb`, `gemma-8gb`) plus the retuned `16gb` and `macos-16gb`.

Design rules that make these tiers feasible:

- **Qwen hybrid attention** (Qwen3.5-9B, Qwen3.6-27B): only a quarter of layers use full attention, so the KV cache is near-constant in context size. 32K-64K contexts stay affordable even at 6 GB. This is architecture, not tuning.
- **Dense beats MoE at 12-16 GB for agentic work**: the dense 27B out-scores the 35B-A3B MoE on agentic benchmarks, and its honest 16 GB quant (UD-IQ3_XXS, 12.2 GB) is smaller than the MoE's. The only MoE worth a low-end slot is gemma-4-26b-a4b UD-Q3_K_XL (12.9 GB) on 16 GB, for decode speed over agentic reliability.
- **Gemma 4 12B QAT** (`gemma-4-12b-qat`, 6.4 GB, Google-official, near-lossless) is the strongest model that fits 8 GB — it replaces the plain Q4 as the default for `macos-16gb` and `gemma-8gb`.
- **KV quantization**: `cache-type-k/v = q4_0` on the 4/6 GB tiers halves KV memory; `q8_0` everywhere else.
- **Partial offload**: discrete-VRAM presets (e.g. `6gb`) default to partial `n-gpu-layers` so llama.cpp spills to CPU (`fit = true`) instead of failing to allocate.

Honest expectations: 4 GB is chat + light automation; 8 GB is the agentic floor (small models, short sessions); real multi-step agentic coding wants 12-16 GB. VRAM detection in `lac init` buckets by VRAM when a discrete NVIDIA GPU is smaller than RAM; Apple Silicon uses unified RAM.
