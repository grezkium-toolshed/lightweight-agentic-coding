# Free Cloud Fallbacks

Free or trial-backed cloud providers make this cluster usable on weaker hardware and for onboarding teams that are not ready to run large local models.

## Recommended order
1. Local llama.cpp + Qwen 3.6 if the hardware can handle it.
2. NVIDIA NIM for strong free or trial-backed OpenAI-compatible access.
3. OpenRouter free models for shared-quota experimentation.
4. z.ai and Antigravity when those are a good fit for your org or personal setup.

## Design principle
Cloud fallbacks are an adoption bridge, not the primary identity of the repo. The baseline should still work locally first.

## What to consider
- quota volatility
- provider-specific rate limits
- data sensitivity
- API key handling
- model drift over time

Use `scripts/sync-free-cloud-models.*` to refresh the community-maintained snapshot of currently free coding-capable models.
