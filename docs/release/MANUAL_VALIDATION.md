# Manual Validation Evidence

This file records release-blocking checks that cannot be proven by local CI alone. Keep every gate marked `open` until the exact evidence has been captured.

Run the release gate report before publishing:

```bash
./scripts/release-gate-report.sh
```

The command is expected to fail while any gate below is open.

Gate IDs, owners, required evidence text, and command bundles are defined in `docs/release/gates.json`. This file owns the current status table and the completed evidence notes.

Use the evidence helper to print the exact command bundle and evidence fields for a gate:

```bash
./scripts/release-evidence.sh <gate-id>
```

It also prints matching `RELEASE_CHECKLIST.md` item(s) and a paste-ready markdown stub with `Status: open` so you can record the evidence in this file without closing the gate until the checklist item is complete.

For command-line gates, the helper also prints a transcript capture command that writes under ignored `state/release-evidence/`. Reference that transcript in the gate evidence instead of pasting secrets or long terminal output into this file.

For a tester-friendly summary of the currently open manual gates, run:

```bash
./scripts/release-manual-next-steps.sh
```

## Gates

| Gate ID | Status | Owner | Evidence Required |
|---|---|---|---|
| `security-pvr` | open | repo owner | GitHub Private Vulnerability Reporting enabled in repository settings; `SECURITY.md` updated with the active reporting path or clear GitHub reporting instruction. |
| `fresh-clone-unix` | open | release tester | Fresh macOS or Linux clone runs `./scripts/release-fresh-clone-unix.sh --full-runtime`, which performs `python3 -m pip install .`, `lac init --yes --profile 24gb --no-cloud`, `lac models sync 24gb`, `lac runtime start`, runtime status, and `lac client render opencode`. Attach date, OS, Python version, lac version, evidence summary path, and command transcript summary. |
| `windows-powershell` | open | Windows tester | Fresh Windows clone runs `bin/lac.ps1 init --yes --profile 24gb --no-cloud`, `bin/lac.ps1 doctor`, and `bin/lac.ps1 smoke`. Attach PowerShell version, Python version, and transcript summary. |
| `llama-smoke` | open | release tester | With llama.cpp runtime running, `curl http://127.0.0.1:8080/health` and `curl http://127.0.0.1:8080/v1/models` return expected local runtime responses. |
| `ds4-128gb` | open | 128GB Apple Silicon tester | On a 128GB+ M3/M4/M5-class Apple Silicon machine, build `antirez/ds4`, run `lac models sync 128gb-ds4-flash`, `lac runtime start`, `curl http://127.0.0.1:8000/v1/models`, then launch OpenCode with the ds4 model. Attach date, hardware, macOS version, ds4 commit, model filename, and transcript summary. |
| `opencode-discovery` | open | release tester | Real OpenCode session discovers `.opencode/agents/*.md` and `.opencode/skills/*/SKILL.md` from the generated config. Attach OpenCode version and screenshot or transcript summary. |
| `provider-docs` | closed | maintainer | Provider auth docs reviewed for Antigravity, z.ai, NVIDIA NIM, OpenRouter, Anthropic, Codex auth, and OpenCode Go/Zen. Evidence recorded below. |
| `provider-live-freshness` | open | maintainer | Run live provider probes with release credentials or document why each configured provider is intentionally skipped. Attach `lac provider verify --all --json` output and any catalog refresh result. |
| `trust-docs` | closed | maintainer | Third-party agent/skill guidance reviewed against `docs/security/TRUST_MODEL.md`, `docs/security/THIRD_PARTY_AGENT_INTAKE.md`, and catalog trust metadata. Evidence recorded below. |
| `repo-binary-hygiene` | closed | maintainer | Confirm no model binaries or machine-specific files are tracked. Evidence recorded below. |
| `linux-ci` | open | maintainer | Confirm Linux CI is green on the release branch. Attach workflow URL, commit SHA, and run result. |

## Evidence Template

```markdown
### Gate: <gate-id>

- Status: closed
- Date:
- Tester:
- Environment:
- Commands:
- Result:
- Evidence:
- Notes:
```

Move a gate to `closed` only after the evidence above is complete and `RELEASE_CHECKLIST.md` has the matching item checked. `./scripts/release-gate-report.sh` fails if a closed gate lacks a matching `### Gate: <gate-id>` evidence section or any required evidence field.

### Gate: trust-docs

- Status: closed
- Date: 2026-06-30
- Tester: Codex
- Environment: macOS local repo audit
- Commands:
  - `./scripts/release-local-audit.sh`
  - `./scripts/release-local-audit.sh --json`
- Result: passed
- Evidence:
  - `docs/security/TRUST_MODEL.md` now describes bundled Open Design assets as community/optional/not-reviewed until a maintainer performs deeper review.
  - `docs/security/THIRD_PARTY_AGENT_INTAKE.md` now documents Open Design imports as a community design/reference layer, not core trusted automation.
  - `catalog/assets.json` summary from the audit: 41 assets; 12 core reviewed assets, 27 community optional not-reviewed Open Design assets, 1 trimmed-and-reviewed adapted skill, and 1 opt-in-reviewed Microsoft Graph skill.
- Notes: This closes local trust-doc alignment only. It does not close provider freshness, real OpenCode discovery, or external runtime validation.

### Gate: repo-binary-hygiene

- Status: closed
- Date: 2026-06-30
- Tester: Codex
- Environment: macOS local repo audit
- Commands:
  - `./scripts/release-local-audit.sh`
  - `git ls-files`
- Result: passed
- Evidence:
  - Release local audit reported `tracked_model_artifacts: []`.
  - `.gitignore` contains `models/**`, `state/**`, `.qwen/`, and `.claude/`.
  - Allowed tracked placeholder/docs remain limited to `models/.gitkeep`, `models/README.md`, and `state/README.md`.
- Notes: Linux CI status remains a separate open `linux-ci` gate.

### Gate: provider-docs

- Status: closed
- Date: 2026-06-30
- Tester: Codex
- Environment: macOS local repo audit plus documentation spot checks
- Commands:
  - `./scripts/release-local-audit.sh --json`
  - `./bin/lac provider list --json`
  - `./bin/lac provider verify --all --json`
- Result: passed for local provider documentation structure; live probes skipped or blocked as expected
- Evidence:
  - Release local audit checked 8 provider docs covering Antigravity, z.ai, NVIDIA NIM, OpenRouter, OpenCode Zen, OpenCode Go, Codex auth, and Anthropic.
  - `lac provider list --json` returned all 9 configured provider entries including `local-cluster`.
  - `lac provider verify --all --json` skipped cloud providers because API key env vars were not set: `ANTIGRAVITY_API_KEY`, `ZAI_API_KEY`, `NVIDIA_API_KEY`, `OPENROUTER_API_KEY`, `OPENCODE_ZEN_API_KEY`, `OPENCODE_GO_API_KEY`, `OPENAI_API_KEY`, and `ANTHROPIC_API_KEY`.
  - Local cluster probe returned connection refused because the local runtime was not running; that remains covered by `llama-smoke`.
  - Official documentation spot checks were performed for OpenRouter API reference, Anthropic models API, Z.AI developer docs, and NVIDIA NIM docs on 2026-06-30.
- Notes: This closes local documentation coverage only. Live provider freshness remains open under `provider-live-freshness`.
