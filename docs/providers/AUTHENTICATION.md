# Provider Authentication and Prerequisites

These providers are optional. Local llama.cpp remains the default path.

## Antigravity
- recommended repo env var convention: `ANTIGRAVITY_API_KEY`
- endpoint in repo config: `https://api.antigravity.ai/v1`
- prerequisite: an account with API access to the referenced models
- recommended usage: frontier-grade cloud fallback when local hardware is not enough

## z.ai
- recommended repo env var convention: `ZAI_API_KEY`
- endpoint in repo config: `https://open.z.ai/api/paas/v4`
- prerequisite: an account with access to the referenced GLM models
- recommended usage: alternative cloud fallback with strong general models

## NVIDIA NIM
- recommended repo env var convention: `NVIDIA_API_KEY`
- endpoint in repo config: `https://integrate.api.nvidia.com/v1`
- prerequisite: NIM account access and whatever free or trial quota is currently available
- recommended usage: strongest free or trial-backed OpenAI-compatible fallback in this repo

## OpenRouter
- recommended repo env var convention: `OPENROUTER_API_KEY`
- endpoint in repo config: `https://openrouter.ai/api/v1`
- prerequisite: OpenRouter account and available shared or paid quota
- recommended usage: lowest-friction free-tier experimentation across multiple hosted models

## Important notes
- These environment variable names are repo conventions for documentation and shell setup. If you use a different secret-loading method, keep the docs and your local environment consistent.
- Model availability and quota policies change frequently.
- Treat the provider blocks in `opencode.jsonc` as verified starter examples, not permanent guarantees.
- Refresh `docs/FREE_CLOUD_MODELS.md` when preparing a new public beta cut.
