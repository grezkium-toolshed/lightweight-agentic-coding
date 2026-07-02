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

The summary includes the owner, short gate summary, exact `./scripts/release-evidence.sh <gate-id>` command, and matching checklist item(s). Use `--json` to inspect the full command bundle and evidence fields for automation.

## Gates

| Gate ID | Status | Owner | Evidence Required |
|---|---|---|---|
| `security-pvr` | open | repo owner | Automated/local rehearsal runs `./scripts/release-security-pvr.sh --allow-unavailable` and writes generated evidence under `state/release-evidence/`, but this gate remains open until a repo owner/admin enables GitHub Private Vulnerability Reporting in GitHub repository settings. Manual release evidence runs `./scripts/release-security-pvr.sh --confirm-enabled --screenshot <reference>` after enabling. Attach generated evidence summary path, GitHub docs/settings path (`Settings > Code security and analysis > Private vulnerability reporting` or repository `Settings > Advanced Security`), `gh repo view` metadata, security policy URL, `SECURITY.md` wording check, repo owner/admin confirmation, date enabled, and screenshot/reference from repository Settings > Advanced Security showing Private vulnerability reporting enabled. |
| `fresh-clone-unix` | open | release tester | Fresh macOS or Linux clone runs `./scripts/release-fresh-clone-unix.sh --full-runtime`, which performs `python3 -m pip install .`, `lac init --yes --profile 24gb --no-cloud`, `lac models sync 24gb`, `lac runtime start`, runtime status, and `lac client render opencode`. Attach date, OS, Python version, lac version, evidence summary path, and command transcript summary. |
| `windows-powershell` | open | Windows tester | Manual release evidence runs `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/release-windows-powershell.ps1 -FullRuntime` from a fresh Windows clone and writes generated evidence under `state/release-evidence/`. Optional no-runtime Windows rehearsal may run the same helper with `-NoRuntime`, but this gate remains open until real Windows fresh-clone proof exists. Attach Windows OS details, PowerShell version, Python version/path, git commit, `bin/lac.ps1 --version`, `bin/lac.ps1 init --yes --profile 24gb --no-cloud --json`, `bin/lac.ps1 doctor --bootstrap-hint --json`, `bin/lac.ps1 smoke --json`, transcript/summary path, and, when `-FullRuntime` is used, model sync/runtime start/status evidence captured by the helper. |
| `llama-smoke` | open | release tester | With llama.cpp runtime running, `./scripts/release-llama-smoke.sh` confirms `curl http://127.0.0.1:8080/health`, `curl http://127.0.0.1:8080/v1/models`, and `lac smoke --json` return expected local runtime responses. |
| `ds4-128gb` | open | 128GB Apple Silicon tester | Automated/local rehearsal runs `./scripts/release-ds4-128gb.sh --dry-run --allow-missing-ds4` and writes generated evidence under `state/release-evidence/`, but this gate remains open until real 128GB+ hardware proof exists. On a 128GB+ M3/M4/M5-class Apple Silicon machine with `antirez/ds4` built and the model synced, run `./scripts/release-ds4-128gb.sh --full-runtime`. Attach generated evidence summary path, hardware/RAM/macOS details, ds4 binary path plus version or commit, `lac profile apply 128gb-ds4-flash --json` output, runtime status showing ds4 paths and port 8000, `lac models sync 128gb-ds4-flash` evidence from the manual full-runtime run, `curl http://127.0.0.1:8000/v1/models` output, and OpenCode ds4 model selection/session notes. |
| `opencode-discovery` | open | release tester | Automated rehearsal runs `./scripts/release-opencode-discovery.sh --skip-open --allow-missing-opencode` and writes repeatable evidence under `state/release-evidence/`. The gate remains open until a real OpenCode session runs `./scripts/release-opencode-discovery.sh --open` and proves discovery of generated `.opencode/agents/*.md` and `.opencode/skills/*/SKILL.md`. Attach OpenCode version, rendered config path, repo/package agent and skill counts, evidence summary path, and screenshot, transcript, or manual session notes from the real OpenCode session. |
| `provider-docs` | closed | maintainer | Provider auth docs reviewed for Antigravity, z.ai, NVIDIA NIM, OpenRouter, Anthropic, Codex auth, and OpenCode Go/Zen. Evidence recorded below. |
| `provider-live-freshness` | open | maintainer | Run `./scripts/release-provider-freshness.sh --refresh-catalog` with release credentials, or document why each configured provider is intentionally skipped. Attach the generated evidence summary, `provider-verify.json`, and any OpenRouter catalog refresh result. |
| `trust-docs` | closed | maintainer | Third-party agent/skill guidance reviewed against `docs/security/TRUST_MODEL.md`, `docs/security/THIRD_PARTY_AGENT_INTAKE.md`, and catalog trust metadata. Evidence recorded below. |
| `repo-binary-hygiene` | closed | maintainer | Confirm no model binaries or machine-specific files are tracked. Evidence recorded below. |
| `linux-ci` | open | maintainer | Automated/local rehearsal runs `./scripts/release-linux-ci.sh --allow-unavailable` and writes generated evidence under `state/release-evidence/`, but this gate remains open until GitHub Actions evidence proves `.github/workflows/ci.yml` completed successfully for the release commit. Manual release evidence runs `./scripts/release-linux-ci.sh --run-id <run-id>` after CI finishes. Attach generated evidence summary path, workflow URL, commit SHA, run status/conclusion, selected run ID, branch, workflow name, and confirmation that `.github/workflows/ci.yml` includes the Linux integration/package/docs/schema checks. |

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
