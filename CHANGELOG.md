# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
for tagged releases (public beta and beyond).

## [Unreleased]

### Added

- Public beta release gate flow: `docs/release/gates.json`, `docs/release/MANUAL_VALIDATION.md`, `scripts/release-gate-report.sh`, `scripts/release-evidence.sh`, `scripts/release-manual-next-steps.sh`, `scripts/test-release-gate-report.sh`, and `scripts/verify-public-beta-local.sh`.
- Public beta support policy in `SUPPORT.md`, including issue routing, validation commands, and no-SLA beta expectations.
- Paste-ready manual evidence stubs from `scripts/release-evidence.sh`, kept at `Status: open` until external evidence is complete.
- Transcript capture guidance for manual release gates, writing local evidence logs under ignored `state/release-evidence/`.
- Fresh-clone Unix onboarding smoke helper at `scripts/release-fresh-clone-unix.sh`, with no-download rehearsal mode and `--full-runtime` release evidence mode.
- Provider freshness evidence helper at `scripts/release-provider-freshness.sh`, capturing provider verify JSON, OpenRouter refresh/check output, and skipped-provider reasons without secrets.
- llama.cpp smoke evidence helper at `scripts/release-llama-smoke.sh`, capturing runtime status, curl health/models probes, and `lac smoke --json`.
- GitHub Private Vulnerability Reporting evidence helper wiring for `scripts/release-security-pvr.sh`, documenting local rehearsal with `--allow-unavailable` while keeping the gate open until repo owner/admin `--confirm-enabled --screenshot <reference>` evidence is captured after enabling PVR in repository settings.
- Linux CI evidence helper wiring for `scripts/release-linux-ci.sh`, documenting local rehearsal with `--allow-unavailable` while keeping the gate open until GitHub Actions evidence proves `.github/workflows/ci.yml` completed successfully for the release commit.
- Historical plan/backlog docs now carry public-beta supersession notes, and `verify-documentation.sh` prevents old implementation plans from being mistaken for current release guidance.
- Release state open questions now carry explicit owners and target conditions, with `verify-documentation.sh` coverage preventing ownerless or targetless public-beta blockers.
- OpenCode template schema validation is explicitly tracked in CI, the local beta wrapper, and documentation verification.
- Contributor script-style guidance now standardizes public helper entrypoints as shell/PowerShell wrappers with inline Python for small validators and standalone Python reserved for the CLI/shared libraries.
- Public docs navigation now links Codex auth back to provider onboarding and Claude Code guidance, and the scenario guide documents `catalog/workflow-packs.json` as the canonical workflow-pack source.
- Provider/free-model freshness age warnings via `scripts/check-provider-doc-freshness.sh`, wired into CI and the local public-beta suite without auto-refreshing live catalogs.
- Windows PowerShell release evidence helper wiring for `scripts/release-windows-powershell.ps1`, documenting manual `-FullRuntime` evidence from a fresh Windows clone, optional `-NoRuntime` Windows rehearsal, generated evidence under `state/release-evidence/`, wrapper JSON command outputs, environment details, and transcript/summary paths while keeping the gate open until real Windows proof exists.
- OpenCode discovery evidence helper wiring for `scripts/release-opencode-discovery.sh`, documenting automated rehearsal, real-session proof, generated evidence under `state/release-evidence/`, OpenCode version, rendered config path, repo/package agent and skill counts, and screenshot/transcript/manual session notes.
- ds4 128GB release evidence helper wiring for `scripts/release-ds4-128gb.sh`, documenting local rehearsal with `--dry-run --allow-missing-ds4` while keeping the gate open until `--full-runtime` evidence is captured on real 128GB+ Apple Silicon hardware.
- Gate-to-checklist cross-references in release helpers and release-gate reports, including diagnostics for closed gates whose checklist item remains open.
- ds4/DwarfStar local runtime support for the `128gb-ds4-flash` profile, targeting 128GB+ Apple Silicon validation for DeepSeek V4 Flash.
- Packaged `.opencode` asset mirror under `src/lac/data/opencode`, covering tracked agents, skills, craft rulebooks, design systems, and DCP config.
- `THIRD_PARTY_NOTICES.md` for bundled external assets, optional runtimes, and ds4 model-source attribution.
- Wheel/package verification via `scripts/verify-package-build.sh`.
- Package metadata now declares `THIRD_PARTY_NOTICES.md`, package data ships it for installed users, and wheel/sdist verification checks both.
- MCP server configuration for GitHub API (`disabled` by default; requires `GITHUB_TOKEN`).
- Custom commands `/doctor` and `/health` for runtime validation.
- Dynamic Context Pruning (DCP) plugin configuration at `.opencode/dcp.jsonc`.
- `docs/review-backlog.md` — comprehensive backlog of open issues from full repo review.

