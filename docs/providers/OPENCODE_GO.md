# OpenCode Go

lac configures **OpenCode Go**, a first-party hosted offering that integrates natively with the OpenCode client. It is a useful cloud overlay when you want a curated model set without assembling credentials from multiple vendors.

Cross-check https://opencode.ai/docs/go/ for current model and subscription details.

## Environment variables

| Provider | Env var |
|----------|---------|
| OpenCode Go | `OPENCODE_GO_API_KEY` |

Sign in at https://opencode.ai and copy the API key from your account page. In the OpenCode TUI, `/connect` can also add OpenCode Go directly to OpenCode's auth store.

## Models in this repo

OpenCode Go is pre-wired in `opencode.template.jsonc`. The curated model list evolves upstream; treat the block as a starting point and verify it before a release.

Current OpenAI-compatible Go entries in `opencode.template.jsonc` (checked 2026-08-04): Grok 4.5, GLM 5.2, GLM 5.1, Kimi K3, Kimi K2.7 Code, Kimi K2.6, DeepSeek V4 Pro, DeepSeek V4 Flash, MiMo-V2.5, MiMo-V2.5-Pro, and Hy3.

Go also hosts Qwen3.6 Plus, Qwen3.7 Plus, Qwen3.7 Max, **Qwen3.8 Max** (live since the 2026-08-03 announcement), and MiniMax M3/M2.7/M2.5 — but those use the Anthropic `/v1/messages` endpoint, so they are **not** listed in the template's single-provider OpenAI-compatible block. Select them in OpenCode after subscribing via the `/connect` flow. See `docs/models/QWEN38_READY.md` for the Qwen 3.8 story.

### China-hosted model opt-in

The newest hosted Qwen releases can be served only from China-hosted endpoints until your
account opts in. OpenCode then shows "The latest version of this model is only available
hosted in China and requires explicit opt in" with a workspace link
(`opencode.ai/workspace/<id>/go`). Open that link once and enable the opt-in; the setting
is per-account and does not affect local `local-cluster` inference.

Useful setup commands:

```bash
./bin/lac init --yes --profile 24gb --cloud opencode-go
./bin/lac profile apply opencode-go
./bin/lac provider models opencode-go
./bin/lac provider verify opencode-go
```

Use the first command when you want local models plus a Go overlay. Use `profile apply opencode-go` when you want a zero-download Go-only setup. After subscribing, set `OPENCODE_GO_API_KEY` in your shell environment or connect through OpenCode's `/connect` flow. Then use `/models` in OpenCode to select a Go model such as `opencode-go/glm-5.1`.

## When to use vs. other providers

- **Pick OpenCode Go** when you want a curated model catalog that matches OpenCode's agentic flows without DIY tuning.
- **Pick OpenRouter free tier** when you want zero-cost experimentation and can tolerate rate limits and occasional model rotation.
- **Pick Anthropic API** when you specifically want Claude models with no intermediary.

## Refresh guidance

Before each beta cut:
1. Open https://opencode.ai/docs/go/ and confirm the current catalog.
2. Update the `opencode-go` provider block in `opencode.template.jsonc` if any listed model is retired.
3. Update the `models` array in `catalog/providers.json` to match.
4. Run `lac provider verify opencode-go` with release credentials.
