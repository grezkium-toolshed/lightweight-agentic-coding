# Contributing

## Scope

This repository is a battery-included setup for local agentic coding with OpenCode + llama.cpp.
Contributions should preserve portability and reproducibility.
Contributions are welcome — please follow the checks below before submitting a PR.

## Local Checks Before PR

For public-beta work, prefer the one-command local gate:

```bash
./scripts/verify-public-beta-local.sh
```

This runs the local automated checks and summarizes any manual release gates that still require external evidence.

For smaller changes, run the relevant focused checks below.

1. Run shell syntax checks:

```bash
bash -n scripts/*.sh
bash -n verify-*.sh
bash -n runtime-config/launch/*.sh
```

2. Run offline contract checks:

```bash
./scripts/verify-config-schema.sh
./scripts/verify-profiles-sync.sh
./scripts/verify-opencode-assets.sh
./scripts/verify-provider-catalog.sh
./verify-documentation.sh
```

3. Regenerate profile config and run doctor:

```bash
./bin/lac profile apply 24gb
./bin/lac doctor --bootstrap-hint
```

## Contribution Rules

- Do not commit model binaries (`*.gguf`) or local caches.
- Do not commit generated runtime state (`state/runtime/presets.active.ini`, `state/active/profile.txt`, `state/clients/opencode/opencode.json`, logs, PID files, or reports).
- Do not commit local tool state from `.qwen/` or `.claude/`.
- Keep both Unix (`.sh`) and Windows (`.ps1`) parity when changing workflows.
- Keep llama.cpp as the default runtime path; specialist profiles may opt into runtimes such as oMLX or ds4 explicitly.
- Prefer additive profile changes over hardcoded machine-specific paths.
- Keep `.opencode/agents/` and `.opencode/skills/` intentionally small and task-focused.

## Script Style

- Keep public helper entrypoints as shell or PowerShell wrappers: `./scripts/*.sh`, `./bin/lac`, and `./bin/lac.ps1` should be directly runnable from a clean checkout.
- For small validation and release helpers, prefer inline Python in the wrapper (`python3 - <<'PY'`) and shared imports from `scripts/lib/`. This keeps the command surface portable while avoiding duplicated parsers.
- Reserve standalone Python files for the main CLI (`scripts/lac.py`) and shared library modules under `scripts/lib/`.
- Inline Python used by local verification helpers should avoid syntax newer than the macOS system Python used by the public-beta smoke path.
