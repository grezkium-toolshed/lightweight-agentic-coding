# OpenRouter Free Tier

OpenRouter provides a `:free` suffix on select models that require no API credits. These are useful for zero-cost experimentation and for low-end hardware that can't run local models.

**Last verified:** 2026-04-21 (structural review; use `./bin/lac provider models openrouter` for the live list and `./bin/lac provider verify openrouter --refresh-catalog` for a live refresh).

## Live Model List

OpenRouter free models are refreshed into `catalog/providers.json` from the live `/models` response. The repo still keeps starter defaults in `opencode.template.jsonc` so a clean clone can render a working config before the first refresh.

Use these commands:
- `./bin/lac provider models openrouter` to print the current live model list
- `./bin/lac provider list` to inspect provider freshness and readiness
- `./bin/lac provider verify openrouter --refresh-catalog` to probe the endpoint with your key and store the refreshed catalog

## Rate Limits and Caveats

- **Rate limits apply**: Free models have per-minute and per-day request limits. Heavy usage will hit `429 Too Many Requests`.
- **No uptime guarantee**: Free models may be temporarily unavailable during peak demand.
- **Models rotate**: OpenRouter adds and removes free models frequently. Verify availability before each beta cut.
- **`:free` suffix is required**: The same model without `:free` (e.g., `openai/gpt-oss-120b`) requires paid credits.

## Refresh Guidance

When the live list or risk posture changes:
1. Run `./bin/lac provider verify openrouter --refresh-catalog`
2. Re-run `./bin/lac provider models openrouter` and confirm the refreshed list looks sane
3. Update this doc only if the refresh command, caveats, or fallback posture changes
4. Keep `docs/FREE_CLOUD_MODELS.md` and `docs/free-coding-models.json` focused on the live command path rather than a frozen table
