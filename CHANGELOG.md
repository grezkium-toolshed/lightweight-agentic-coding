# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
for tagged releases (public beta and beyond).

## [Unreleased]

### Added

- MCP server configuration for GitHub API (`disabled` by default; requires `GITHUB_TOKEN`).
- Custom commands `/doctor` and `/health` for runtime validation.
- Dynamic Context Pruning (DCP) plugin configuration at `.opencode/dcp.jsonc`.
- `docs/review-backlog.md` — comprehensive backlog of open issues from full repo review.

### Changed

- Renamed `opencode.jsonc` to `opencode.template.jsonc` to prevent OpenCode auto-discovery conflict.
- Bumped all model context limits to `262144` and output limits to `16384` for consistency.
- Expanded `state/README.md` with env-var override and git-ignore notes.
- Added `docs/providers/FREE_CLOUD_FALLBACKS.md` to documentation verification checks.
- Added Contributing section to `README.md`.

### Fixed

- CI glob fragility in `.github/workflows/ci.yml` (loop guard for empty globs).
- Missing documentation for `opencode-antigravity-auth` plugin in `docs/providers/AUTHENTICATION.md`.
- Example template (`templates/opencode/opencode.example.jsonc`) missing 7 model IDs and 4 provider blocks.
- Example bash permissions misaligned with main config.
- `scripts/switch-profile.sh` usage string now auto-generated from `profiles.json`.
- Foreground runtime mode missing SIGINT/SIGTERM cleanup in `scripts/lac.py`.
- Root `agents/` and `skills/` directories missing warnings about `.opencode/` runtime paths.
- Missing `--version` flag on `./bin/lac` CLI.

## [0.1.0] — 2026-04-27

### Added

- Initial public beta preparation.
- Local AI Cluster runtime with llama.cpp and optional oMLX on macOS.
- Profile-based model setup (`16gb` through `128gb-multi`, plus cloud-only profiles).
- Curated OpenCode agents: `architecture-reviewer`, `reality-checker`, `release-reviewer`, `research-synthesizer`, `documentation-generator`.
- Curated OpenCode skills: `documentation-generator`, `docx-workflow`, `pdf-workflow`, `pptx-workflow`, `xlsx-workflow`, `gsd`, `research-synthesizer`.
- CLI tool `./bin/lac` for profile management, runtime control, and client launch.
- CI validation for Linux (bash syntax, config schema, profile parity, documentation, provider catalog).
