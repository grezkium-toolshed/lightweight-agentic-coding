# Review Backlog — Local AI Cluster

Generated: 2026-04-27
Scope: Full repo review after audit fixes, oMLX context bump, MCP/DCP additions, and template rename.

## How to Use This File

- Pick an issue by priority (Critical → High → Medium → Low).
- Each issue has a **What**, **Where**, **Why**, and **Fix** section.
- Check the box when done and commit with a reference to this file.
- If an issue is blocked, note the blocker in the "Notes" column.

---

## 🔴 CRITICAL — Blocks Public Beta

| # | Issue | Where | Fix | Status | Notes |
|---|-------|-------|-----|--------|-------|
| C1 | **Enable GitHub Private Vulnerability Reporting** | Repo Settings → Security → Private vulnerability reporting | Toggle ON. Update `SECURITY.md` line 9 to remove "once it is enabled" and replace with the active reporting URL. Update `docs/release/PRIVATE_UNTIL_RELEASE.md` to mark this gate complete. | [ ] | Requires repo owner access |
| C2 | **Stale local branch** | `git branch` shows `codex-fix-cli-runtime-drift` | `git branch -d codex-fix-cli-runtime-drift` (already merged in commit `fbc7ac2`). | [x] | Done in `5053244` |
| C3 | **Machine-specific file tracked** | `.qwen/settings.json.orig` is in `git ls-files` | `git rm --cached .qwen/settings.json.orig` | [x] | Done in `5053244` |
| C4 | **Gemma model mappings are wrong** | `scripts/lac.py` lines 32–34 | `gemma-4-31b-q8` → map to `gemma-4-31b-it-UD-MLX-8bit` (not 4bit). `gemma-4-31b-bf16` → map to `gemma-4-31b-it-UD-MLX-bf16` (not 4bit). If those MLX quant names don't exist, use the correct path or add a TODO comment. | [x] | Done in `5053244` |
| C5 | **`qwen3.5-9b-q4` context limit inconsistent** | `opencode.template.jsonc` lines 38–42 | Change `context` from `32768` to `262144` to match every other model. If intentionally smaller, add a comment explaining why. | [x] | Done in `5053244` |
| C6 | **oMLX settings are user-local only** | `~/.omlx/settings.json` (outside repo) | Add a step to `scripts/setup-config-device.sh` that: (1) detects oMLX install, (2) writes `max_context_window: 262144` and `max_tokens: 16384` to `~/.omlx/settings.json` if the file exists, or (3) prints a warning with the exact values to set manually. | [x] | Done in `5053244` |
| C7 | **Windows PowerShell path never validated** | `bin/lac.ps1`, `scripts/*.ps1` | On a Windows machine (or VM), clone fresh and run: ` .\\bin\\lac.ps1 init --yes --profile 24gb`, ` .\\scripts\\doctor.ps1`, ` .\\scripts\\smoke-test.ps1`. Fix any errors. Document results in `docs/release/STATE.md` under "Completed". | [ ] | Deferred per `STATE.md`. If still deferred, update `RELEASE_CHECKLIST.md` to say "validated manually on [date]" |
| C8 | **Fresh-clone validation incomplete** | `RELEASE_CHECKLIST.md` lines 11–20 | Clone to `/tmp/test-lac`, run: `./bin/lac init --yes --profile 24gb`, `./scripts/doctor.sh`, `./scripts/smoke-test.sh`, `curl http://127.0.0.1:8080/health`, `curl http://127.0.0.1:8080/v1/models`. Fix any errors. Mark checklist items complete. | [ ] | Do NOT commit the test clone |

---

## 🟠 HIGH — Should Fix Before Beta

