# Model Recommendations

## Local-first baseline

Use Qwen 3.5 as the default local family for general agentic work.

Recommended profile mapping:
- `16gb`: Qwen 3.5 9B
- `24gb`: Qwen 3.5 27B
- `32gb`: Qwen 3.5 35B-A3B
- `64gb`: Qwen 3.5 35B-A3B + qwen3-coder-next
- `128gb-multi`: multiple practical local models
- `128gb-qwen122b`: Qwen 122B-focused
- `128gb-minimax`: MiniMax-focused

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

For office automation, the model matters less than workflow quality and tool support. Smaller Qwen 3.5 profiles can still be useful if the repo provides strong skills and clear workflow guidance.

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

### When to choose Gemma 4 over Qwen 3.5

- **Apache-2.0 license** — Fully permissive, no commercial restrictions
- **Thinking mode** — Built-in reasoning with `<|think|>` token control
- **Multimodal** — Vision support via `--mmproj` clip projector
- **MoE efficiency** — 26B-A4B activates only 4B params per token
- **256K context** — Available on 26B-A4B and 31B variants

### Gemma 4 inference defaults

Use these defaults for Gemma 4 (different from Qwen 3.5):
- `temperature = 1.0`
- `top_p = 0.95`
- `top_k = 64`
- `presence_penalty = 0.0`
- `repeat_penalty = 1.0`
- EOS token: `<turn|>`

**Warning:** Do not use CUDA 13.2 runtime with GGUFs — it causes degraded outputs.
