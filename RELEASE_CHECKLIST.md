# Public Beta Release Checklist

Use this checklist before changing the repo visibility or publishing release notes.

## Identity and framing
- [ ] Repository name, description, and README use the `local-ai-cluster` identity consistently.
- [ ] Public beta positioning is explicit: local-first, evolving, and not a stable v1.
- [ ] Any remaining private-only language is intentional and limited to release-gate docs.

## Runtime validation
- [ ] macOS or Linux path validated from a fresh clone:
  - `setup-models-device`
  - `setup-config-device`
  - `launch-llama`
  - `launch-opencode`
- [ ] Windows PowerShell path validated from a fresh clone with the equivalent scripts.
- [ ] `launch-opencode-desktop` validated on the platforms where it is documented.
- [ ] `curl http://127.0.0.1:8080/health` succeeds during smoke testing.
- [ ] `curl http://127.0.0.1:8080/v1/models` returns the expected profile models.

## OpenCode integration
- [ ] `.opencode/agents/*.md` are discoverable in a real OpenCode session.
- [ ] `.opencode/skills/*/SKILL.md` are discoverable in a real OpenCode session.
- [ ] Config regeneration preserves compaction, watcher ignores, instructions, permission policy, and provider blocks.

## Providers and docs
- [ ] Provider auth docs are current for Antigravity, z.ai, NVIDIA NIM, and OpenRouter.
- [ ] Free cloud snapshot policy is explicit and still correct.
- [ ] Onboarding scenarios are accurate for low-end, higher-end, and hosted-model workflows.
- [ ] Claude Code template docs are complete and not misleading.

## Trust and repo hygiene
- [ ] Third-party agent and skill guidance matches the current trust model.
- [ ] `SECURITY.md` contains a real public reporting path or explicitly requires GitHub private vulnerability reporting.
- [ ] No model binaries or machine-specific files are tracked.
- [ ] CI passes on the release branch.
- [ ] No stale docs or deleted-path references remain in the tree.
