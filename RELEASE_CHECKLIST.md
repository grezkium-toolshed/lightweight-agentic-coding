# Public Beta Release Checklist

This document tracks release readiness. Items marked [x] are complete; open items are gating factors.

Use this checklist before changing the repo visibility or publishing release notes.

Final public-beta publication is blocked until `./scripts/release-gate-report.sh` exits successfully and `docs/release/MANUAL_VALIDATION.md` has evidence for every manual gate.

Use `./scripts/release-evidence.sh <gate-id>` to print the command bundle and evidence fields for each manual gate.

Use `./scripts/verify-public-beta-local.sh` to run the local automated public-beta check suite before collecting external/manual evidence.

## Identity and framing
- [x] Repository name, description, and README use the `lac` — Lightweight Agentic Coding identity consistently.
- [x] Public beta positioning is explicit: local-first, evolving, and not a stable v1.
- [x] Any remaining private-only language is intentional and limited to release-gate docs.

## Runtime validation
- [ ] macOS or Linux path validated from a fresh clone:
  - `python3 -m pip install .`
  - `lac init --yes --profile 24gb --no-cloud`
  - `lac models sync 24gb`
  - `lac runtime start`
  - `lac client render opencode`
- [ ] Windows PowerShell path validated from a fresh clone with `bin/lac.ps1 init`, `bin/lac.ps1 doctor`, and `bin/lac.ps1 smoke`.
- [ ] OpenCode desktop launch validated on the platforms where it is documented.
- [ ] llama.cpp smoke validates `curl http://127.0.0.1:8080/health` and `curl http://127.0.0.1:8080/v1/models`.
- [ ] ds4/DwarfStar 128GB-class path validated manually: build `antirez/ds4`, run `lac models sync 128gb-ds4-flash`, `lac runtime start`, and verify `curl http://127.0.0.1:8000/v1/models`.

## OpenCode integration
- [ ] `.opencode/agents/*.md` are discoverable in a real OpenCode session.
- [ ] `.opencode/skills/*/SKILL.md` are discoverable in a real OpenCode session.
- [x] Config regeneration preserves compaction, watcher ignores, instructions, permission policy, and provider blocks.

## Providers and docs
- [x] Provider auth docs are current for Antigravity, z.ai, NVIDIA NIM, OpenRouter, Anthropic, Codex auth, and OpenCode Go/Zen.
- [ ] Live provider freshness probes are complete with release credentials, or every skipped provider has a documented release skip reason.
- [x] Free cloud snapshot policy is explicit and still correct.
- [x] Onboarding scenarios are accurate for low-end, higher-end, and hosted-model workflows.
- [x] Claude Code template docs are complete and not misleading.
- [x] Public beta docs mention ds4 as an explicit 128GB+ Apple Silicon path, not a default recommendation.

## Automated validation
- [x] Local automated gate wrapper passed on 2026-06-30: `scripts/verify-public-beta-local.sh` runs coherence, documentation, profile/schema/asset/provider verifiers, v2 contract, integration, package build, release local audit, and release gate report self-test.
- [x] Package-mode sanity check passed from outside the repo: `lac doctor --json` reports 41 catalog assets, 7 packs, 6 agents, and 35 skills; `lac pack list --json` reports 7 packs.
- [x] Wheel build check verifies package metadata plus bundled runtime config, catalog files, `.opencode` agents/skills/craft/design-systems, chat templates, and the ds4 preset; installed-wheel `doctor`, `pack list`, and `profile apply` are smoke-tested.
- [x] ds4 dry validation passed: `lac profile apply 128gb-ds4-flash --json` selects `ds4/deepseek-v4-flash`, and `lac runtime status --json` reports ds4 port/state paths.
- [x] Release local audit validates provider doc structure, trust metadata/doc alignment, and absence of tracked model/local artifacts.
- [x] Release local audit validates free cloud policy, scenario catalog/docs alignment, and Claude Code template scope.

## Trust and repo hygiene
- [x] Third-party agent and skill guidance matches the current trust model.
- [ ] GitHub Private Vulnerability Reporting is enabled. `SECURITY.md` intentionally keeps this as a release gate until repo settings are updated.
- [x] No model binaries or machine-specific files are tracked.
- [ ] Linux CI passes on the release branch.
- [x] No stale docs or deleted-path references remain in the tree.
