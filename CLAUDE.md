# Guidance for Claude Code sessions on this repo

This repo is a **Local AI Cluster**: llama.cpp + Qwen 3.6 MoE / Gemma 4 baseline with OpenCode as the lead client. The v2 CLI at `./bin/lac` is the supported control plane.

Branding is `local-ai-cluster`; filesystem slug is still `ai-coding-cluster` during transition — don't "fix" that.

## Primary CLI

All onboarding and maintenance flows through `./bin/lac` (or `./bin/lac.ps1` on Windows). Key subcommands:

- `lac init [--yes --profile <id> [--cloud <ids>] [--no-cloud]]` — interactive wizard; stops before downloading weights
- `lac profile list|apply <id>`
- `lac models sync <profile>` — downloads weights
- `lac runtime start|status|stop`
- `lac client render|open <target>` (`opencode` | `claude-code` | `codex-reference`)
- `lac pack list|show <pack>` / `lac scenario list|show <scenario>` — browse catalogs
- `lac provider list|status|verify <id> [--all] [--refresh-catalog]` — reachability probe
- `lac doctor [--strict]` / `lac smoke`

Every command accepts a top-level `--json`. Human output is the default; JSON is byte-identical to what gets written under `state/reports/`.

## Source vs generated

- **Source (tracked, edit freely):** `opencode.template.jsonc`, `runtime-config/presets/*.ini`, `runtime-config/profiles.json`, `catalog/*.json`, `.opencode/agents/*`, `.opencode/skills/*`, `templates/*`, docs
- **Generated (don't hand-edit):** everything under `state/` — `state/active/`, `state/runtime/presets.active.ini`, `state/clients/<target>/`, `state/logs/`, `state/reports/`

`AI_CLUSTER_STATE_ROOT` overrides the state root — used by tests and the contract script.

## Verification scripts (run before committing code changes)

```bash
./scripts/verify-v2-contract.sh       # CLI contract + init + provider verify
./verify-documentation.sh             # tracked doc presence and consistency
./scripts/verify-opencode-assets.sh   # agent/skill schema
./scripts/verify-provider-catalog.sh  # catalog/providers.json schema
./scripts/verify-config-schema.sh     # opencode.template.jsonc schema
./scripts/verify-profiles-sync.sh     # profile manifest parity across scripts + README
```

All six must pass locally. GitHub Actions is currently red — rely on local signal.

## Hard constraints

- **stdlib-only** in `scripts/lac.py` (urllib, json, argparse, pathlib) — no new deps
- **`--json` output shape is stable** — don't change existing keys without bumping the contract
- **Secrets never logged** — provider verify prints env var *names* and a boolean, never values
- **Read-only by default** — only `--refresh-catalog` writes to `catalog/providers.json`; `profile apply` / `init` write only under `state/`

## Where to look

- Architecture: `ARCHITECTURE_OVERVIEW.md`
- CLI contract: `CONFIG_SUMMARY.md`
- Release gates: `RELEASE_CHECKLIST.md`, `docs/release/STATE.md`
- Provider auth + verify: `docs/providers/AUTHENTICATION.md`
- Free-model snapshot: `docs/FREE_CLOUD_MODELS.md`, `docs/free-coding-models.json`

## Conventions

- Commits: short imperative subject; body explains *why*, not *what*
- Prefer editing existing files over creating new ones; docs over new docs
- Human-readable renderers go through `emit(..., kind=...)` in `scripts/lac.py`
- New providers: add to `catalog/providers.json` **and** `opencode.template.jsonc` **and** `PROVIDER_VERIFICATION` in `scripts/lac.py` — all three must agree