### Changed

- README quick start now uses the public clone/install flow: `git clone`, `cd lightweight-agentic-coding`, `python3 -m pip install .`, then `lac init`.
- Python package metadata now includes public beta classifiers, project URLs, keywords, and maintainer attribution for package-index readiness.
- Historical audit/backlog docs now identify themselves as superseded snapshots and point current release work at the canonical manual-gate system.
- `models/README.md` now documents `lac models sync` / `lac profile apply` instead of retired setup scripts, including the ds4 model directory.
- Migration and hybrid-workspace docs now frame `./bin/lac` / `./bin/lac.ps1` as the primary operational path, with `scripts/` reserved for compatibility and verification helpers.
- Repo-local Unix and PowerShell wrappers now work from a clean checkout without manually exporting `PYTHONPATH=src`.
- CI now runs the integration test, package build check, release local audit, and release gate report self-test.
- `scripts/integration-test.sh` validates current `bin/lac.ps1` and `runtime-config/launch/*.ps1` paths instead of removed setup scripts.
- Renamed `opencode.jsonc` to `opencode.template.jsonc` to prevent OpenCode auto-discovery conflict.
- Bumped all model context limits to `262144` and output limits to `16384` for consistency.
- Expanded `state/README.md` with env-var override and git-ignore notes.
- Added `docs/providers/FREE_CLOUD_FALLBACKS.md` to documentation verification checks.
- Release local audit now verifies third-party notice coverage for cataloged external source refs and ds4 runtime/model sources.
- Added Contributing section to `README.md`.
- Device setup now installs or refreshes `@tarquinen/opencode-dcp@latest` so `/dcp` is available after restarting OpenCode.

### Fixed

- Package-mode `client render opencode` writes generated manifests to state instead of package data.
- OpenCode `/doctor` command and model verification docs now point at current `./bin/lac doctor` / `./bin/lac smoke` commands instead of retired script paths.
- Root and packaged catalogs now have parity checks to prevent silent drift.
- Installed-wheel profile application now references packaged chat templates.
- `SECURITY.md` keeps GitHub Private Vulnerability Reporting as an explicit public-beta release gate until enabled.
- CI glob fragility in `.github/workflows/ci.yml` (loop guard for empty globs).
- Missing documentation for `opencode-antigravity-auth` plugin in `docs/providers/AUTHENTICATION.md`.
- Example template (`templates/opencode/opencode.example.jsonc`) missing 7 model IDs and 4 provider blocks.
- Example bash permissions misaligned with main config.
- `scripts/switch-profile.sh` usage string now auto-generated from `profiles.json`.
- Foreground runtime mode missing SIGINT/SIGTERM cleanup in `scripts/lac.py`.
- Root `agents/` and `skills/` directories missing warnings about `.opencode/` runtime paths.
- Missing `--version` flag on `./bin/lac` CLI.
- DCP setup no longer calls the unsupported `opencode plugin list` command.

## [0.1.0] — 2026-04-27

### Added

- Initial versioned codebase with the lac — Lightweight Agentic Coding rebrand. *(Pre-public codebase versioning; public beta remains gated by the release checklist.)*
- lac runtime with llama.cpp and optional oMLX on macOS.
- Profile-based model setup (`16gb` through `128gb-multi`, plus cloud-only profiles).
- Curated OpenCode agents: `architecture-reviewer`, `reality-checker`, `release-reviewer`, `research-synthesizer`, `documentation-generator`.
- Curated OpenCode skills: `documentation-generator`, `docx-workflow`, `pdf-workflow`, `pptx-workflow`, `xlsx-workflow`, `gsd`, `research-synthesizer`.
- CLI tool `./bin/lac` for profile management, runtime control, and client launch.
- CI validation for Linux (bash syntax, config schema, profile parity, documentation, provider catalog).
