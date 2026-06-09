# Contributing

## Scope

This repository is a battery-included setup for local agentic coding with OpenCode + llama.cpp.
Contributions should preserve portability and reproducibility.
The repo is still in pre-beta — public contributions welcome once release gates are complete.

## Local Checks Before PR

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
./verify-documentation.sh
```

3. Regenerate profile config and run doctor:

```bash
./scripts/setup-config-device.sh --profile 24gb
./scripts/doctor.sh --bootstrap-hint
```

## Contribution Rules

- Do not commit model binaries (`*.gguf`) or local caches.
- Do not commit generated runtime state (`runtime-config/presets.active.ini`, `runtime-config/active-profile.txt`, `runtime-config/opencode.active.json`).
- Do not commit local tool state from `.qwen/` or `.claude/`.
- Keep both Unix (`.sh`) and Windows (`.ps1`) parity when changing workflows.
- Keep llama.cpp as default runtime path.
- Prefer additive profile changes over hardcoded machine-specific paths.
- Keep `.opencode/agents/` and `.opencode/skills/` intentionally small and task-focused.
