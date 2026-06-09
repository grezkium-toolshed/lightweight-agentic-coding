# Release Documentation Index

This folder tracks release-readiness guidance for the public beta.

## Canonical docs

- `docs/release/STATE.md`: current release phase, open questions, and next-session focus
- `docs/release/BETA_RELEASE_CRITERIA.md`: definition of beta quality for this repo
- `docs/release/PRIVATE_UNTIL_RELEASE.md`: privacy and release-gate policy
- `RELEASE_CHECKLIST.md`: operational release gate checklist

## Current release posture

- The repository remains private until release gates are complete.
- CI exists at `.github/workflows/ci.yml`, is Linux-based for now, and remains part of pre-release validation.
- Runtime and docs validation must stay aligned with the current scripts and profile contracts.

## Naming and path policy

- Product and docs name: `lac` — Lightweight Agentic Coding
- Repository slug/path: `lightweight-agentic-coding`
- This split is temporary and acceptable during pre-release hardening.
