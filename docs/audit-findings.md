# Audit Findings — lac

Generated: 2026-04-26

> Historical note: this was an April audit snapshot. It is kept for traceability,
> but the current public-beta release blockers are tracked in
> `docs/release/gates.json`, `docs/release/MANUAL_VALIDATION.md`, and
> `RELEASE_CHECKLIST.md`. Use `./scripts/release-gate-report.sh` and
> `./scripts/release-evidence.sh <gate-id>` for current release work.

## CRITICAL

### C2. CI launch/*.sh glob is fragile

- **File:** `.github/workflows/ci.yml`, line 17
- **Problem:** `bash -n runtime-config/launch/*.sh` fails on Linux if the glob expands to nothing — the entire pipeline breaks with an unhelpful error.
- **Fix:** Replace with a loop guard: `for f in runtime-config/launch/*.sh; do [ -f "$f" ] && bash -n "$f"; done`
- **Status:** Resolved 2026-06-09 — guarded for loop in ci.yml

### C4. Plugin `opencode-antigravity-auth` has no docs

- **File:** `opencode.template.jsonc`, line 7
- **Problem:** The plugin array references an npm package with zero documentation on what it does, how to install it, or that it's required for Antigravity provider to work.
- **Fix:** Either document installation in `docs/providers/AUTHENTICATION.md` or remove from the template and add a comment explaining it must be installed separately.

---

## HIGH

### H1. Example template missing 7 model IDs

- **File:** `templates/opencode/opencode.example.jsonc`
- **Problem:** Missing `gemma-4-26b-a4b-q4`, `gemma-4-31b-b16`, `gemma-4-31b-q4`, `gemma-4-31b-q8`, `gemma-4-e4b-q8`, `minimax-m2.7`, `qwen3.5-9b-q4`. Users who copy-paste the example get errors when trying to use these models.
- **Fix:** Update example to match main config, or add a clear disclaimer and point users to `./bin/lac profile apply <profile>` for full configs.

### H2. Example template missing 4 provider blocks

- **File:** `templates/opencode/opencode.example.jsonc`
- **Problem:** Missing `anthropic`, `codex-auth`, `opencode-zen`, `opencode-go`. Legitimate cloud providers that users may reference when setting up their own config.
- **Fix:** Add stub provider blocks with minimal models and a comment.

### H5. Release checklist — 20 unchecked items

- **File:** `RELEASE_CHECKLIST.md`
- **Problem:** All gates unmet. No fresh-clone validation, no Windows PowerShell validation, no real OpenCode session testing, no PVR (Private Vulnerability Reporting) enabled.
- **Fix:** Prioritize the remaining release-blocking evidence gates: enable GitHub PVR, validate `python3 -m pip install .` plus `lac init` from a fresh clone, validate Windows PowerShell wrappers, collect llama.cpp and ds4 runtime smoke evidence, confirm real OpenCode discovery, and verify Linux CI.
- **Status:** Partially resolved 2026-06-30 — release gates are now tracked in `docs/release/gates.json`, `docs/release/MANUAL_VALIDATION.md`, and `RELEASE_CHECKLIST.md`. Keep this item open until `./scripts/release-gate-report.sh` exits successfully.

---

## MEDIUM

### M1. Example bash permissions too restrictive

- **File:** `templates/opencode/opencode.example.jsonc`, lines 98-109
- **Problem:** Example only allows `rg *`, `git status*`, `git diff*`. Main config allows `pwd`, `ls *`, `find *`, `sed *`, `cat *`, `head *`, `tail *`, etc. Users who copy the example will be frustrated by denied permissions.
- **Fix:** Align with main config or add a comment explaining the difference.

### M2. Free cloud model docs drift without automation

- **Files:** `docs/providers/OPENROUTER_FREE.md`, `docs/FREE_CLOUD_MODELS.md`
- **Problem:** These contain live data (last verified dates, model lists) but are manually maintained. The sync script `sync-free-cloud-models.sh` exists but there's no cron or CI step to run it automatically.
- **Fix:** Add a CI check that warns if these files are older than 7 days, or run the sync script as part of CI.

### M6. `switch-profile.sh` usage is hardcoded

- **File:** `scripts/switch-profile.sh`, line 5
- **Problem:** Usage string explicitly lists valid profiles. New profiles added to `profiles.json` won't appear here, causing confusing "Unknown argument" errors.
- **Fix:** Auto-generate usage from `profiles.json` or add a TODO comment requiring manual sync.

### M10. Foreground runtime mode doesn't handle Ctrl+C cleanly

- **File:** `scripts/lac.py`, lines 1220-1246
- **Problem:** In foreground mode, SIGINT (Ctrl+C) is sent to the child but the parent Python process may not clean up properly — PID file won't be deleted.
- **Fix:** Add a signal handler that forwards SIGINT to the child and cleans up on exit.

---

## LOW

### L7. Root `agents/` and `skills/` dirs may confuse contributors

- **Files:** `agents/README.md`, `skills/README.md`
- **Problem:** These are index-only directories pointing to `.opencode/agents` and `.opencode/skills`. New contributors may add agents to the wrong location.
- **Fix:** Add a prominent note in both READMEs: "DO NOT add agents here — use `.opencode/agents/` for runtime."

### L8. No `--version` flag on CLI

- **File:** `scripts/lac.py`, line 2131
- **Problem:** The argparse parser has no `--version` flag. Users need a way to know which version they're running, especially before public beta.
- **Fix:** Add `parser.add_argument("--version", action="version", version=f"lac {__version__}")` where `__version__` is defined at module level.

---

## Immediate Pre-Beta Actions

Current release blockers live in `docs/release/MANUAL_VALIDATION.md`. Run:

```bash
./scripts/release-gate-report.sh
./scripts/release-manual-next-steps.sh
./scripts/release-evidence.sh <gate-id>
```

Keep gates open until the requested evidence is captured and the matching
`RELEASE_CHECKLIST.md` item is checked.
