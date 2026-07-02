# Public Beta Release Criteria

This repo is targeting a public beta, not a stable v1.

## What beta means here
- the runtime and profile API are intended to be usable now
- provider and model recommendations may still drift
- docs, agents, and skills are curated but still evolving
- feedback about onboarding friction is expected and useful

## What must be true before release
- `RELEASE_CHECKLIST.md` is complete
- `docs/release/MANUAL_VALIDATION.md` has every gate marked closed with evidence
- `./scripts/release-gate-report.sh` exits successfully
- Linux CI checks in `.github/workflows/ci.yml` are green on current default branch
- live validation has been performed on the release-blocking documented paths in `docs/release/gates.json`; non-gating profiles remain identified by verification tier and are not marketed as hardware-validated until evidence exists
- repo naming and public framing are consistent with `lac` — Lightweight Agentic Coding
- no stale or archived branches remain in the active tree
