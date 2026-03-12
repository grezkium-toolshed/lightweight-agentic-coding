# Contributing

## Scope

This repository is a configuration-first template for OpenCode + llama.cpp.
Contributions should preserve portability and reproducibility.
The repo is intentionally private until release gates are complete.

## Local Checks Before PR

1. Run shell syntax checks:

```bash
bash -n scripts/*.sh
bash -n verify-*.sh
bash -n runtime-config/launch/*.sh
```

2. Regenerate profile config and run doctor:

```bash
./scripts/setup-config-device.sh --profile 24gb
./scripts/doctor.sh
```

3. Validate docs set:

```bash
./verify-documentation.sh
```

## Contribution Rules

- Do not commit model binaries (`*.gguf`) or local caches.
- Keep both Unix (`.sh`) and Windows (`.ps1`) parity when changing workflows.
- Keep llama.cpp as default runtime path.
- Prefer additive profile changes over hardcoded machine-specific paths.
- Keep `.opencode/agents/` and `.opencode/skills/` intentionally small and task-focused.
