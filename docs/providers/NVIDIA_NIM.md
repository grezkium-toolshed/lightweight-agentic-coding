# NVIDIA NIM Support

This repo includes an `nvidia-nim` provider block in `opencode.jsonc` using the OpenAI-compatible endpoint:

- `https://integrate.api.nvidia.com/v1`

## Why NIM belongs here
- strong free or trial-backed model access
- useful bridge for smaller hardware
- good fit for startup and home users who want frontier-adjacent capability without running very large local models

## Included example models
- `deepseek-ai/deepseek-v3.2`
- `qwen/qwen3-coder-480b-a35b-instruct`
- `qwen/qwen2.5-coder-32b-instruct`
- `openai/gpt-oss-120b`
- `meta/llama-3.3-70b-instruct`
- `nvidia/nemotron-3-nano-30b-a3b`

Availability can change. Treat these as starter examples, then refresh against current NIM catalogs and your own account limits.

## Operational note
Keep local Qwen 3.5 profiles as the default recommendation. NIM is the best fallback when hardware is not enough or a user needs a faster path to adoption.
