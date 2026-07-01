# Public Release Preparation Plan

> Historical note: this plan is kept for traceability and may mention
> superseded script names, release goals, or implementation sequencing.
> Current public-beta blockers are canonical in `docs/release/gates.json`,
> `docs/release/MANUAL_VALIDATION.md`, and `RELEASE_CHECKLIST.md`.
> Use `./scripts/release-gate-report.sh` for authoritative release status.

> **For the implementer:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prepare the repo for public release — fix failing Linux CI, rename env vars, remove all private-repo language, fix incomplete indexes, sync package data, and polish for first public impression.

**Architecture:** Text replacements and file management — no CLI, runtime, or logic changes. Env var rename touches ~8 files. Private language removal touches ~8 files. Index updates touch 4 files. Package data sync is a file copy. The CI workflow gets diagnostic scaffolding to identify the failing step, then a targeted fix.

**Tech Stack:** Bash, Python, Markdown, YAML, JSON. No new dependencies.

**Design spec:** N/A (derived from public-readiness review findings)

---

### Task 1: CI Diagnostic Scaffolding

**Files:**
- Modify: `.github/workflows/ci.yml`

**Step 1: Add step names, verbose tracing, and upgrade checkout action**

Replace the current workflow with a version that:
1. Upgrades `actions/checkout@v4` → `actions/checkout@v5`
2. Adds `set -x` to every step for verbose tracing
3. Adds unique step names for log filtering
4. Does NOT use `continue-on-error` — let CI fail naturally so the failing step is unambiguous

```yaml
name: CI

on:
  push:
  pull_request:

jobs:
  validate-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - name: Bash Syntax Check
        run: |
          set -x
          bash -n scripts/*.sh
          bash -n verify-*.sh
          for f in runtime-config/launch/*.sh; do [ -f "$f" ] && bash -n "$f"; done

      - name: Config Schema Check
        run: |
          set -x
          ./scripts/verify-config-schema.sh

      - name: Profile and Preset Parity Check
        run: |
          set -x
          ./scripts/verify-profiles-sync.sh

      - name: Documentation Consistency Check
        run: |
          set -x
          ./verify-documentation.sh

      - name: OpenCode Asset Schema Check
        run: |
          set -x
          ./scripts/verify-opencode-assets.sh

      - name: Provider Catalog Validation
        run: |
          set -x
          ./scripts/verify-provider-catalog.sh

      - name: V2 CLI Contract Check
        run: |
          set -x
          ./scripts/verify-v2-contract.sh

      - name: Agent and Skill Presence Check
        run: |
          set -x
          test -f .opencode/agents/architecture-reviewer.md
          test -f .opencode/agents/release-reviewer.md
          test -f .opencode/agents/reality-checker.md
          test -f .opencode/skills/docx-workflow/SKILL.md
          test -f .opencode/skills/pptx-workflow/SKILL.md
          test -f .opencode/skills/xlsx-workflow/SKILL.md

      - name: Public Beta Asset Presence Check
        run: |
          set -x
          test -f RELEASE_CHECKLIST.md
          test -f state/README.md
          test -f catalog/assets.json
          test -f catalog/workflow-packs.json
          test -f catalog/providers.json
          test -f catalog/scenarios.json
          test -f .github/ISSUE_TEMPLATE/config.yml
          test -f .github/ISSUE_TEMPLATE/bug_report.md
          test -f .github/ISSUE_TEMPLATE/docs_mismatch.md
          test -f .github/ISSUE_TEMPLATE/provider_model_drift.md
          test -f .github/ISSUE_TEMPLATE/hardware_profile_request.md
```

**Step 2: Commit and push to trigger CI**

```bash
git add .github/workflows/ci.yml && git commit -m "ci: add verbose tracing and step names to isolate Linux failure"
```

**Step 3: Check CI logs**

After push, inspect the GitHub Actions run. The step that fails will show the error in the GitHub run log. Identify the failing step and its exact error message.

**Step 4: Fix the actual failure**

Based on the CI log output, fix the failing step. If CI passes (green), skip this step.

**Step 5: Remove set -x scaffolding**

After CI is green, remove `set -x` from all steps:
```bash
git add .github/workflows/ci.yml && git commit -m "ci: remove verbose tracing, CI green"
```

---

### Task 2: Rename AI_CLUSTER_* Env Vars to LAC_*

**Files:**
- Modify: `scripts/lac.py`
- Modify: `src/lac/context.py`
- Modify: `src/lac/cli.py`
- Modify: `src/lac/packs.py`
- Modify: `scripts/verify-v2-contract.sh`
- Modify: `scripts/integration-test.sh`
- Modify: `state/README.md`

