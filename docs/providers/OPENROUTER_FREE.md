# OpenRouter Free Tier

OpenRouter provides a `:free` suffix on select models that require no API credits. These are useful for zero-cost experimentation and for low-end hardware that can't run local models.

**Last verified:** 2026-04-13 — run `./scripts/verify-free-models.sh` to re-check.

## Current Free Models in This Repo

The `openrouter` provider block in `opencode.jsonc` includes:

| Model ID | Notes |
|----------|-------|
| `qwen/qwen3-coder:480b-free` | Strong coding model, 480B MoE. Good for code review and refactoring. |
| `mistralai/devstral-2-free` | Efficient instruction-following model. Good for general tasks. |
| `stepfun/step-3.5-flash:free` | Fast response times, reasonable quality. Good for quick Q&A. |
| `openai/gpt-oss-120b:free` | Open-weight large model. Good general-purpose fallback. |
| `openai/gpt-oss-20b:free` | Smaller, faster variant. Lower quality but very responsive. |
| `nvidia/nemotron-3-nano-30b-a3b:free` | Nvidia's open model. Decent quality for its size. |
| `meta-llama/llama-3.3-70b-instruct:free` | Llama 3.3 70B — strong general-purpose model. |
| `z-ai/glm-4.5-air:free` | GLM 4.5 Air — S+ tier coding model, strong reasoning. |
| `qwen/qwen3-next-80b-a3b-instruct:free` | Qwen3 Next 80B MoE — next-gen coding and reasoning. |
| `openai/gpt-4o-mini:free` | GPT-4o Mini — fast general-purpose model. |
| `google/gemini-2.0-flash-exp:free` | Gemini 2.0 Flash — strong general-purpose with large context. |

## Rate Limits and Caveats

- **Rate limits apply**: Free models have per-minute and per-day request limits. Heavy usage will hit `429 Too Many Requests`.
- **No uptime guarantee**: Free models may be temporarily unavailable during peak demand.
- **Models rotate**: OpenRouter adds and removes free models frequently. Verify availability before each beta cut.
- **`:free` suffix is required**: The same model without `:free` (e.g., `openai/gpt-oss-120b`) requires paid credits.

## Refresh Guidance

Before each public beta cut:
1. Run `./scripts/verify-free-models.sh` (requires `OPENROUTER_API_KEY` and/or `NVIDIA_API_KEY`) to check all configured models
2. Remove any `[!!] REMOVED` models from `opencode.jsonc`
3. Visit https://openrouter.ai/models?pricing=free to verify current availability
4. Update this doc if rate limits or caveats have changed
5. Update `docs/FREE_CLOUD_MODELS.md` and `docs/free-coding-models.json` to match

## Default Profile Risk

The `openrouter` hardware profile sets `qwen/qwen3-coder:480b-free` as the default model. This is the single most user-visible failure point — if OpenRouter removes this model, the entire profile stops working at startup.

If `verify-free-models.sh` reports this model as `[!!] REMOVED`:
- Update the `openrouter` profile in `scripts/setup-config-device.sh` and `.ps1` to use the next highest-tier free model (e.g., `z-ai/glm-4.5-air:free`)
- Update `runtime-config/presets/openrouter.ini` if needed
- Re-run verification to confirm the replacement works
