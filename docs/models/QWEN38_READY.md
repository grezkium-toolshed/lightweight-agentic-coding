# Qwen 3.8 Readiness

Status: **prepped — open weights not yet released.**

## Timeline

- **2026-08-03** — Qwen3.8-Max announced: 2.4T-parameter MoE (95B active), hybrid attention, 1M context, text + image/video input, `$2` / `$6` / `$0.25`-cached per 1M tokens. Open-weights release announced for the **following week (~2026-08-10)**, together with **Qwen3.8-27B** going open-weights.
- **Agentic gains** — the generation jump is the story for lac: FrontierSWE rose 40.7 → 73.5 in this family, and the 27B checkpoint is the one that fits ordinary on-premise hardware (projected: Q3_K_M ~12 GB VRAM, Q4_K_M ~16 GB, Q6_K ~24 GB).

## What is already wired (pre-drop)

- `opencode.template.jsonc` → `local-cluster` provider now carries `qwen3.8-27b-q3`, `qwen3.8-27b-q4`, `qwen3.8-27b-q6` slots (262144 context / 16384 output, matching the qwen3.6-27b entries). Generated configs render today; `lac models sync` simply has nothing to download until catalog entries exist.
- No profile defaults have been switched yet — the swaps below are the pending items.

## Drop-day checklist (when GGUFs land)

1. **Source GGUFs** — prefer official/unsloth quantizations matching the slot naming (`qwen3.8-27b-q3/q4/q6`).
2. **Add integrity data** — fill `catalog/checksums.json` SHA256 entries for the three files (or at minimum exact sizes); update `catalog/assets.json` pending slots.
3. **Verify llama.cpp support** — Qwen 3.8 uses a hybrid-attention MoE architecture; run `brew upgrade llama.cpp` and validate with `./bin/lac doctor` and `lac smoke` before promising anything.
4. **Flip profile defaults** (pending benchmark validation):
   - `24gb` → `local-cluster/qwen3.8-27b-q4` (was qwen3.6-27b-q4)
   - `32gb` → `local-cluster/qwen3.8-27b-q4` (was qwen3.6-27b-q4)
   - `16gb` → `local-cluster/qwen3.8-27b-q3` (was qwen3.6-27b-q3)
   - `small_model` entries follow the same swap.
5. **Re-run the context matrix** — `./scripts/integration-test.sh` asserts generated OpenCode context == preset `ctx-size` for every profile; then `lac profile apply 24gb`, `lac runtime start`, and an OpenCode smoke session.
6. **Update docs** — `docs/model-recommendations.md` tables and README profile table once the 27B is validated.
7. **Cloud overlay** — `qwen3.8-max` is **already live on OpenCode Go** (since the 2026-08-03 announcement) and is selectable after subscribing via `/connect` (Anthropic `/v1/messages` endpoint — see `docs/providers/OPENCODE_GO.md`; it is not in the template's OpenAI-compatible Go block by design).

## Hosted-model caveat

OpenCode's hosted Qwen models (not lac's local-cluster path) can be served only from
China-hosted endpoints for the newest releases; the client shows an opt-in notice with a
workspace link (`opencode.ai/workspace/...`) until the account opts in. That is a
per-account OpenCode setting and does not affect local inference.
