# Local Models Directory

This directory is a legacy, opt-in model root and is intentionally excluded from
Git commits. Normal checkout and installed commands use the platform user-data
directory; run `lac doctor --json` for the effective `models_root`. Set
`AI_MODELS_DIR="$PWD/models"` only when deliberately reusing checkout-local weights.

Expected subdirectories by profile:

- `models/qwen3.5/`
- `models/qwen/`
- `models/minimax/` (only for `128gb-minimax`)
- `models/ds4/` (only for `128gb-ds4-flash`)
- `models/embeddings/`

Use `lac models sync` to download or verify models:

- Unix: `./bin/lac models sync 24gb`
- Windows: `.\bin\lac.ps1 models sync 24gb`

Then generate the active profile and client config:

- Unix: `./bin/lac profile apply 24gb`
- Windows: `.\bin\lac.ps1 profile apply 24gb`

For the 128GB-class ds4/DwarfStar profile, use:

```bash
./bin/lac models sync 128gb-ds4-flash
./bin/lac profile apply 128gb-ds4-flash
```