**Step 1: Find all occurrences**

```bash
rg -n "AI_CLUSTER_" --type py --type sh --type md -g '!node_modules' -g '!.git'
```

**Step 2: Rename each occurrence in all files**

Apply exact string replacements in each file. Use the Edit tool with `replaceAll` to change each env var name:

| Old | New |
|-----|-----|
| `AI_CLUSTER_STATE_ROOT` | `LAC_STATE_ROOT` |
| `AI_CLUSTER_PORT` | `LAC_PORT` |
| `AI_CLUSTER_HOST` | `LAC_HOST` |
| `AI_CLUSTER_INSTALL_DCP` | `LAC_INSTALL_DCP` |
| `AI_CLUSTER_OPENCODE_SKILLS_DIR` | `LAC_OPENCODE_SKILLS_DIR` |

**Step 3: Add backward-compat fallback in Python code**

In `scripts/lac.py` and `src/lac/context.py`, add a fallback pattern so existing shell configs with `AI_CLUSTER_*` vars don't silently break. For each env var lookup, check `LAC_*` first, then fall back to `AI_CLUSTER_*` with a deprecation warning printed to stderr.

Example pattern (in `scripts/lac.py:30`):
```python
import sys

def _env_or_deprecated(new_key, old_key, default=None):
    val = os.environ.get(new_key)
    if val is not None:
        return val
    val = os.environ.get(old_key)
    if val is not None:
        print(f"Warning: {old_key} is deprecated, use {new_key} instead", file=sys.stderr)
        return val
    return default

STATE_ROOT = Path(_env_or_deprecated("LAC_STATE_ROOT", "AI_CLUSTER_STATE_ROOT", str(ROOT / "state")))
```

Apply the same pattern to: `LAC_PORT`, `LAC_HOST`, `LAC_INSTALL_DCP`, `LAC_OPENCODE_SKILLS_DIR`.

**Step 4: Verify no remaining bare AI_CLUSTER_ references**

```bash
rg "AI_CLUSTER_" --type py --type sh --type md -g '!node_modules' -g '!.git'
```

Expected: only references appear inside the deprecation fallback functions (which reference the old name for backward compat). No bare env var lookups using `AI_CLUSTER_`.

**Step 5: Commit**

```bash
git add scripts/lac.py src/lac/context.py src/lac/cli.py src/lac/packs.py scripts/verify-v2-contract.sh scripts/integration-test.sh state/README.md
git commit -m "refactor: rename AI_CLUSTER_* env vars to LAC_* with backward-compat fallback"
```

---

### Task 3: Remove Private-Repo Language

**Files:**
- Delete: `docs/release/PRIVATE_UNTIL_RELEASE.md`
- Modify: `AGENTS.md`
- Modify: `SECURITY.md`
- Modify: `README.md`
- Modify: `docs/architecture.md`
- Modify: `docs/config-summary.md`
- Modify: `docs/release/README.md`
- Modify: `templates/claude-code/CLAUDE.md`
- Modify: `CONTRIBUTING.md`

**Step 1: Delete PRIVATE_UNTIL_RELEASE.md**

```bash
git rm docs/release/PRIVATE_UNTIL_RELEASE.md
```

**Step 2: Update AGENTS.md**

Remove line: `This repo is intentionally private until the release gates in docs/release/PRIVATE_UNTIL_RELEASE.md are complete.`

**Step 3: Update SECURITY.md**

Replace the private-repo language with standard GitHub Security Advisories info:
- Remove "Do not make the repository public until a real private reporting path is active."
- Add: "To report a security vulnerability, use [GitHub Security Advisories](https://github.com/TuukkaTanner/lightweight-agentic-coding/security/advisories)."

**Step 4: Fix README clone URL**

Replace `git clone https://github.com/<user>/lightweight-agentic-coding` → `git clone https://github.com/TuukkaTanner/lightweight-agentic-coding.git`

**Step 5: Fix docs/architecture.md**

Remove line: `The repo should remain private until the release gates in docs/release/PRIVATE_UNTIL_RELEASE.md are complete.`

**Step 6: Fix docs/config-summary.md**

Remove line: `This repo is still private by design. Public release should happen only after the release-gate checklist is complete.`

**Step 7: Fix docs/release/README.md**

Remove line: `The repository remains private until release gates are complete.`

**Step 8: Fix templates/claude-code/CLAUDE.md**

Remove line: `Do not assume public-release readiness; the repo is intentionally private until release gates are met.`

**Step 9: Fix CONTRIBUTING.md**

Update the pre-release language. Change line 7 from "pre-beta — public contributions welcome once release gates are complete" to standard contribution guidance.

