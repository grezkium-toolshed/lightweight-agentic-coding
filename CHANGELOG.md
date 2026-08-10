# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
for tagged releases (public beta and beyond).

## [0.3.0] — 2026-08-09

Released the hardware-fit public beta with an explicit Apple Silicon MacBook support boundary.

### Added

- Normalized accelerator-memory detection and diagnostics for Apple unified memory, NVIDIA,
  AMD, Intel, ordinary iGPUs, and Windows ARM64 Qualcomm/Adreno hardware.
- A canonical Windows guide separating WSL2 local use, native local preview, and the explicitly
  hosted OpenChamber Desktop plus OpenCode Go/Zen alternative.
- A manual-only `48gb` profile for Qwen 3.6 35B-A3B Q8 with a 27B fallback and conservative
  256K-context runtime settings. Automatic recommendation remains disabled until the exact
  48 GB MacBook hardware contract passes.
- A public, undated roadmap covering trustworthy MacBook self-service, the hardware-fit
  workbench direction, and a scenario-led private-work workspace.
- A public stack boundary describing lac as the private execution layer in an evidence-to-proof
  Microsoft 365 security delivery loop, plus a candidate `delivery-run.v1` content-addressed
  linking contract and dependency-free semantic verifier.

### Changed

- Checkout and installed commands now resolve the same per-user model, catalog, and state roots;
  checkout-local mutable data requires an explicit environment override.
- Generated OpenCode configuration disables sharing and automatic updates and asks before edits.
  `lac doctor` and client launch report inherited global/project configuration risks without
  modifying user files or blocking launch.
- Bootstrap uses the installed pipx command for its first run when available, prints its resolved
  storage roots, and reports legacy checkout-local data instead of silently selecting it.
- Recovery documentation now covers OpenCode merge behavior, exact uninstall paths, client process
  ownership, first-use plugin networking, checksum scope, and safe workspace practice.
- `lac init` now recommends from the largest single usable accelerator budget instead of broad
  system-RAM ranges. Unmeasured accelerators and WSL2 without a measurable GPU budget fall back
  to the `4gb` profile with low confidence; non-Apple 128 GB hosts avoid automatic ds4 selection.
- Public support is now explicit: Apple Silicon MacBooks are the tested and supported platform;
  Windows, Linux, Intel Macs, ordinary iGPUs, Snapdragon/Adreno, and other unverified hardware
  are experimental and test-at-your-own-risk.
- The ds4/DwarfStar profile uses a 256K harness default and documents measured M4 Max 128 GB
  context, memory, prefill, and decode evidence.
- Profile metadata, presets, downloads, and rendered client context are checked together across
  60 active preset model sections. Local release checks cover contracts and clean package builds; an
  optional manual workflow can repeat Linux/macOS/Windows configuration-compatibility checks.
- Automatic GitHub Actions triggers and the install-only hosted macOS bootstrap workflow were
  removed to conserve hosted minutes. A real clean-MacBook bootstrap remains the release gate.
- The bootstrap retries OpenCode through its npm package when the upstream installer cannot fetch
  version metadata. Clean installs pin OpenCode `1.17.18` and OpenChamber `1.16.3`; existing
  mismatched versions are left in place with an explicit alignment warning.
- Native Windows process checks no longer use signal zero, Windows log hints use PowerShell, and
  the on-demand compatibility workflow can build and exercise an installed Windows wheel.
- Generated OpenCode configs now expose only models present in the active preset, match runtime and
  fitting context exactly, cap output at 4K/8K/16K by context tier, and reject insufficient prompt
  headroom. DCP thresholds are generated per model at 50%/75% as supplemental compression guidance.
- `OPENCODE_CONFIG_DIR` now carries generated DCP configuration and packaged agents/skills to both
  OpenCode and OpenChamber, while repository checkouts retain their canonical project assets.
- Custom `LAC_HOST` and `LAC_PORT` values now reach the llama.cpp client URL as well as the runtime.
- Ponytail is pinned to `4.9.0`, which loads correctly with the v0.3 OpenCode pin; the earlier
  `4.8.4` pin failed during a clean isolated plugin load.
- DCP is pinned to `3.1.9`: it registers its command and compression tool with OpenCode `1.17.18`,
  while `3.1.14` currently fails clean npm resolution because of an OpenTUI peer conflict.
- The roadmap now separates lac SemVer from coordinated stack milestones. Cross-product claims
  remain candidate capabilities until one approved production-pilot control completes assessment,
  approval, deployment, independent read-back, customer-safe packaging, and repeat-run delta.

### Removed

- The README's forwardable "What your IT needs to allow" guidance. lac remains individuals-first
  and does not promise enterprise deployment or procurement support.
- The undocumented `lac doctor --fix` self-healing subsystem, legacy `lac setup` path, and the
  misleading Windows desktop launcher. Explicit commands and read-only diagnostics remain.

## [0.2.0] — 2026-08-04

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
- Cloud catalogs refreshed against upstream (2026-08-04): OpenCode Go block now lists the
  current OpenAI-compatible models (Grok 4.5, GLM 5.2/5.1, Kimi K3/K2.7 Code/K2.6, DeepSeek V4
  Pro/Flash, MiMo-V2.5, Hy3 — Qwen/MiniMax Go models use the Anthropic endpoint and are
  documented as `/connect` models); the OpenRouter free block now lists live free-tier IDs
  (Gemma 4, Nemotron 3, GPT-OSS 20B, and more); profile defaults follow suit.
- Public beta posture documented: README/SUPPORT state that Apple Silicon macOS is the
  validated platform, with Windows full-runtime, 128 GB `ds4`, and fresh-macOS bootstrap
  flagged as not-yet-validated-on-hardware paths.
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
- Pinned the default Dynamic Context Pruning plugin to `3.1.9` for reproducible setup.
- Pinned the optional Microsoft Graph skill installer to release `v1.0.19` and added a blocking
  SHA-256 check before extracting the downloaded archive.
- Fixed package verification when run from the repository root, where the local `build/` output
  directory previously shadowed Python's `build` module.

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
