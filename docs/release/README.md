# Release Documentation Index

This folder tracks release-readiness guidance for the public beta. This is not a stable v1 release track.

## Canonical docs

- `docs/release/STATE.md`: current release phase, open questions, and next-session focus
- `docs/release/BETA_RELEASE_CRITERIA.md`: definition of beta quality for this repo
- `docs/release/gates.json`: canonical manual gate metadata, command bundles, and evidence prompts
- `docs/release/MANUAL_VALIDATION.md`: evidence ledger for release-blocking manual gates
- `RELEASE_CHECKLIST.md`: operational release gate checklist

## Release gate command

Run this before publishing a public beta:

```bash
./scripts/release-gate-report.sh
```

It exits non-zero while any release-blocking checklist item or manual validation gate is still open.

For gate-specific command bundles and evidence prompts, run:

```bash
./scripts/release-evidence.sh list
./scripts/release-evidence.sh fresh-clone-unix
```

The helper also prints matching `RELEASE_CHECKLIST.md` item(s) and a paste-ready evidence stub with `Status: open` so you can capture notes in `docs/release/MANUAL_VALIDATION.md` without closing the gate early.

For command-line gates, the helper also prints a transcript capture command that writes under ignored `state/release-evidence/`.

For a quick handoff view of the currently open manual gates, run:

```bash
./scripts/release-manual-next-steps.sh
```

The handoff helper lists each open gate owner, summary, exact `./scripts/release-evidence.sh <gate-id>` command, and matching checklist item(s). Pass `--json` when another tool needs the full command bundle from `docs/release/gates.json`.

To run the local automated beta gate suite in one command, run:

```bash
./scripts/verify-public-beta-local.sh
```

This wrapper runs the non-manual checks and then summarizes the still-open manual gates without treating missing external evidence as an automated failure.

## Current release posture

- CI exists at `.github/workflows/ci.yml`, is Linux-based for now, and remains part of pre-release validation.
- Runtime and docs validation must stay aligned with the current scripts and profile contracts.

## Naming and path policy

- Product and docs name: `lac` — Lightweight Agentic Coding
- Repository slug/path: `lightweight-agentic-coding`
- This split is temporary and acceptable during pre-release hardening.
