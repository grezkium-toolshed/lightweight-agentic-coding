# Provider Authentication and Prerequisites

These providers are optional. Local llama.cpp remains the default path.

## Verifying credentials

Use `provider verify` to confirm both provider auth and local-cluster readiness:

```bash
./bin/lac provider verify openrouter
./bin/lac provider verify --all
```

The probe sends a real request to each provider's baseURL with your key. `--all` also probes the local health endpoint, so it can report `error` until `./bin/lac runtime start` has been run. Results report as `ok`, `skipped` (env var unset), or `error` with a reason. Secrets are never written to logs or JSON output — only the env var name and a boolean `configured` flag appear.

## Antigravity
- recommended repo env var convention: `ANTIGRAVITY_API_KEY`
- endpoint in repo config: `https://api.antigravity.ai/v1`
- prerequisite: an account with API access to the referenced models
- recommended usage: frontier-grade cloud fallback when local hardware is not enough
- plugin: `opencode-antigravity-auth` must be installed via npm before using this provider. Add it to the `plugin` array in your config and run `npm install opencode-antigravity-auth`. Without this plugin, the antigravity provider block will fail to initialize.

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

## OpenCode Go
- recommended repo env var convention: `OPENCODE_GO_API_KEY`
- endpoint in repo config: `https://opencode.ai/zen/go/v1`
- prerequisite: OpenCode Go subscription at https://opencode.ai
- recommended usage: flat-rate subscription with a curated model list, matched to OpenCode's agentic flows
- details: `OPENCODE_ZEN_GO.md`

## OpenCode Zen
- recommended repo env var convention: `OPENCODE_ZEN_API_KEY`
- endpoint in repo config: `https://api.opencode.ai/zen/v1`
- prerequisite: OpenCode Zen account with credits at https://opencode.ai
- recommended usage: pay-per-request curated access, broader current catalog than Go
- details: `OPENCODE_ZEN_GO.md`

## Codex via ChatGPT Subscription
- recommended repo env var convention: `OPENAI_API_KEY`
- endpoint in repo config: `https://api.openai.com/v1`
- prerequisite: ChatGPT Plus / Pro / Team subscription, plus the third-party helper at https://github.com/numman-ali/opencode-openai-codex-auth
- recommended usage: reuse an existing ChatGPT subscription as an OpenAI-compatible provider
- details: `CODEX_AUTH.md`
- note: third-party auth helper; treat as reviewed-external trust

## Anthropic API
- recommended repo env var convention: `ANTHROPIC_API_KEY`
- prerequisite: API key from https://console.anthropic.com (Claude.ai subscription does NOT work)
- recommended usage: direct access to the Claude 4.x family
- details: `ANTHROPIC_API.md`

## Important notes
- These environment variable names are repo conventions for documentation and shell setup. Local-cluster readiness is profile/runtime based, so use the selected profile plus `./bin/lac runtime start` rather than treating env vars as a readiness step.
- Model availability and quota policies change frequently.
- Treat the provider blocks in `opencode.template.jsonc` as verified starter examples, not permanent guarantees.
- Refresh `docs/FREE_CLOUD_MODELS.md` when preparing a new public beta cut.
