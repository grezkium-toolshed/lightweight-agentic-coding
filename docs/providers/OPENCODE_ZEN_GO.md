# OpenCode Zen and OpenCode Go

OpenCode ships two first-party hosted offerings that integrate natively with the OpenCode client. They are a useful cloud overlay when you want a curated set of models without assembling credentials from multiple vendors.

**Last verified:** 2026-04-18 — cross-check https://opencode.ai/docs/zen/ and https://opencode.ai/docs/go/ before each beta cut.

## Quick comparison

| Product | Pricing model | When to pick it |
|---------|---------------|-----------------|
| **OpenCode Go** | Flat subscription (roughly $10/mo after intro) | Predictable monthly cost, stable curated model list |
| **OpenCode Zen** | Pay-per-request credits | Low or variable usage, or you want the broadest current model list |

Both are openai-compatible from the client's point of view. Switching between them is just an env var change.

## Environment variables

| Provider | Env var |
|----------|---------|
| OpenCode Go | `OPENCODE_GO_API_KEY` |
| OpenCode Zen | `OPENCODE_ZEN_API_KEY` |

Sign in at https://opencode.ai and copy the API key from your account page.

## Models in this repo

Both providers are pre-wired in `opencode.jsonc`. The curated model list evolves upstream; treat the blocks here as a starting point and refresh before each beta cut.

Current entries include GLM 4.7, Claude Sonnet 4.6 (Zen only, subject to upstream availability), and GPT-5 Codex (Zen only).

## When to use vs. other providers

- **Pick OpenCode Go/Zen** when you want a curated, tested model catalog that matches OpenCode's agentic flows without DIY tuning.
- **Pick OpenRouter free tier** when you want zero-cost experimentation and can tolerate rate limits and occasional model rotation.
- **Pick Anthropic API** when you specifically want Claude models with no intermediary.
- **Pick Codex auth** when you already have a ChatGPT subscription and want to reuse it.

## Refresh guidance

Before each beta cut:
1. Open https://opencode.ai/docs/zen/ and https://opencode.ai/docs/go/ and confirm the current catalog.
2. Update the `opencode-zen` and `opencode-go` provider blocks in `opencode.jsonc` if any listed model is retired.
3. Update the `models` array in `catalog/providers.json` to match.
4. Bump `last_verified_at` in `catalog/providers.json` for both providers.
