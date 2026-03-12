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
