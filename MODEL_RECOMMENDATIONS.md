# Model Recommendations

## Default Family

Use Qwen 3.5 Unsloth GGUF variants as the base model family for local OpenCode clusters.

## Tier Recommendations

### 16GB

- Primary: `Qwen3.5-9B-UD-Q4_K_XL.gguf`
- Keep context conservative for reliability.

### 24GB

- Primary: `Qwen3.5-27B-UD-Q4_K_XL.gguf`
- Fallback: 9B

### 32GB

- Primary: `Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf`
- Utility: 27B
- Optional coding specialist: `Qwen3-Coder-Next-MXFP4_MOE.gguf`

### 64GB

- Primary: 35B-A3B
- Specialist coding: qwen3-coder-next
- Utility: 27B

### 128GB (option A)

- Profile: `128gb-qwen122b`
- Primary: `Qwen3.5-122B-A10B-MXFP4_MOE-*`
- Keep effective usage <=115GB.

### 128GB (option B)

- Profile: `128gb-minimax`
- Primary: MiniMax model
- Keep effective usage <=115GB.

## Embeddings

- `nomic-embed-text-v1.5.Q4_K_M.gguf`

## Why keep qwen3-coder-next

It remains a strong specialist option for high-value coding tasks where depth and code quality are prioritized over speed.
