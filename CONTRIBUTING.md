# Contributing

## Scope

This repository is a battery-included setup for local agentic coding with OpenCode + llama.cpp.
Contributions should preserve portability and reproducibility.
Contributions are welcome — please follow the checks below before submitting a PR.

## Local Checks Before PR

Run the local validation before submitting a change:

```bash
./scripts/verify.sh            # shell syntax, config/provider schema, package staging, licensing guard
./scripts/integration-test.sh  # full CLI workflow, no GPU or network
./scripts/verify-package-build.sh  # clean wheel/sdist and installed-package smoke
```

The GitHub compatibility workflow is manual-only and optional. It can reproduce Linux, macOS, or
Windows packaging/configuration issues, but it is not a substitute for local checks or physical
hardware validation.

Then regenerate profile config and run doctor:

```bash
./bin/lac profile apply 24gb
./bin/lac doctor --bootstrap-hint
```

## Contribution Rules

- Do not commit model binaries (`*.gguf`) or local caches.
- Do not commit generated runtime state (`state/runtime/presets.active.ini`, `state/active/profile.txt`, `state/clients/opencode/opencode.json`, logs, PID files, or reports).
- Do not commit local tool state from `.qwen/` or `.claude/`.
- Do not edit `src/lac/data/` — it is generated from the top-level trees at build time (see below). Edit the canonical top-level files instead.
- Keep both Unix (`.sh`) and Windows (`.ps1`) parity when changing workflows.
- Keep llama.cpp as the default runtime path; specialist profiles may opt into runtimes such as oMLX or ds4 explicitly.
- Prefer additive profile changes over hardcoded machine-specific paths.
- Keep `.opencode/agents/` and first-party `.opencode/skills/` intentionally small and task-focused. Third-party design skills/systems are opt-in fetch (`od mcp install opencode`), not vendored here.

## Data staging (one source of truth)

The canonical config/asset trees live at the repo top level: `runtime-config/`, `catalog/`,
`opencode.template.jsonc`, and `.opencode/`. The installed package needs a copy under
`src/lac/data/`, so `scripts/stage_data.py` regenerates that copy at build time (invoked from
`setup.py`). `src/lac/data/` is gitignored — never hand-edit or commit it. To refresh it locally,
run `./scripts/stage-data.sh` (or `python3 scripts/stage_data.py`).

## Script Style

- Keep public helper entrypoints as shell or PowerShell wrappers: `./scripts/*.sh`, `./bin/lac`, and `./bin/lac.ps1` should be directly runnable from a clean checkout.
- The CLI lives in `src/lac/` (entry point `lac.cli:main`). For small validation helpers, prefer inline Python in the wrapper (`python3 - <<'PY'`) and shared imports from `scripts/lib/`.
- Inline Python in verification helpers should avoid syntax newer than the macOS system Python.
