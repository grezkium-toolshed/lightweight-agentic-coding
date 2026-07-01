# Plan: Replace Qwen Coder Next with Qwen 3.6 MTP Models

> Historical note: this plan is kept for traceability and may mention
> superseded script names, release goals, or implementation sequencing.
> Current public-beta blockers are canonical in `docs/release/gates.json`,
> `docs/release/MANUAL_VALIDATION.md`, and `RELEASE_CHECKLIST.md`.
> Use `./scripts/release-gate-report.sh` for authoritative release status.

**Date:** 2026-05-19
**Rationale:** Qwen Coder Next tends to fail with tool calls. Qwen 3.6 27B (best architect) and 35B-A3B (fast coder) with MTP speculative decoding provide better reliability and sufficient speed. MTP was merged into llama.cpp and delivers 1.4-2.2x faster inference with no accuracy loss.

## Scope

### Remove `qwen3-coder-next-80b` from 5 local presets
- `runtime-config/presets/128gb-multi.ini`
- `runtime-config/presets/32gb.ini`
- `runtime-config/presets/64gb.ini`
- `runtime-config/presets/128gb-qwen122b.ini`
- `runtime-config/presets/128gb-minimax.ini`

### Add MTP variants to those presets
| Model | Quant | Context | spec-draft-n-max |
|---|---|---|---|
| 27B MTP | UD-Q4_K_XL | 262144 | 6 (tunable 1-6) |
| 35B-A3B MTP | UD-Q6_K_XL | 262144 | 6 (tunable 1-6) |

Per-preset additions:
- **128gb-multi:** +27B Q4 MTP, +35B-A3B Q6 MTP, drop 27B Q3
- **32gb:** +27B Q4 MTP only (memory constraint)
- **64gb:** +35B-A3B Q6 MTP only (keep 27B Q4 fallback)
- **128gb-qwen122b:** +27B Q4 MTP, +35B-A3B Q6 MTP
- **128gb-minimax:** +27B Q4 MTP, +35B-A3B Q6 MTP

### Add MTP model entries to `opencode.template.jsonc`
- `qwen3.6-27b-mtp-q4`: context 262144, output 16384
- `qwen3.6-35b-a3b-mtp-q6`: context 262144, output 16384

### Mirror all changes in `src/lac/data/`
- `src/lac/data/runtime-config/presets/` (5 files)
- `src/lac/data/opencode/opencode.template.jsonc`

### Update documentation
- `docs/model-recommendations.md` — profile mapping, shipped settings, specialist model section
- `docs/architecture.md` — replace coder-next reference with MTP
- `docs/rules/cluster-guidelines.md` — same
- `docs/use-cases/ONBOARDING_32GB_PLUS.md` — same
- `docs/CONFLUENCE_QWEN35_MIGRATION_GUIDE.md` — note removal

### NOT changed (cloud-only, kept)
- `catalog/providers.json` — antigravity, nvidia-nim, openrouter coder entries
- Cloud provider entries in `opencode.template.jsonc`
- `docs/FREE_CLOUD_MODELS.md`, `docs/providers/NVIDIA_NIM.md`

## MTP INI section pattern
```ini
[qwen3.6-27b-mtp-q4]
model = __MODELS_DIR__/qwen3.6-mtp/Qwen3.6-27B-MTP-UD-Q4_K_XL.gguf
ctx-size = 262144
fit = true
fit-ctx = 262144
n-gpu-layers = 999
threads = 10
batch-size = 1024
ubatch-size = 256
cache-type-k = q8_0
cache-type-v = q8_0
temp = 0.7
top-p = 0.9
top-k = 40
min-p = 0.0
presence-penalty = 0.2
repeat-penalty = 1.04
jinja = true
chat-template-file = __CLUSTER_ROOT__/runtime-config/chat-templates/qwen3.5.jinja
reasoning = off
spec-type = draft-mtp
spec-draft-n-max = 6

[qwen3.6-35b-a3b-mtp-q6]
model = __MODELS_DIR__/qwen3.6-mtp/Qwen3.6-35B-A3B-MTP-UD-Q6_K_XL.gguf
ctx-size = 262144
fit = true
fit-ctx = 262144
n-gpu-layers = 999
threads = 12
batch-size = 1536
ubatch-size = 384
cache-type-k = q8_0
cache-type-v = q8_0
temp = 0.7
top-p = 0.92
top-k = 40
min-p = 0.0
presence-penalty = 0.4
repeat-penalty = 1.04
jinja = true
chat-template-file = __CLUSTER_ROOT__/runtime-config/chat-templates/qwen3.5.jinja
reasoning = off
spec-type = draft-mtp
spec-draft-n-max = 6
```
