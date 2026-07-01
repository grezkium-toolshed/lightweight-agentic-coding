# Release State

Track progress toward public beta release. Updated as work progresses.

## Current Phase: Public beta readiness

Release index: `docs/release/README.md`

Release gate report: `./scripts/release-gate-report.sh` intentionally fails until `RELEASE_CHECKLIST.md` and `docs/release/MANUAL_VALIDATION.md` are complete.

### Scope
- Ship a public beta posture, not a stable v1 claim
- Keep automated checks green and onboarding paths honest
- Validate documented onboarding paths on real hardware before marking hardware gates complete
- Expose ds4/DwarfStar as an explicit 128GB+ Apple Silicon path for DeepSeek V4 Flash

### Open Questions
- [ ] GitHub Private Vulnerability Reporting enabled in repo settings with `./scripts/release-security-pvr.sh --confirm-enabled --screenshot <reference>` evidence, including generated `state/release-evidence/` output, GitHub docs/settings path, `gh repo view` metadata, security policy URL, `SECURITY.md` wording check, repo owner/admin confirmation, date enabled, and screenshot/reference from repository Settings > Advanced Security showing Private vulnerability reporting enabled
- [ ] Live validation on all documented hardware tiers (16gb, 24gb, 32gb, 64gb, gemma-*)
- [ ] Manual 128GB-class Apple Silicon validation with `./scripts/release-ds4-128gb.sh --full-runtime`, including generated `state/release-evidence/` output, hardware/RAM/macOS details, ds4 binary path/version or commit, `lac profile apply 128gb-ds4-flash --json`, runtime status showing ds4 paths and port 8000, `lac models sync 128gb-ds4-flash`, `curl http://127.0.0.1:8000/v1/models`, and OpenCode ds4 model selection/session notes
- [ ] Windows PowerShell fresh-clone validation with `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/release-windows-powershell.ps1 -FullRuntime`, including generated `state/release-evidence/` output, Windows OS details, PowerShell version, Python version/path, git commit, `bin/lac.ps1 --version`, `bin/lac.ps1 init --yes --profile 24gb --no-cloud --json`, `bin/lac.ps1 doctor --bootstrap-hint --json`, `bin/lac.ps1 smoke --json`, transcript/summary path, and model sync/runtime start/status evidence when captured by the helper
- [ ] Real OpenCode discovery validation with `./scripts/release-opencode-discovery.sh --open` and screenshot, transcript, or manual session notes
- [ ] Live provider freshness probes with release credentials or documented skips
- [ ] Linux CI green on release branch

