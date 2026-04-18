# Anthropic API

The `anthropic` provider is Anthropic's first-party API. Use this when you want Claude models with no intermediary.

**Last verified:** 2026-04-18 — cross-check https://docs.claude.com/en/docs before each beta cut.

## Important: subscription does not work here

A Claude.ai subscription (Pro, Max, etc.) is **not** API credits. OpenCode talks to Anthropic over the API, which is billed separately and requires an API key from https://console.anthropic.com.

If you only have a Claude subscription:
- Use the Claude.ai web UI or Claude Code for interactive work.
- For OpenCode, either get an API key (pay-as-you-go), or use a different provider (OpenRouter, OpenCode Go, etc.).

## Environment variable

| Provider | Env var |
|----------|---------|
| Anthropic | `ANTHROPIC_API_KEY` |

Create a key at https://console.anthropic.com/settings/keys. Keys are billed per request.

## Models in this repo

The `anthropic` provider block in `opencode.jsonc` includes the current Claude 4.x family:

| Model ID | Notes |
|----------|-------|
| `claude-opus-4-7` | Most capable. Best for planning, architecture, complex refactors. |
| `claude-sonnet-4-6` | Balanced. Default for most agentic work. |
| `claude-haiku-4-5-20251001` | Fast and cheap. Good for quick iteration or routing. |

Model IDs follow Anthropic's API naming. Keep them in sync with https://docs.claude.com/en/docs/about-claude/models.

## When this is a good fit

- You want Claude models specifically (reasoning quality, long-context behavior, tool use).
- You are comfortable with metered API billing.
- You want a direct path with no third-party auth helpers.

## Caveats

- **Billing is per-token, not fixed.** Heavy agentic use adds up quickly.
- **Rate limits apply per tier.** New accounts start with low per-minute limits; the console shows current tier.
- **Not a replacement for Claude Code's subscription access.** If you already have Claude Max or Claude Code subscription, that access stays in Claude Code / the web — OpenCode still needs a separate API key.

## Refresh guidance

Before each beta cut:
1. Open https://docs.claude.com/en/docs/about-claude/models and confirm current model IDs.
2. Update the `anthropic` provider block in `opencode.jsonc` if the 4.x family has shifted.
3. Update the `models` array in `catalog/providers.json` to match.
4. Bump `last_verified_at`.
