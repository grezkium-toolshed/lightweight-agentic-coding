# Migration Plan: From Scripts to Installable Package

## Context

The repo currently relies on `scripts/lac.py` (2631 lines) plus 14 `.sh`/`.ps1` script pairs for setup, verification, model downloads, and runtime management. Nothing is installable — users must `git clone` and run from the repo root.

## Goals

1. Make the CLI installable via `pip install .` on all platforms
2. Break the monolith into testable, maintainable modules
3. Eliminate shell/PowerShell duplication — Python handles cross-platform logic
4. Keep a single thin PowerShell bootstrap for Windows initial install only
5. Preserve all existing commands and behavior (backward compatible)

## Windows Strategy

**Ditch PowerShell script duplication.** Python is already cross-platform. After `pip install`, Windows users run `lac` directly from any shell (PowerShell, cmd, terminal). The only PowerShell we keep is a one-liner bootstrap:

```powershell
py -m pip install .
```

No more `.ps1` mirrors of `.sh` scripts. No more parity checks. The `bin/lac` bash wrapper also becomes unnecessary after install but stays for repo-local dev use.

---

## Phase 1: Make It Installable

**Goal:** `pip install .` works. `lac` is on PATH. Zero behavior changes.

### Steps

1. **Create `pyproject.toml`** at repo root
   - Project name: `lightweight-agentic-coding` (or `lac`)
   - Version: `0.1.0` (match current `VERSION` in `lac.py`)
   - Python requires: `>=3.10`
   - Console script entry point: `lac = "lac.cli:main"`
   - No external dependencies (stdlib only)
   - Include `catalog/`, `runtime-config/`, `.opencode/`, `opencode.template.jsonc` as package data

2. **Create `src/lac/` package layout**
   ```
   src/lac/
     __init__.py        # VERSION constant
     __main__.py        # python -m lac support
   ```
   - `__init__.py` exports `VERSION = "0.1.0"`
   - `__main__.py` calls `main()` from the CLI module

3. **Move `scripts/lac.py` → `src/lac/cli.py`**
   - Keep it as a single file for now — just relocate
   - Update imports: `from lib.jsonc` → `from lac.lib.jsonc`
   - Update `ROOT` resolution: use `importlib.resources` or `__file__` relative to installed package
   - Keep `scripts/lac.py` as a thin redirect during transition: `exec python3 src/lac/cli.py "$@"`

4. **Move `scripts/lib/` → `src/lac/lib/`**
   - `jsonc.py` moves with updated imports in `cli.py`

5. **Verify install works**
   - `pip install -e .` from repo root
   - `lac --version` works from any directory
   - `lac doctor`, `lac profile list` work from repo root
   - `bin/lac` still works for repo-local dev

6. **Update `.gitignore`** if needed (e.g., `*.egg-info/`, `dist/`, `build/`)

### Verification

- [ ] `pip install -e .` succeeds on macOS/Linux
- [ ] `lac --version` prints `0.1.0`
- [ ] `lac doctor` runs from repo root
- [ ] `lac profile list` returns profiles
- [ ] `bin/lac doctor` still works (backward compat)
- [ ] CI still passes

---

## Phase 2: Break Up the Monolith

**Goal:** `cli.py` shrinks from 2631 lines to ~200 lines of argument parsing and dispatch. All logic lives in focused modules.

### Target Layout

```
src/lac/
  __init__.py          # VERSION
  __main__.py          # python -m lac
  cli.py               # argparse, main(), emit() dispatch
  context.py           # Context class, path resolution, ROOT detection
  runtime.py           # start/stop/status, llama.cpp + oMLX lifecycle
  profiles.py          # apply, list, recommend, detect hardware, RAM buckets
  providers.py         # verification, catalog refresh, readiness, URL resolution
  models.py            # model sync, download logic (ported from setup-models-device.sh)
  skills.py            # optional skill install/remove/verify (msgraph)
  config.py            # opencode config rendering, preset rendering
  init.py              # init wizard, prompts, readiness checks
  packs.py             # workflow packs, asset catalog, pack summaries
  scenarios.py         # scenario catalog list/show
  clients.py           # render_client, client_open (opencode, claude-code, codex-reference)
  lib/
    jsonc.py           # JSONC loader
```

### Module Responsibilities