**Step 10: Verify no remaining private language**

```bash
rg -i "intentionally private|remain.*private|do not make.*public|until release gates" --type md -g '!docs/plans' -g '!docs/superpowers'
```

Expected: no output (except in historical docs like plans/specs).

**Step 11: Commit**

```bash
git add docs/release/PRIVATE_UNTIL_RELEASE.md AGENTS.md SECURITY.md README.md docs/architecture.md docs/config-summary.md docs/release/README.md templates/claude-code/CLAUDE.md CONTRIBUTING.md
git commit -m "docs: remove all private-repo language, fix README clone URL"
```

---

### Task 4: Fix Template Branding + Sync Package Data

**Files:**
- Modify: `opencode.template.jsonc`
- Modify: `src/lac/data/opencode/opencode.template.jsonc`
- Create/Copy: `src/lac/data/opencode/agents/devops-reviewer.md`

**Step 1: Fix "local AI Cluster" in both template copies**

In both files, replace `"local AI Cluster setup"` → `"lac setup"`

**Step 2: Sync devops-reviewer agent**

```bash
cp .opencode/agents/devops-reviewer.md src/lac/data/opencode/agents/devops-reviewer.md
```

**Step 3: Verify the branding fix was applied**

```bash
rg '"lac setup"' opencode.template.jsonc src/lac/data/opencode/opencode.template.jsonc
rg '"local AI Cluster setup"' opencode.template.jsonc src/lac/data/opencode/opencode.template.jsonc
```

Expected: first command finds 2 matches, second command finds 0.

**Step 4: Verify devops-reviewer agent was copied**

```bash
diff .opencode/agents/devops-reviewer.md src/lac/data/opencode/agents/devops-reviewer.md && echo "identical"
```

**Step 5: Commit**

```bash
git add opencode.template.jsonc src/lac/data/opencode/opencode.template.jsonc src/lac/data/opencode/agents/devops-reviewer.md
git commit -m "fix: update template branding, sync package data agents"
```

---

### Task 5: Fix Incomplete Indexes and Counts

**Files:**
- Modify: `agents/README.md`
- Modify: `skills/README.md`
- Modify: `AGENTS.md`

**Step 1: Fix agents/README.md**

Add `devops-reviewer` to the agent index table. The agent file already exists at `.opencode/agents/devops-reviewer.md`.

**Step 2: Fix skills/README.md**

Expand from 7 to 35 skills. List all skill directories from `.opencode/skills/` in the index table. Use this table format:

```markdown
| Skill | Directory | Description |
|-------|-----------|-------------|
| docx-workflow | `.opencode/skills/docx-workflow/` | Create or revise .docx documents |
| pptx-workflow | `.opencode/skills/pptx-workflow/` | Build or revise PowerPoint decks |
| ... | ... | ... |
```

To discover all skills:
```bash
ls -1 .opencode/skills/ | grep -v msgraph
```

Read each `SKILL.md` frontmatter (first 10 lines) to extract the description. The existing README already has a format — match it exactly, just add the missing 28 entries.

**Step 3: Fix AGENTS.md counts**

Change "33 curated design/HTML/image/research skills" → "35 curated skills" (verified by `scripts/verify-opencode-assets.sh` output).
Verify agent count is correct (6).

**Step 4: Commit**

```bash
git add agents/README.md skills/README.md AGENTS.md
git commit -m "docs: fix agent/skill indexes and counts"
```

---

### Task 6a: Clean Up Stale Artifacts + Add CODEOWNERS + Fix .gitignore

**Files:**
- Delete: `src/local_ai_cluster.egg-info/` (entire directory)
- Create: `.github/CODEOWNERS`
- Modify: `.gitignore`

**Step 1: Clean up stale egg-info with old package name**

```bash
rm -rf src/local_ai_cluster.egg-info/
```

**Step 2: Add CODEOWNERS**

```bash
cat > .github/CODEOWNERS << 'EOF'
* @TuukkaTanner
EOF
```

**Step 3: Fix .gitignore**

Verify and add Python build artifact entries if not present:
```
__pycache__/
*.egg-info/
dist/
build/
```

**Step 4: Commit**

```bash
git add .github/CODEOWNERS .gitignore
git rm -rf src/local_ai_cluster.egg-info/ 2>/dev/null || true
git commit -m "chore: clean stale egg-info, add CODEOWNERS, fix gitignore"
```

---

### Task 6b: Fix CHANGELOG, RELEASE_CHECKLIST, and Audit Findings

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `RELEASE_CHECKLIST.md`
- Modify: `docs/audit-findings.md`

