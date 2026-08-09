# Qwen 3.8 Readiness

Status: **candidate only — no local profile defaults change without release and hardware evidence.**

## Small-model status

Do not add or switch low-end Qwen 3.8 slots based on announcements, projections, or community distills. The low-end tiers keep Qwen3.5-9B / Gemma 4 12B QAT until official weights, llama.cpp compatibility, exact artifact sizes, checksums, and target-hardware results exist.

## Timeline

- **2026-08-03 announcement** — retained as planning context only. Announced dates, benchmark claims, context ceilings, and projected quant sizes are not shipped resource contracts.
- **Local decision gate** — official weights and license, supported GGUFs, llama.cpp compatibility, measured memory/context behavior, and representative agentic results must all be recorded before a default changes.

## What is already wired (pre-drop)

- `opencode.template.jsonc` carries placeholder `qwen3.8-27b-q3`, `qwen3.8-27b-q4`, and `qwen3.8-27b-q6` client slots. They are compatibility placeholders, not download mappings or recommendations.
- No profile defaults have been switched yet — the swaps below are the pending items.

## Drop-day checklist (when GGUFs land)

1. **Source GGUFs** — prefer official/unsloth quantizations matching the slot naming (`qwen3.8-27b-q3/q4/q6`).
2. **Add integrity data** — fill `catalog/checksums.json` SHA256 entries for the three files (or at minimum exact sizes); update `catalog/assets.json` pending slots.
3. **Verify llama.cpp support** — Qwen 3.8 uses a hybrid-attention MoE architecture; run `brew upgrade llama.cpp` and validate with `./bin/lac doctor` and `lac smoke` before promising anything.
4. **Consider profile defaults only after the evidence gate**:
   - `24gb` → `local-cluster/qwen3.8-27b-q4` (was qwen3.6-27b-q4)
   - `32gb` → `local-cluster/qwen3.8-27b-q4` (was qwen3.6-27b-q4)
   - `16gb` → `local-cluster/qwen3.8-27b-q3` (was qwen3.6-27b-q3)
   - `small_model` entries follow the same swap.
5. **Re-run the context matrix** — `./scripts/integration-test.sh` asserts generated OpenCode context == preset `ctx-size` for every profile; then `lac profile apply 24gb`, `lac runtime start`, and an OpenCode smoke session.
6. **Update docs** — `docs/model-recommendations.md` tables and README profile table once the 27B is validated.
7. **Cloud overlay** — verify the live provider catalog and endpoint behavior before documenting availability; hosted presence does not validate local weights.

## Hosted-model caveat

OpenCode's hosted Qwen models (not lac's local-cluster path) can be served only from
China-hosted endpoints for the newest releases; the client shows an opt-in notice with a
workspace link (`opencode.ai/workspace/...`) until the account opts in. That is a
per-account OpenCode setting and does not affect local inference.