### Completed
- [x] Public project metadata updated for public beta: `CHANGELOG.md` records ds4/package/release-gate work, and `CONTRIBUTING.md` points contributors at `scripts/verify-public-beta-local.sh` with current generated state paths
- [x] Public support surface added: `SUPPORT.md` documents issue routing, validation commands, security routing, and public-beta no-SLA expectations
- [x] Manual evidence helper hardened: `scripts/release-evidence.sh` prints paste-ready `Status: open` stubs so testers can record evidence without closing gates early
- [x] Manual gate transcript guidance added: command-line evidence can be captured under ignored `state/release-evidence/` and referenced from the gate notes
- [x] Fresh-clone Unix helper added: `scripts/release-fresh-clone-unix.sh` records no-download smoke evidence by default and `--full-runtime` evidence for the manual release gate
- [x] Provider freshness helper added: `scripts/release-provider-freshness.sh` captures provider verify JSON, OpenRouter refresh/check output, and skipped-provider reasons for the manual release gate
- [x] llama.cpp smoke helper added: `scripts/release-llama-smoke.sh` captures runtime status, curl health/models probes, and `lac smoke --json` for the manual release gate
- [x] GitHub Private Vulnerability Reporting helper documentation wired: `scripts/release-security-pvr.sh --allow-unavailable` is documented as automated/local rehearsal, while `--confirm-enabled --screenshot <reference>` after repo owner/admin enablement plus generated `state/release-evidence/` output, GitHub docs/settings path, `gh repo view` metadata, security policy URL, `SECURITY.md` wording check, owner/admin confirmation, date enabled, and repository Settings > Advanced Security screenshot/reference remain required to close the gate
- [x] Windows PowerShell helper documentation wired: `scripts/release-windows-powershell.ps1 -NoRuntime` is documented as optional Windows rehearsal, while `-FullRuntime` from a real fresh Windows clone plus generated `state/release-evidence/` output, Windows OS/PowerShell/Python/git details, wrapper JSON command outputs, transcript/summary path, and helper-captured runtime evidence remain required to close the gate
- [x] OpenCode discovery helper documentation wired: `scripts/release-opencode-discovery.sh --skip-open --allow-missing-opencode` is documented for automated rehearsal, while `--open` plus OpenCode version, rendered config path, repo/package agent and skill counts, generated `state/release-evidence/` summary, and screenshot/transcript/manual notes remain required to close the gate
- [x] ds4 128GB helper documentation wired: `scripts/release-ds4-128gb.sh --dry-run --allow-missing-ds4` is documented for automated/local rehearsal, while `--full-runtime` on real 128GB+ Apple Silicon hardware remains required to close the gate
- [x] Manual gates now cross-reference matching `RELEASE_CHECKLIST.md` items, and release-gate reporting flags closed gates whose checklist items remain open
- [x] Third-party notices added for bundled external assets, optional runtimes, and ds4 model-source attribution; local release audit now checks catalog source-ref coverage
- [x] Package metadata declares `THIRD_PARTY_NOTICES.md`, package data ships it for installed users, and package-build verification checks wheel and sdist artifacts
- [x] Historical audit/backlog notes marked as superseded snapshots so current public-beta work routes through `docs/release/gates.json`, `docs/release/MANUAL_VALIDATION.md`, and `RELEASE_CHECKLIST.md`
- [x] Local automated public-beta wrapper passed on 2026-06-30: `scripts/verify-public-beta-local.sh` completed and summarized the 8 remaining manual gates without metadata or closed-gate evidence errors
- [x] Repo naming/public framing audit passed: README, package metadata, release docs, and local release audit align on `lac` — Lightweight Agentic Coding, `lightweight-agentic-coding` package slug, and public beta/not stable v1 positioning
- [x] Release local audit passed for provider doc structure, trust metadata/doc alignment, and tracked model/local artifact hygiene
- [x] Provider authentication docs reviewed locally for catalog coverage and release env-var conventions
- [x] Free cloud policy, onboarding scenario docs, and Claude Code template scope validated by release local audit
- [x] Local automated beta gate passed on 2026-06-29 with the coherence, documentation, profile, schema, asset, provider, v2 contract, and integration scripts
- [x] Package-mode sanity check passed from outside the repo with matching catalog/pack/agent/skill counts
- [x] Wheel build verification added for package metadata, bundled lac data files, installed-wheel `doctor`, installed-wheel `pack list`, and installed-wheel `profile apply` chat-template paths
- [x] ds4 dry validation passed: generated OpenCode config selects `ds4/deepseek-v4-flash`, and runtime status reports ds4 port/state paths
- [x] ds4/DwarfStar profile and runtime path added for public-beta validation
- [x] Repo-local Unix and PowerShell wrappers prepared for clean-checkout execution
- [x] Packaged `.opencode` asset mirror expanded to match the tracked public catalog
- [x] Gemma 4 model family added (models, presets, setup scripts, templates)
- [x] Pre-beta review findings fixed (missing gemma model in config, dead code, fragile grep)
- [x] OpenRouter free tier documented around a live catalog refresh path with starter defaults kept for clean-clone fallback
- [x] OpenRouter free-model availability moved from manual snapshot review to catalog-driven docs/tests
- [x] GSD workflow skill added for multi-session work
- [x] OpenRouter hardware profile added (cloud-only, zero downloads)
- [x] Skill and agent authoring templates created
- [x] Smoke test and profile sync scripts added
- [x] CI workflow added at `.github/workflows/ci.yml`

### Deferred (post-beta)
- Windows CI lane restoration; for now, validate Windows via local/manual checks until native PowerShell verification coverage exists
- Performance telemetry
- Profile composition (mix local + cloud in one profile)
- Structured feedback loop

### Next Session
Pick up from the "Open Questions" above. If a question is resolved, move it to "Completed" and add the next item.