| Module | Functions moved from `cli.py` |
|--------|-------------------------------|
| `context.py` | `Context` class, `ROOT`, `STATE_ROOT`, path mappings |
| `runtime.py` | `runtime_start`, `runtime_stop`, `runtime_status`, `collect_runtime_status`, `runtime_paths`, `selected_local_runtime`, `_profile_supports_omlx`, `_normalize_local_runtime` |
| `profiles.py` | `profile_apply`, `profile_list`, `render_preset`, `recommend_profile`, `family_alternatives`, `detect_hardware`, `detect_total_ram_gb`, `RAM_BUCKETS`, `_bucket_for_ram` |
| `providers.py` | `verify_provider`, `verify_all_providers`, `refresh_provider_catalog`, `provider_list`, `provider_models`, `provider_status`, `collect_provider_readiness`, `PROVIDER_VERIFICATION`, `_verify_provider_record`, `_resolve_verify_endpoint`, `_get_provider_entry`, `_opencode_base_urls`, `_openrouter_is_free_model`, `parse_openrouter_models_response` |
| `models.py` | Model download logic ported from `setup-models-device.sh`: `download_one`, `download_mlx_repo`, `should_stage_mlx`, `verify_checksum`, profile→model mapping |
| `skills.py` | `install_optional_skill`, `remove_optional_skill`, `optional_skill_status`, `verify_optional_skill`, `OPTIONAL_SKILLS`, `_copy_optional_skill_*`, `_extract_zip_safely` |
| `config.py` | `render_opencode_config`, `LOCAL_MLX_MODEL_IDS`, `_build_opencode_model_entry`, `_inject_provider_catalog_models`, `_openrouter_catalog_models`, `_fetch_openrouter_free_models`, `_normalize_openrouter_catalog_models`, `_catalog_model_*`, `_resolve_catalog_selector` |
| `init.py` | `init_wizard`, `_init_prerequisites`, `_init_readiness`, `_init_status`, `_next_steps`, `_init_recommendation`, `_parse_cloud_arg`, `_validate_cloud_ids`, `_prompt_*`, `CLOUD_PROVIDER_HINTS`, `FAMILY_DESCRIPTIONS`, `render_init_text`, `_render_init_section` |
| `packs.py` | `build_pack_summary`, `pack_list`, `pack_show`, `render_pack_list`, `render_pack_show`, `load_asset_catalog`, `load_workflow_catalog` |
| `scenarios.py` | `scenario_list`, `scenario_show`, `render_scenario_list`, `render_scenario_show` |
| `clients.py` | `render_client`, `client_open`, `_render_verify_row`, `render_provider_verify_*`, `render_provider_list`, `render_provider_models`, `render_provider_status` |
| `cli.py` (remaining) | `build_parser`, `main`, `emit`, `render_*` text formatters, `write_text`, `write_json`, `read_text`, `request_json`, `is_pid_running`, `command_exists`, `_strip_global_json_flag`, `log_info`, `as_runtime_path`, `_host_install_platform`, `_install_hint`, `utc_now`, `write_runtime_state` |

### Extraction Order

1. `lib/jsonc.py` — already separate, just relocate
2. `context.py` — no dependencies, pure data class
3. `profiles.py` — depends on `context`
4. `config.py` — depends on `context`, `profiles`
5. `runtime.py` — depends on `context`, `profiles`
6. `providers.py` — depends on `context`, `config`
7. `packs.py` — depends on `context`
8. `scenarios.py` — depends on `context`
9. `clients.py` — depends on `context`, `packs`
10. `skills.py` — depends on `context`
11. `models.py` — depends on `context` (port shell logic here)
12. `init.py` — depends on `profiles`, `providers`, `config`, `runtime`
13. `cli.py` — wires everything together

### Verification

- [ ] Each module imports independently
- [ ] `lac` commands all work identically to before
- [ ] No regression in `lac doctor`, `lac runtime start`, `lac init`, etc.
- [ ] CI passes

---

## Phase 3: Eliminate Shell Duplication

**Goal:** All logic lives in Python. Shell scripts become thin compatibility shims or are removed.

### Steps

1. **Port `setup-models-device.sh` → `lac models sync`**
   - The Python `models.py` module already handles this (from Phase 2)
   - Profile→model mapping moves from shell `case` statement into Python data structure
   - Checksum verification, resume downloads, HF CLI detection, MLX repo staging — all in Python
   - `bin/lac models sync <profile>` becomes the single entry point

