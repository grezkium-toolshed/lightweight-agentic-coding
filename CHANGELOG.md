# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
for tagged releases (public beta and beyond).

## [Unreleased]

Re-aimed the project around **private, on-device AI for everyday work** (for people on machines
where cloud AI is blocked), plus a lightweight-to-maintain, correctly-attributed cleanup pass.

### Added

- `scripts/bootstrap.sh` (macOS-first) + `scripts/bootstrap.ps1` — one command from nothing to a
  running private assistant: installs prerequisites (llama.cpp, OpenCode, OpenChamber, Python),
  then downloads a small model and opens the OpenChamber chat UI. Idempotent.
- README re-positioned around private on-device AI for work, OpenChamber-first, with honest
  "Will this run on my work laptop?" and "What your IT needs to allow" sections; big-memory
  profiles moved to an "Advanced" section.

### Changed

- Onboarding is OpenChamber-first (chat UI) with OpenCode as the coding option; `lac init` now
  lists OpenChamber in prerequisites and next-steps.
- Single source of truth for bundled data: the top-level `runtime-config/`, `catalog/`,
  `opencode.template.jsonc`, and `.opencode/` trees are canonical. `src/lac/data/` is now
  generated at build time by `scripts/stage_data.py` (invoked from `setup.py`) and gitignored.
- CI collapsed to two scripts: `scripts/verify.sh` (syntax, schema, staging, licensing guard)
  and `scripts/integration-test.sh`.
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
  has a real integrity check (best-effort: mismatches warn, they do not block).

### Removed

- Dead second CLI `scripts/lac.py` and the entire release-gate apparatus (`release-*.sh`,
  `docs/release/gates.json`, `verify-documentation.sh`, drift-guard verify scripts).
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
