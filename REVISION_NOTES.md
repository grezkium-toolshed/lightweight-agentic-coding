# Revision Notes

## 2026-03-04 - vNext Migration

### Major Changes

- Decommissioned `oh-my-opencode` from active setup (repo-wide direction).
- Added canonical root `opencode.jsonc` for OpenCode project configuration.
- Added profile-based llama.cpp preset system:
  - `16gb`, `24gb`, `32gb`, `64gb`, `128gb-multi`, `128gb-qwen122b`, `128gb-minimax`
- Added cross-platform scripts (`.sh` and `.ps1`) for:
  - model download
  - config generation
  - profile switching
  - llama launch
  - OpenCode launch
  - doctor checks
- Standardized default endpoint to `http://127.0.0.1:8080/v1`.
- Added `.gitignore` rules for local model files and local artifacts.
- Added `docs/CONFLUENCE_QWEN35_MIGRATION_GUIDE.md` for org rollout.
- Removed remaining legacy compatibility wrapper files.
- Added default cloud provider definitions for Antigravity, z.ai, and OpenRouter free models.
- Added free-model sync scripts and generated docs integration with kudos to @vava-nessa.
- Added launch visibility upgrades for llama-server on Unix and Windows:
  - persistent log file capture
  - simple log rotation (`.log` + `.log.1`)
  - tail hints on successful launch
  - recent log excerpts on startup failure
  - optional `--show-logs` / `-ShowLogs` and hint suppression flags

### Policy Updates

- Keep llama.cpp as default runtime path.
- Keep `qwen3-coder-next` for high-value coding specialist tasks.
- 128GB profiles target <=115GB effective memory usage for headroom.
