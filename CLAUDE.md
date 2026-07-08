# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`lac` (Lightweight Agentic Coding) is a Python CLI that orchestrates a fully local AI coding setup: it detects hardware, picks a model profile, downloads GGUF weights, manages a local inference runtime (llama.cpp `llama-server`, with optional oMLX / ds4 backends), and renders config for clients like OpenCode and OpenChamber. Cloud providers (OpenRouter, Anthropic, NVIDIA NIM) are optional overlays/fallbacks. Nothing leaves the machine unless a cloud provider is configured.

The package is `lac` (import name), distributed as `lightweight-agentic-coding`. Console entry point: `lac = lac.cli:main`. Runs on Python 3.10+.

## Commands

Two ways to invoke the CLI:
- `./bin/lac <cmd>` — repo-local dev wrapper, runs from the source tree (adds `src/` to `PYTHONPATH`, picks the newest Python 3.10+). Use this during development. Windows: `./bin/lac.ps1`.
- `lac <cmd>` — after `python3 -m pip install .`.

All commands accept `--json` for machine-readable output.

Core lifecycle: `lac init` (hardware detection + onboarding), `lac models sync [profile]`, `lac profile apply <profile>`, `lac runtime start|stop|status`, `lac client open opencode|openchamber`, `lac doctor [--strict] [--fix]`, `lac smoke`, `lac bench`.

### Tests and checks

There is **no pytest suite**. CI (`.github/workflows/ci.yml`, Linux) runs exactly two scripts:

```bash
./scripts/verify.sh              # shell syntax, config/provider schema, package-data staging, licensing guard
./scripts/integration-test.sh    # full CLI workflow, no llama-server (uses a temp LAC_STATE_ROOT)
```

`verify.sh` orchestrates the kept sub-checks (`verify-config-schema.sh`, `verify-provider-catalog.sh`) plus a licensing guard that fails if any un-shippable third-party skill or vendored asset tree leaks into the wheel. The integration test is the closest thing to a unit-test run — it exercises `profile apply`, config generation, doctor, provider/pack commands, etc., against a throwaway state root without a GPU or running server.

## Architecture

### CLI structure

`src/lac/` is the single, modular, packaged CLI (`lac.cli:main`). `src/lac/cli.py` owns argument parsing (`build_parser`), dispatch (`main`), and the `emit()` text/JSON renderer. Each subsystem is its own module: `profiles`, `models`, `runtime`, `providers`, `config` (renders OpenCode config), `clients`, `packs`, `scenarios`, `catalog`, `init`, `doctor`, `bench`, `render` (human-readable output formatting). Shared JSONC parsing lives in `src/lac/lib/jsonc.py`.

### Config / state / data model

`src/lac/context.py` is the spine. `Context` resolves every path through `_find_repo_root()`, which searches upward for `runtime-config/profiles.json`:

- **Running from the repo** → root is the checkout; the canonical source-of-truth files are the top-level `runtime-config/`, `catalog/`, `opencode.template.jsonc`, `.opencode/agents`, `.opencode/skills`.
- **Running pip-installed** → root is the bundled `src/lac/data/`.

**`src/lac/data/` is generated, not hand-maintained.** It is gitignored; `scripts/stage_data.py` (invoked from `setup.py` at build time) copies the canonical top-level trees into it so the wheel ships them. Never edit or commit `src/lac/data/` — edit the top-level files and, if you need a fresh local copy, run `./scripts/stage-data.sh`.

Three kinds of files, never conflated:
- **Source (committed):** `runtime-config/profiles.json`, `runtime-config/presets/<profile>.ini`, `catalog/*.json`, `opencode.template.jsonc`, `.opencode/`.
- **Generated state (git-ignored, under `state/`):** `state/active/profile.txt`, `state/runtime/presets.active.ini`, `state/clients/opencode/opencode.json`, logs, PID files, reports. Regenerate with `lac profile apply <profile>`. Never commit these.
- **Runtime override:** `LAC_STATE_ROOT` relocates the entire `state/` tree (the integration test uses this to sandbox).

### Profiles

A profile ties a hardware bucket to a model set and runtime. Definitions live in `runtime-config/profiles.json` (metadata) and `src/lac/models.py` (download specs, `CLOUD_PROFILES`). Keep the profile id sets in `profiles.json`, `models.py`, `scenarios.json`, and the README table in agreement — adding a profile means editing all of these together. Default local runtime is llama.cpp; `micro` is a tiny CPU demo; `openrouter`/`opencode-go` are cloud-only; specialist profiles opt into `omlx` (Apple Silicon MLX) or `ds4` (DeepSeek V4 Flash on 128GB+; the Apple Silicon path targets the maintainer's Mac Studio / Mac Pro, the DGX Spark / CUDA path is community-validated).

### Runtime

`src/lac/runtime.py` starts/stops the local server, tracks PID + JSON state files per backend under `state/runtime/`, and polls `/health`, `/v1/models`, `/v1/chat/completions`. `selected_local_runtime(profile)` chooses llama.cpp / omlx / ds4. Default host/port `127.0.0.1:8080` (override with `LAC_HOST` / `LAC_PORT`).

### Environment variables

`LAC_*` names are current; `AI_CLUSTER_*` names are deprecated aliases still honored with a stderr warning (see `_env_or_deprecated`). Key ones: `LAC_STATE_ROOT`, `LAC_HOST`, `LAC_PORT`, `AI_MODELS_DIR`, `LAC_INSTALL_DCP`, provider keys like `OPENROUTER_API_KEY` / `NVIDIA_API_KEY`.

## Conventions

- **Shell/PowerShell parity:** every user-facing workflow change must touch both the `.sh` and `.ps1` variant (`bin/lac` + `bin/lac.ps1`, `runtime-config/launch/*`, `scripts/stage-data.*`).
- **Script style:** public entrypoints stay as shell/PowerShell wrappers runnable from a clean checkout. For small validation helpers, prefer inline Python (`python3 - <<'PY'`) importing from `scripts/lib/`; reserve standalone `.py` files for the CLI, shared library modules, and `scripts/stage_data.py`. Inline Python in verification helpers must run under the macOS system Python (avoid newer syntax).
- **Style:** 2-space indent, no tabs, LF endings; kebab-case or snake_case filenames; JSONC allows `//` comments; INI sections lowercase-and-hyphens.
- **OpenCode assets:** skills live at `.opencode/skills/<name>/SKILL.md`; agents are narrow, operational markdown under `.opencode/agents/`. Only first-party (and correctly-attributed MIT) assets are bundled; third-party design skills/systems are opt-in fetch, not vendored (`verify.sh` guards this). Authoring guide: `docs/skills/AUTHORING.md`; templates under `templates/`.
- **Never commit:** `*.gguf` model binaries, anything under `state/`, generated `src/lac/data/`, the internal `dev/` folder, or local tool state (`.qwen/`, `.claude/`).
- Prefer additive profile changes over hardcoded machine-specific paths. Keep llama.cpp as the default runtime path.

Internal working notes (plans, backlog, release checklists) live in the gitignored `dev/` folder, out of the public tree.
