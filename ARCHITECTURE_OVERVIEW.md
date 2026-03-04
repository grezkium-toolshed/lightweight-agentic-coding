# Architecture Overview

## Runtime

- Inference: `llama.cpp` (`llama-server`)
- Endpoint: `http://127.0.0.1:8080/v1`
- OpenCode config: repo root `opencode.jsonc`

## Model Strategy

- Specialist coding: `qwen3-coder-next-80b`
- General task tiers: Qwen 3.5 (9B / 27B / 35B / 122B)
- Optional high-end alternative: MiniMax profile on 128GB tier
- Embeddings: `nomic-embed-text-v1.5`

## Profile IDs

- `16gb`
- `24gb`
- `32gb`
- `64gb`
- `128gb-qwen122b`
- `128gb-minimax`

## 128GB Policy

Use conservative defaults and keep effective memory usage <=115GB for stability headroom.
