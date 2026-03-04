# Local Models Directory

This directory is intentionally excluded from Git commits.

Expected subdirectories by profile:

- `models/qwen3.5/`
- `models/qwen/`
- `models/minimax/` (only for `128gb-minimax`)
- `models/embeddings/`

Use the setup scripts to download models:

- Unix: `./scripts/setup-models-device.sh --profile 24gb`
- Windows: `./scripts/setup-models-device.ps1 -Profile 24gb`

Then generate active config:

- Unix: `./scripts/setup-config-device.sh --profile 24gb`
- Windows: `./scripts/setup-config-device.ps1 -Profile 24gb`
