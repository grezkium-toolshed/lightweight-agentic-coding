# Category Guide

This repository now uses profile-based model selection with OpenCode root config and llama.cpp presets.

Recommended routing pattern:

- High-value coding tasks: `qwen3-coder-next-80b`
- General, reasoning, and utility tasks: Qwen 3.5 profile primary model
- Embeddings: `nomic-embed-text-v1.5`

Use `scripts/setup-config-device.*` to set the active profile and default model.