**Step 1: Fix CHANGELOG.md**

Update the `[0.1.0]` entry description from "Initial public beta preparation" to "First public release with lac — Lightweight Agentic Coding rebrand." Keep the date (2026-04-27) but note that this corresponds to when the initial codebase was versioned.

**Step 2: Fix RELEASE_CHECKLIST.md**

Add a header note: "This document tracks release readiness. Items marked [x] are complete; open items are gating factors."
Mark items that are now complete (doc moves, branding updates, README rewrite). Leave CI, Windows validation, and fresh-clone as pending.

**Step 3: Fix docs/audit-findings.md**

For each resolved finding, add a resolution note with date:
- C2 (CI glob fragility): Resolved — fixed with guarded `for` loop
- Any branding-related findings: Resolved — lac rebrand (2026-06-09)

**Step 4: Commit**

```bash
git add CHANGELOG.md RELEASE_CHECKLIST.md docs/audit-findings.md
git commit -m "docs: update changelog, release checklist, and audit findings for public release"
```

---

### Task 6c: Fix CONTRIBUTING.md and verify-coherence.sh

**Files:**
- Modify: `CONTRIBUTING.md`
- Modify: `verify-coherence.sh`

**Step 1: Fix CONTRIBUTING.md commands**

Update outdated script references. Search for:
- `./scripts/setup-config-device.sh --profile 24gb` → `./bin/lac profile apply 24gb`
- `./scripts/doctor.sh --bootstrap-hint` → `./bin/lac doctor`
- Any `./scripts/*.sh` commands that should use `./bin/lac` instead

Also update the pre-release contribution language from "pre-beta — public contributions welcome once release gates are complete" to standard open-source contribution guidance.

**Step 2: Fix verify-coherence.sh**

Replace the trivial 3-line script that just calls `scripts/doctor.sh` with:
```bash
#!/bin/bash
set -euo pipefail
exec ./bin/lac doctor "$@"
```

**Step 3: Commit**

```bash
git add CONTRIBUTING.md verify-coherence.sh
git commit -m "docs: update contributing guide, fix verify-coherence script"
```

---

### Task 7: Final Verification + CI Badge

**Files:**
- Modify: `README.md`

**Step 1: Add CI badge to README**

After CI passes, add:
```markdown
[![CI](https://github.com/TuukkaTanner/lightweight-agentic-coding/actions/workflows/ci.yml/badge.svg)](https://github.com/TuukkaTanner/lightweight-agentic-coding/actions/workflows/ci.yml)
```

**Step 2: Run full verification locally**

```bash
bash verify-documentation.sh
bash scripts/verify-config-schema.sh
bash scripts/verify-profiles-sync.sh
bash scripts/verify-opencode-assets.sh
bash scripts/verify-provider-catalog.sh
bash scripts/verify-v2-contract.sh
bash -n scripts/*.sh
bash -n verify-*.sh
for f in runtime-config/launch/*.sh; do [ -f "$f" ] && bash -n "$f"; done
```

**Step 3: Test pip install**

```bash
pip install -e .
lac --version
```

**Step 4: Final grep for any missed old branding**

```bash
rg "local-ai-cluster|Local AI Cluster|AI_CLUSTER_" --type py --type sh --type md --type json --type toml -g '!docs/plans' -g '!docs/superpowers' -g '!node_modules' -g '!.git'
```

Expected: zero results.

**Step 5: Commit final changes**

```bash
git add README.md && git commit -m "docs: add CI badge, final verification pass"
```

---

### Task 8: Fresh-Clone Validation

> **Precondition:** This task runs ONLY after CI is green from Task 1. Do not proceed with fresh-clone validation while Linux CI still fails.

**Step 1: Clone fresh**

```bash
cd /tmp
git clone https://github.com/TuukkaTanner/lightweight-agentic-coding.git lac-fresh-test
cd lac-fresh-test
```

**Step 2: Run pip install**

```bash
pip install -e .
lac --version
```

**Step 3: Run doctor**

```bash
lac doctor
```

**Step 4: Verify CLI commands work**

```bash
lac profile list
lac provider list
lac pack list
```

**Step 5: Verify verify scripts work**

```bash
bash verify-documentation.sh
bash scripts/verify-config-schema.sh
bash scripts/verify-profiles-sync.sh
bash scripts/verify-opencode-assets.sh
bash scripts/verify-provider-catalog.sh
```

**Step 6: Clean up test clone**

```bash
cd /tmp && rm -rf lac-fresh-test
```

**Step 7: Mark RELEASE_CHECKLIST C8 as done**

Update `RELEASE_CHECKLIST.md` to mark fresh-clone validation complete.