2. **Port `setup-config-device.sh` → `lac setup` or fold into `lac init`**
   - oMLX settings update → Python `config.py` function
   - DCP plugin install → Python `skills.py` or new `plugins.py`
   - `lac setup <profile>` runs profile apply + oMLX config + DCP install

3. **Port `verify-free-models.sh` → `lac provider verify-models`**
   - Already partially covered by `provider verify`
   - Add a `--check-models` flag that does the chat completion probe

4. **Port `sync-free-cloud-models.sh` → `lac catalog sync-free`**
   - Fetch upstream JS, parse, write JSON + markdown
   - All in Python, no heredoc tricks

5. **Thin out remaining `.sh` scripts**
   - `doctor.sh` → `exec lac doctor "$@"` (5 lines → 3 lines)
   - `smoke-test.sh` → `exec lac smoke "$@"`
   - `switch-profile.sh` → `exec lac profile apply "$2"` (or just tell users to use `lac`)
   - `launch-llama.sh` → `exec lac runtime start`
   - `launch-opencode.sh` → `exec lac client open opencode`

6. **Remove `.ps1` duplicates entirely**
   - `doctor.ps1`, `smoke-test.ps1`, `setup-config-device.ps1`, etc. — all deleted
   - Windows users run `lac` directly after `pip install`

7. **Keep `bin/lac` and `bin/lac.ps1` as repo-local dev wrappers**
   - `bin/lac` → `exec python3 -m lac "$@"` (uses repo source, not installed)
   - `bin/lac.ps1` → `python -m lac $args` (same purpose for Windows dev)
   - These are for developers working on the repo, not end users

8. **Remove `verify-profiles-sync.sh`**
   - No more shell/Python parity to check
   - Replace with a simpler check: profiles in `profiles.json` match `models.py` model map

### Verification

- [ ] `lac models sync 24gb` downloads models (same as old `setup-models-device.sh`)
- [ ] `lac setup 24gb` configures device (same as old `setup-config-device.sh`)
- [ ] All `.ps1` files removed from repo
- [ ] `.sh` scripts are thin shims or removed
- [ ] CI passes without `verify-profiles-sync.sh`
- [ ] Windows: `py -m pip install .` then `lac doctor` works

---

## Phase 4: Distribution and Polish

**Goal:** Users can install without cloning the repo.

### Steps

1. **Publish to PyPI** (optional, private or public)
   - `pip install lightweight-agentic-coding`
   - Requires deciding on public vs. private index
   - Package must include catalog JSON, templates, presets as package data

2. **Alternative: standalone binary**
   - Use `shiv` or `pex` to build a single-file executable
   - `curl -fsSL https://.../lac -o /usr/local/bin/lac`
   - No Python install required on target machine

3. **Homebrew tap** (macOS)
   - `brew install lightweight-agentic-coding/tap/lac`
   - Installs `lac` binary + optionally bundles llama.cpp

4. **Windows installer**
   - Simple PowerShell one-liner: `py -m pip install lightweight-agentic-coding`
   - Or a `.msi` / winget package if warranted

5. **Update README**
   - Installation section replaces "clone and run"
   - `pip install` as primary path
   - `git clone` as development path

### Verification

- [ ] `pip install lightweight-agentic-coding` works on clean machine
- [ ] `lac --version` works without repo checkout
- [ ] All commands work from arbitrary working directory
- [ ] Package data (catalogs, presets, templates) accessible at runtime

---

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| `ROOT` resolution breaks after install | Use `importlib.resources` or `importlib.metadata` for package data, not `__file__` relative paths |
| Model download logic is shell-heavy | Port carefully; test resume, checksum, HF CLI fallback paths |
| Breaking existing workflows | Keep `bin/lac` working throughout; add deprecation warnings to old script paths |
| Windows path handling | Test on Windows early; use `pathlib` consistently, not string concatenation |

## Timeline Estimate

| Phase | Effort |
|-------|--------|
| Phase 1: Packaging | 1-2 hours |
| Phase 2: Monolith breakup | 4-6 hours |
| Phase 3: Shell elimination | 3-4 hours |
| Phase 4: Distribution | 2-4 hours (depends on PyPI/brew decisions) |

Total: ~10-16 hours of focused work.
