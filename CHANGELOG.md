# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
for tagged releases (public beta and beyond).

## [0.2.0] — Unreleased

*(Pre-public codebase versioning; public beta remains gated by the release checklist.)*

Re-aimed the project around **private, on-device AI for everyday work** (for people on machines
where cloud AI is blocked), plus a lightweight-to-maintain, correctly-attributed cleanup pass.

### Added

- Ponytail plugin (`@dietrichgebert/ponytail@4.8.4`, MIT) pre-wired into generated OpenCode
  configs: laziness ruleset injected every turn, `/ponytail lite|full|ultra|off` commands, and
  review/audit/debt skills. Opt out per session with `PONYTAIL_DEFAULT_MODE=off`; see
  `THIRD_PARTY_NOTICES.md`.
- Qwen 3.8 readiness: `qwen3.8-27b-q3/q4/q6` slots in the `local-cluster` provider template so
  configs render before the open-weights drop (~2026-08-10); drop-day checklist in
  `docs/models/QWEN38_READY.md`.
- `scripts/bootstrap.sh` (macOS-first) + `scripts/bootstrap.ps1` — one command from nothing to a
  running private assistant: installs prerequisites (llama.cpp, OpenCode, OpenChamber, Python),
  then downloads a small model and opens the OpenChamber chat UI. Idempotent.
- README re-positioned around private on-device AI for work, OpenChamber-first, with honest
  "Will this run on my work laptop?" and "What your IT needs to allow" sections; big-memory
  profiles moved to an "Advanced" section.
- A compact public-release checklist and installed wheel/sdist verification across Python
  3.10-3.13, plus a native Windows PowerShell CI smoke test.

### Changed

- Onboarding is OpenChamber-first (chat UI) with OpenCode as the coding option; `lac init` now
  lists OpenChamber in prerequisites and next-steps.
- Single source of truth for bundled data: the top-level `runtime-config/`, `catalog/`,
  `opencode.template.jsonc`, and `.opencode/` trees are canonical. `src/lac/data/` is now
  generated at build time by `scripts/stage_data.py` (invoked from `setup.py`) and gitignored.
- CI uses the offline verifier and integration suite on Linux/macOS, plus clean artifact
  build/install checks and a Windows PowerShell lane. GitHub Actions are commit-pinned.
- Provider catalog trimmed to the documented core: `local-cluster`, `openrouter`, `anthropic`,
  `opencode-go`, `nvidia-nim`; provider freshness metadata dropped.
- `SUPPORT.md`/`SECURITY.md` reworded to reflect a best-effort community project on `master`.

### Fixed

- `lac doctor --fix` no longer runs installs/downloads/runtime-start before the consent prompt
  (detection is now side-effect-free), and no longer crashes in text mode.
- `lac init` no longer offers cloud providers that were removed from the catalog (the wizard
  used to list `opencode-zen`/`codex-auth`/`antigravity`/`z-ai` and crash if one was selected).
- Removed the phantom `nomic-embed-text-v1.5` model slot that 12 presets declared but no profile
  ever downloaded.
- MiniMax profile now uses the model's embedded chat template instead of the Qwen template.
- Fixed `main` → `master` self-referencing links (PyPI URLs, issue template, `SECURITY.md`).
- Bundled `catalog/checksums.json` with the demo model's SHA256 so `lac models sync micro`
  has a blocking integrity check; mismatched files are quarantined and never launched.
- Installed wheels now keep models, refreshed catalogs, and runtime state in writable per-user
  directories instead of trying to modify package resources.
- Packaged the Claude Code templates required by `lac client render claude-code`.
- Bootstrap now installs/checks OpenChamber's Node.js 22+ and pnpm prerequisites and falls back
  to OpenCode when the chat UI is unavailable.
- Bootstrap now exposes pnpm's macOS global bin directory to the same install process and detects
  versioned Python binaries before installing another Homebrew Python.
- The `micro` profile now uses a 32K context window, preventing OpenCode from repeatedly trying
  and failing to compact its startup prompt into the previous 8K limit, and lets llama.cpp
  auto-select GPU offload instead of forcing CPU-only inference.
- Package verification no longer mistakes an ignored local `build/` output directory for the
  installed PyPA `build` module, keeping repeated release checks idempotent.
- OpenChamber discovery now checks the pnpm install locations used by bootstrap, so later
  `lac client open openchamber` runs do not depend on inheriting bootstrap's temporary PATH.
- Rendered OpenCode configs now take every selected local model's context limit from the active
  profile preset and reject profiles below the 32K startup/headroom floor, preventing both
  immediate prompt overloads and later runtime/advertised-context drift.
- Removed stale provider blocks and docs for providers no longer present in the supported catalog.
- Repaired the packaged shell and PowerShell launch wrappers so they invoke the supported CLI.
- Pinned the default Dynamic Context Pruning plugin to `3.1.14` for reproducible setup.

### Removed

- Dead second CLI `scripts/lac.py` and the heavyweight release-evidence apparatus (`release-*.sh`,
  `docs/release/gates.json`, `verify-documentation.sh`, drift-guard verify scripts); a compact
  `RELEASE_CHECKLIST.md` remains as the public-release gate.
- Vendored third-party design skills, craft rulebooks, and brand design-systems are no longer
  redistributed — they are opt-in fetch via the Open Design installer. See `THIRD_PARTY_NOTICES.md`.


## [0.1.0] — 2026-04-27

### Added

- Initial versioned codebase with the lac — Lightweight Agentic Coding rebrand. *(Pre-public codebase versioning; public beta remains gated by the release checklist.)*
- lac runtime with llama.cpp and optional oMLX on macOS.
- Profile-based model setup (`16gb` through `128gb-multi`, plus cloud-only profiles).
- Curated OpenCode agents: `architecture-reviewer`, `reality-checker`, `release-reviewer`, `research-synthesizer`, `documentation-generator`.
- Curated OpenCode skills: `documentation-generator`, `docx-workflow`, `pdf-workflow`, `pptx-workflow`, `xlsx-workflow`, `gsd`, `research-synthesizer`.
- CLI tool `./bin/lac` for profile management, runtime control, and client launch.
- CI validation for Linux (bash syntax, config schema, profile parity, documentation, provider catalog).
