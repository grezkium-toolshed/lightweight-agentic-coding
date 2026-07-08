# OpenCode Go

lac configures **OpenCode Go**, a first-party hosted offering that integrates natively with the OpenCode client — a useful cloud overlay when you want a curated set of models without assembling credentials from multiple vendors. Its sibling **OpenCode Zen** (pay-per-request) is described below for context but is not a configured provider in lac.

Cross-check https://opencode.ai/docs/go/ (and https://opencode.ai/docs/zen/) for current model lists.

## Quick comparison

| Product | Pricing model | When to pick it |
|---------|---------------|-----------------|
| **OpenCode Go** | Flat subscription (roughly $10/mo after intro) | Predictable monthly cost, stable curated model list |
| **OpenCode Zen** | Pay-per-request credits | Low or variable usage, or you want the broadest current model list |

Both are first-party OpenCode hosted providers. Switching between them is just an env var or `/connect` change.

## Environment variables

| Provider | Env var |
|----------|---------|
| OpenCode Go | `OPENCODE_GO_API_KEY` |
| OpenCode Zen | `OPENCODE_ZEN_API_KEY` |

Sign in at https://opencode.ai and copy the API key from your account page. In the OpenCode TUI, `/connect` can also add OpenCode Go directly to OpenCode's auth store.

## Models in this repo

Both providers are pre-wired in `opencode.template.jsonc`. The curated model list evolves upstream; treat the blocks here as a starting point and refresh before each beta cut.

Current OpenCode Go entries include GLM 5.1, GLM 5, Kimi K2.6, Kimi K2.5, MiMo-V2.5, MiMo-V2.5-Pro, MiMo-V2-Pro, MiMo-V2-Omni, MiniMax M2.7, MiniMax M2.5, Qwen3.6 Plus, and Qwen3.5 Plus.

Useful setup commands:

```bash
./bin/lac init --yes --profile 24gb --cloud opencode-go
./bin/lac profile apply opencode-go
./bin/lac provider models opencode-go
./bin/lac provider verify opencode-go
```

Use the first command when you want local models plus a Go overlay. Use `profile apply opencode-go` when you want a zero-download Go-only setup. After subscribing, set `OPENCODE_GO_API_KEY` in your shell environment or connect through OpenCode's `/connect` flow. Then use `/models` in OpenCode to select a Go model such as `opencode-go/qwen3.6-plus`.

## When to use vs. other providers

- **Pick OpenCode Go/Zen** when you want a curated, tested model catalog that matches OpenCode's agentic flows without DIY tuning.
- **Pick OpenRouter free tier** when you want zero-cost experimentation and can tolerate rate limits and occasional model rotation.
- **Pick Anthropic API** when you specifically want Claude models with no intermediary.
- **Pick Codex auth** when you already have a ChatGPT subscription and want to reuse it.

## Refresh guidance

Before each beta cut:
1. Open https://opencode.ai/docs/zen/ and https://opencode.ai/docs/go/ and confirm the current catalog.
2. Update the `opencode-zen` and `opencode-go` provider blocks in `opencode.template.jsonc` if any listed model is retired.
3. Update the `models` array in `catalog/providers.json` to match.
4. Bump `last_verified_at` in `catalog/providers.json` for both providers.