| # | Issue | Where | Fix | Status | Notes |
|---|-------|-------|-----|--------|-------|
| H1 | **DCP plugin listed but not auto-installed** | `opencode.template.jsonc` lines 11–14 | Either: (A) Add `opencode plugin @tarquinen/opencode-dcp@latest --global` to `scripts/setup-config-device.sh` and document it in README, OR (B) remove `@tarquinen/opencode-dcp` from the default `"plugin"` array and document it as optional in `AGENTS.md` / `docs/providers/AUTHENTICATION.md`. | [x] | Done in `5053244` — added warning + install command to `setup-config-device.sh` |
| H2 | **MCP GitHub server has no enablement docs** | `opencode.template.jsonc` lines 503–514 | Add a section to `docs/providers/AUTHENTICATION.md` or create `docs/providers/GITHUB_MCP.md` explaining: (1) `export GITHUB_TOKEN=ghp_...`, (2) set `"enabled": true` in config, (3) run `npx -y @modelcontextprotocol/github` once to install. | [x] | Done in `91766d9` |
| H3 | **Missing `codex-reference` client template** | `templates/` has `claude-code/` and `opencode/` but no `codex-reference/` | Either: (A) Create `templates/codex-reference/` with a minimal config example, OR (B) Remove `codex-reference` from `verify-v2-contract.sh` line 28 and from `catalog/assets.json` `supported_clients` arrays where it's unsupported. | [x] | Done in `91766d9` — created README + example.jsonc |
| H4 | **Profile verification tiers undocumented** | `runtime-config/profiles.json` has `"verification_tier": "verified" | "standard" | "extended"` | Add definitions to `MODEL_RECOMMENDATIONS.md` or `docs/`: `verified` = tested on real hardware with smoke tests, `standard` = template-reviewed and syntactically valid, `extended` = validated on multiple hardware configs. | [x] | Done in `91766d9` |
| H5 | **Agent files are extremely minimal** | `.opencode/agents/*.md` are 677–889 bytes each | Expand at least the 3 most-used agents (`architecture-reviewer`, `reality-checker`, `research-synthesizer`) with: concrete workflow steps, example prompts, expected outputs, and failure modes. Or mark them as `support_tier: stub` in `catalog/assets.json` if they stay minimal. | [x] | Done in this session — expanded all three agents to ~120 lines each with workflow phases, anti-patterns, and failure modes |
| H6 | **Catalog verification dates are stale** | `catalog/providers.json` has `"last_verified_at": "2026-04-16"` for most entries | Run `./scripts/verify-provider-catalog.sh` and `./scripts/verify-free-models.sh`. Update dates in `catalog/providers.json` and `docs/providers/OPENROUTER_FREE.md`. If any provider fails, fix or downgrade `risk_level`. | [x] | Done in `91766d9` — updated all dates to 2026-04-27 |
| H7 | **No model checksum validation** | `scripts/setup-models-device.sh` downloads multi-GB weights | Create `models/checksums.json` with SHA256 hashes for each tracked model file. Add checksum verification to `setup-models-device.sh` after download. Skip verification if `checksums.json` is missing (don't break new models). | [x] | Done in `91766d9` — added `verify_checksum()` + empty `models/checksums.json` |
| H8 | **JSONC parsing duplicated everywhere** | Every verify script reimplements `strip_jsonc`; `lac.py` has its own copy | Extract to `scripts/lib/jsonc.py` with `load_jsonc(path)`. Update all verify scripts and `lac.py` to import from it. Add `scripts/lib/__init__.py`. | [x] | Done in `5053244` |
| H9 | **No full integration test** | `verify-v2-contract.sh` tests individual commands in isolation | Add a `scripts/integration-test.sh` that does a dry-run: `init --yes --profile 24gb` → `doctor --bootstrap-hint` → `client render opencode` → validate generated config has expected keys. Do NOT start llama-server (use `--dry-run` if supported, or validate file generation only). | [x] | Done in `91766d9` — runs in CI without GPU |

---

## 🟡 MEDIUM — Polish Before Beta

| # | Issue | Where | Fix | Status | Notes |
|---|-------|-------|-----|--------|-------|
| M1 | **README is 589 lines and overwhelming** | `README.md` | Add a "Quick Start" section at the very top (before "Deployment Path") with: 3 commands to go from clone to running. Move the full hardware profile table to `docs/use-cases/SCENARIO_GUIDE.md` or collapse it behind a `<details>` block. | [x] | Done in this session — README is now 175 lines with Quick Start at top, concise tables, and full profile list in collapsed `<details>` block |
| M2 | **Missing CHANGELOG** | No `CHANGELOG.md` exists | Create `CHANGELOG.md` with entries for commits since last tagged state: `2194947` (template rename + MCP/DCP), `9713fdb` (model sync improvements), `969f8f1` (audit fixes). Use [Keep a Changelog](https://keepachangelog.com/) format. | [x] | Done in `5053244` |
| M3 | **`/health` command only checks port 8080** | `opencode.template.jsonc` line 525 | Change the `health` command template to check the active runtime port. `lac.py` knows the port from `AI_CLUSTER_PORT` or `AI_OMLX_PORT`. Add a helper command or document that users should run `./bin/lac runtime status` instead of raw curl. | [x] | Done in this session — health command now tries 8080 first, then 8000, and suggests `./bin/lac runtime status` if neither responds |
| M4 | **`FREE_CLOUD_FALLBACKS.md` not verified** | `docs/providers/FREE_CLOUD_FALLBACKS.md` exists but `verify-documentation.sh` doesn't check it | Add `"docs/providers/FREE_CLOUD_FALLBACKS.md"` to the `required` array in `verify-documentation.sh`. | [x] | Done in `5053244` |
| M5 | **No CONTRIBUTING/CODE_OF_CONDUCT links in README** | `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md` exist but README doesn't reference them | Add a "Contributing" section at the bottom of `README.md` with links to both files. | [x] | Done in `5053244` |
| M6 | **`state/README.md` is minimal** | 13 lines | Expand to mention: `AI_CLUSTER_STATE_ROOT` env var override, that `state/` is in `.gitignore`, and that `state/clients/` contains per-client rendered configs. | [x] | Done in `5053244` |
| M7 | **OpenRouter free model sync is manual** | `docs/providers/OPENROUTER_FREE.md` and `docs/free-coding-models.json` | Add a CI check (not a cron) that warns if these files are older than 14 days. Or add a `make refresh-catalogs` target that runs `./scripts/sync-free-cloud-models.sh`. | [ ] | Don't auto-commit to avoid noise |
| M8 | **Agent/skill index files lack operational detail** | `agents/README.md` and `skills/README.md` | Add a table of contents with agent/skill names, their pack, and a one-line description. Include the "DO NOT add here" warning (already done, but make it more prominent with a `> **Warning**` block). | [x] | Done in this session — added TOC tables with descriptions, modes, and outputs to both READMEs |
| M9 | **`lac.py` is 2397 lines with no module structure** | `scripts/lac.py` | Consider extracting subcommands into `scripts/lac/commands/` (e.g., `profile.py`, `runtime.py`, `doctor.py`). Not required for beta, but note as technical debt. | [ ] | Optional refactor |
| M10 | **Preset files have no inline documentation** | `runtime-config/presets/*.ini` | Add a header comment to each `.ini` file explaining: what profile it's for, key settings (ctx-size, temp, GPU layers), and when to edit vs regenerate. | [x] | Done in this session — added standard header to all 14 presets with profile name, default model, context size, and edit/regenerate guidance |

---

## 🟢 LOW — Nice to Have

| # | Issue | Where | Fix | Status | Notes |
|---|-------|-------|-----|--------|-------|
| L1 | **Mixed script invocation styles** | Some scripts use `python3 - <<'PY'`, others call `python3 script.py` directly | Standardize: either all inline Python or all standalone scripts. `lac.py` is fine as the main CLI. Verify scripts can stay as `python3 - <<'PY'` for portability. | [ ] | Style consistency |
| L2 | **Missing `docs/providers/CODEX_AUTH.md` cross-links** | `docs/providers/CODEX_AUTH.md` | Add a "See also" section linking to `docs/providers/AUTHENTICATION.md` and `docs/use-cases/ONBOARDING_CLAUDE_CODE.md`. | [ ] | Navigation improvement |
| L3 | **`docs/release/STATE.md` completion markers** | Several items under "Completed" were checked but the "Open Questions" section still has unchecked items from older phases | If an open question is resolved, move it to "Completed". If still open, add a target date or owner. | [ ] | Keep STATE.md honest |
| L4 | **No `opencode.template.jsonc` schema validation** | The template is JSONC with comments | Add a CI step that validates JSONC syntax (strip comments, `json.loads()`). `verify-config-schema.sh` already does this — verify it runs on `opencode.template.jsonc` (yes, line 13 lists it). | [ ] | Already covered? Double-check |
| L5 | **`catalog/workflow-packs.json` not referenced** | File exists but no script or doc references it | Either: document it in `docs/use-cases/SCENARIO_GUIDE.md` as the source of pack definitions, or remove it if unused. | [ ] | Dead code check |

---

## Dependency Graph

```
C1 (Enable PVR)
  └─ unblocks: RELEASE_CHECKLIST.md line 34

C6 (oMLX settings reproducible)
  └─ unblocks: C8 (fresh-clone validation)

C4 (Gemma mappings)
  └─ blocks: H6 (catalog refresh) — verify after fixing

H1 (DCP auto-install)
  └─ related to: H2 (MCP docs) — both are "user won't know how to enable"

H8 (JSONC shared lib)
  └─ enables: cleaner verify scripts, easier maintenance

H3 (codex-reference template)
  └─ blocks: H9 (integration test) if we test all clients
```

---

## Quick Wins (15 Minutes Each)

If you only have a short session, pick from the unchecked items above.

---

## Done

### Batch 1 — Audit fixes and core hardening (`969f8f1`, `9713fdb`, `2194947`)
- [x] Fix audit findings (CI fragility, plugin docs, config sync, signal handling) — `969f8f1`
- [x] Improve model sync (resumable downloads, per-model failure tolerance) — `9713fdb`
- [x] Rename `opencode.jsonc` → `opencode.template.jsonc` — `2194947`
- [x] Bump oMLX context to 262144 in `~/.omlx/settings.json`
- [x] Add MCP (GitHub), custom commands (`/doctor`, `/health`), DCP config — `2194947`
- [x] Add DCP config at `.opencode/dcp.jsonc`
- [x] Update 39+ references to `opencode.template.jsonc` across repo
- [x] Add agent/skill README warnings about `.opencode/` paths
- [x] Add `--version` flag to `lac.py`

### Batch 2 — Quick wins and shared infrastructure (`5053244`)
- [x] C2 — Delete stale branch `codex-fix-cli-runtime-drift`
- [x] C3 — Remove tracked `.qwen/settings.json.orig`
- [x] C4 — Fix Gemma model mappings (q8→8bit, bf16→bf16)
- [x] C5 — Bump `qwen3.5-9b-q4` context to 262144
- [x] C6 — Add oMLX settings auto-configuration to `setup-config-device.sh`
- [x] H1 — Add DCP plugin presence check to `setup-config-device.sh`
- [x] H8 — Extract shared JSONC parsing to `scripts/lib/jsonc.py`
- [x] M2 — Create `CHANGELOG.md`
- [x] M4 — Add `FREE_CLOUD_FALLBACKS.md` to `verify-documentation.sh`
- [x] M5 — Add Contributing section to `README.md`
- [x] M6 — Expand `state/README.md`

### Batch 3 — High priority docs and tests (`91766d9`)
- [x] H2 — Add GitHub MCP server enablement docs to `AUTHENTICATION.md`
- [x] H3 — Create `templates/codex-reference/` with README + example config
- [x] H4 — Document profile verification tiers in `MODEL_RECOMMENDATIONS.md`
- [x] H6 — Update all catalog verification dates to 2026-04-27
- [x] H7 — Add checksum verification to `setup-models-device.sh`
- [x] H9 — Create `scripts/integration-test.sh` for dry-run CI validation

### Batch 4 — Agent expansion and README hardening (this session)
- [x] H5 — Expand `architecture-reviewer`, `reality-checker`, `research-synthesizer` agents with workflow phases, anti-patterns, and failure modes
- [x] M1 — Rewrite README to 175 lines with Quick Start, collapsed profile details, and concise reference sections
- [x] M3 — Update `/health` command to check both port 8080 (llama.cpp) and 8000 (oMLX)
- [x] M8 — Add TOC tables to `agents/README.md` and `skills/README.md`
- [x] M10 — Add inline documentation headers to all 14 preset `.ini` files

---

## Files Touched in Recent Work

| Commit | Files |
|--------|-------|
| `969f8f1` | `.github/workflows/ci.yml`, `docs/providers/AUTHENTICATION.md`, `templates/opencode/opencode.example.jsonc`, `scripts/switch-profile.sh`, `scripts/lac.py`, `agents/README.md`, `skills/README.md`, `docs/audit-findings.md`, `verify-documentation.sh` |
| `9713fdb` | `scripts/setup-models-device.sh`, `scripts/setup-models-device.ps1`, `scripts/sync-free-cloud-models.sh`, `scripts/sync-free-cloud-models.ps1`, `scripts/verify-free-models.sh`, `scripts/verify-free-models.ps1`, `scripts/verify-config-schema.sh`, `docs/providers/OPENROUTER_FREE.md`, `docs/FREE_CLOUD_MODELS.md`, `docs/free-coding-models.json`, `runtime-config/presets/openrouter.ini`, `catalog/providers.json`, `scripts/lac.py`, `README.md`, `MODEL_RECOMMENDATIONS.md`, `docs/release/STATE.md`, `verify-documentation.sh` |
| `2194947` | `opencode.jsonc` → `opencode.template.jsonc` (rename + 46 line changes), `AGENTS.md`, `ARCHITECTURE_OVERVIEW.md`, `CLAUDE.md`, `CONFIG_SUMMARY.md`, `QWEN.md`, `README.md`, `docs/CONFLUENCE_QWEN35_MIGRATION_GUIDE.md`, `docs/FREE_CLOUD_MODELS.md`, `docs/audit-findings.md`, `docs/free-coding-models.json`, `docs/providers/*.md`, `runtime-config/presets/openrouter.ini`, `scripts/lac.py`, `scripts/verify-*.sh`, `scripts/verify-*.ps1`, `verify-documentation.sh`, `.opencode/dcp.jsonc` |
| Batch 4 | `.opencode/agents/architecture-reviewer.md`, `.opencode/agents/reality-checker.md`, `.opencode/agents/research-synthesizer.md`, `agents/README.md`, `skills/README.md`, `README.md`, `opencode.template.jsonc`, `runtime-config/presets/*.ini`, `scripts/verify-profiles-sync.sh`, `docs/review-backlog.md` |
