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
- `macos-16gb`: Qwen3.5 9B `Q4_K_M` + Gemma 4 E4B `Q8_0` for Apple Silicon headroom
- `24gb`: Qwen 3.6 27B `UD-Q4_K_XL`
- `32gb`: Qwen 3.6 27B `UD-Q4_K_XL` + qwen3-coder-next
- `64gb`: Qwen 3.6 35B-A3B `UD-Q8_K_XL` + qwen3-coder-next
- `128gb-multi`: multiple practical local models
- `128gb-qwen122b`: Qwen 122B-focused
- `128gb-minimax`: MiniMax M2.7 `UD-IQ4_XS` alternative

## 128GB MiniMax alternative

Use `128gb-minimax` when you specifically want MiniMax M2.7 on a 128 GB machine.

Recommended quant for this repo:
- `UD-IQ4_XS`

Why this one:
- Unsloth lists it at about 108 GB, which fits the repo's 128 GB headroom posture much better than `UD-Q4_K_XL`
- it is the practical compromise when you want stronger quality than very low-bit MiniMax options without exceeding the memory budget

## Specialist local model

Keep `qwen3-coder-next` as a coding specialist, not the default answer for every task. It belongs in the higher-memory tiers and multi-model setups.

## When to use free cloud fallbacks

Use free or trial-backed cloud providers when:
- hardware is too small for the desired local model
- onboarding speed matters more than full local execution
- a team wants to try the workflow before investing in hardware

Recommended fallback order:
1. NVIDIA NIM
2. OpenRouter free models
3. z.ai
4. Antigravity

## Office and documentation workloads

For office automation, the model matters less than workflow quality and tool support. Smaller Qwen profiles can still be useful if the repo provides strong skills and clear workflow guidance.

## Apple Silicon 16GB

Use `macos-16gb` for MacBook Air M4 16GB-class machines. It prioritizes OS headroom, context room, and interactive responsiveness over maximum parameter count:
- Qwen3.5 9B `Q4_K_M` is the default local coding/general model.
- Gemma 4 E4B `Q8_0` is the smaller alternate for lighter multilingual and local office work.
- Start at 32K context on 16GB macOS; increase only after validating memory pressure.
- Use OpenCode Go or OpenRouter overlays for heavier repository-wide coding tasks.

## Gemma 4 alternative

Gemma 4 is available as an alternative model family with Apache-2.0 licensing, built-in thinking/reasoning mode (`<|think|>`), multimodal support, and MoE efficiency.

### Gemma 4 profile mapping

| Profile | Models |
|---|---|
| `gemma-16gb` | Gemma 4 26B-A4B (Q4) + E4B (Q8) fallback |
| `gemma-24gb` | Gemma 4 31B (Q4) + 26B-A4B (Q4) fallback |
| `gemma-32gb` | Gemma 4 31B (Q8) + 26B-A4B (Q4) fallback |
| `gemma-64gb` | Gemma 4 31B (BF16) + 31B (Q8) + 26B-A4B (Q4) |

### Gemma 4 benchmarks

| Variant | MMLU Pro | AIME 2026 | LiveCodeBench v6 | MMMU Pro |
|---|---|---|---|---|
| 31B (dense) | 85.2% | 89.2% | 80.0% | 76.9% |
| 26B-A4B (MoE) | 82.6% | 88.3% | 77.1% | 73.8% |

### When to choose Gemma 4 over Qwen 3.6

- **Apache-2.0 license** — Fully permissive, no commercial restrictions
- **Multilingual strength** — Strong fit for multilingual workloads, especially EU-language-heavy usage
- **Thinking mode** — Built-in reasoning with `<|think|>` token control
- **Multimodal** — Vision support via `--mmproj` clip projector
- **MoE efficiency** — 26B-A4B activates only 4B params per token
- **256K context** — Available on 26B-A4B and 31B variants

### Gemma 4 inference defaults

Use these defaults for Gemma 4 (different from the Qwen baseline):
- `temperature = 1.0`
- `top_p = 0.95`
- `top_k = 64`
- `presence_penalty = 0.0`
- `repeat_penalty = 1.0`
- EOS token: `<turn|>`

**Warning:** Do not use CUDA 13.2 runtime with GGUFs — it causes degraded outputs.
