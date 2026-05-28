# Provider Guidance

This Local AI Cluster supports three practical provider modes:
- fully local via llama.cpp
- local + free cloud fallback
- hosted-model client path

Provider freshness and risk metadata now live in `catalog/providers.json`.

Run `./bin/lac provider verify --all` for a live reachability probe — each configured provider gets a real HTTP request to its baseURL and reports `ok`, `skipped`, or `error`. Pass `--refresh-catalog` to bump `last_verified_at` on success.

Local baseline guidance:
- target default family: Qwen 3.6 MoE
- target default quant class: Unsloth `UD-Q4_K_XL`
- multilingual alternative: Gemma 4, especially for EU-language-heavy deployments

Read next:
- `AUTHENTICATION.md`
- `FREE_CLOUD_FALLBACKS.md`
- `NVIDIA_NIM.md`
- `OPENROUTER_FREE.md`
- `OPENCODE_ZEN_GO.md`
- `CODEX_AUTH.md`
- `ANTHROPIC_API.md`
- `MICROSOFT_GRAPH.md`
- `OPENCHAMBER.md`
