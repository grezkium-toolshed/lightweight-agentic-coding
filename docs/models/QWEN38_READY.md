# Qwen 3.8 Readiness

Status: **shipped as the main local model family** (Qwen 3.8 27B). GGUFs from
`unsloth/Qwen3.8-27B-GGUF` are wired into the 16/24/32/48/64/128gb-multi profiles as the
default, with mmproj vision attached. Remaining gaps: no official MTP repo and no MLX repo yet.

## Quant selection (top-1% agreement vs BF16)

| Quant | Size (GiB) | Agreement | Shipped as |
|---|---:|---:|---|
| UD-Q3_K_XL | 12.5 | 92.4% | `16gb` default |
| UD-Q4_K_XL | 16.7 | 96.1% | `24gb` / `32gb` default |
| Q8_0 | 27.0 | 98.8% | 48 GB memory-pressure fallback (documented, not shipped) |
| UD-Q8_K_XL | 29.3 | 99.0% | `48gb` / `64gb` / `128gb-multi` default |

## What is wired

- `opencode.template.jsonc` carries `qwen3.8-27b-q3/q4/q6/q8` client slots (262144 context,
  16384 output) and the top-level `model` / `small_model` fallbacks point at qwen3.8 q4/q3.
- `src/lac/models.py` `PROFILE_MODELS` downloads the qwen3.8 GGUFs + `mmproj-F16.gguf`
  (0.86 GiB) for the six profiles; `catalog/checksums.json` holds SHA256 integrity data.
- Presets set the Unsloth instruct-mode baseline (`temp 0.7 / top-p 0.8 / top-k 20 /
  presence-penalty 1.5 / repeat-penalty 1.0`), `reasoning = off` as the default start,
  `cache-type-k/v = q8_0`, and the embedded qwen3_5 chat template (no `chat-template-file`
  override) with `mmproj = __MODELS_DIR__/qwen3.8/mmproj-F16.gguf`.
- Contexts: 128K for 16/24/32gb, 256K for 48/64/128gb-multi. See `docs/model-recommendations.md`.

## Known gaps and gates

- **MTP**: no Qwen 3.8 MTP repo yet; the 32/64/128gb-multi profiles keep Qwen 3.6 MTP slots.
- **MLX / oMLX**: no Qwen 3.8 MLX repo yet. `_profile_supports_omlx` rejects qwen3.8-default
  profiles, so macOS auto-selection falls back to llama.cpp for them; Gemma profiles keep the
  oMLX path. When Unsloth ships Qwen3.8 MLX, add `LOCAL_MLX_MODEL_IDS` entries in
  `src/lac/config.py` and re-enable oMLX tests.
- **Low-end tiers**: `4gb`–`12gb` and `macos-16gb` keep Qwen3.5-9B / Gemma 4 QAT defaults.
  The Qwen 3.8 IQ2 tier (82–86% agreement) is a quality cliff, not a default.
- **48 GB fit**: 29.3 GiB weights + ~8.5 GiB KV at 256K/q8_0 + compute sits against the
  40 GiB post-headroom budget; `lac context --profile 48gb` shows the per-cache-type math,
  and `Q8_0` (27.0 GiB) is the documented pressure fallback.
- **Validation**: llama.cpp load, KV/tok/s behavior, and checksums were validated on the
  maintainer's M4 Max 128 GB testbed; 48 GB exact-hardware fit remains the manual-gate item
  before the profile's `auto_recommend` flips.
- **Vision**: mmproj is attached at the runtime level; OpenCode image passthrough over the
  openai-compatible provider is best-effort.

## Hosted-model caveat

OpenCode's hosted Qwen models (not lac's local-cluster path) can be served only from
China-hosted endpoints for the newest releases; the client shows an opt-in notice with a
workspace link (`opencode.ai/workspace/...`) until the account opts in. That is a
per-account OpenCode setting and does not affect local inference.
