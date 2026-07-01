# lac Rebrand Implementation Plan

> Historical note: this plan is kept for traceability and may mention
> superseded script names, release goals, or implementation sequencing.
> Current public-beta blockers are canonical in `docs/release/gates.json`,
> `docs/release/MANUAL_VALIDATION.md`, and `RELEASE_CHECKLIST.md`.
> Use `./scripts/release-gate-report.sh` for authoritative release status.

> **For the implementer:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rebrand the repo from "local-ai-cluster / ai-coding-cluster" to "lac — Lightweight Agentic Coding", consolidate root docs from 14 to 7 files, rewrite README for beginners, and add prominent upstream attribution.

**Architecture:** File moves and text replacements only — no CLI, profile, runtime, or logic changes. Root markdown files are deleted, moved, or rewritten. Branding strings in Python source are updated. Cross-reference paths in verify scripts and docs are corrected. Existing CI, scripts, and profiles stay untouched.

**Tech Stack:** Markdown, Python, Bash, TOML. No new dependencies.

**Design spec:** `docs/superpowers/specs/2026-06-09-lac-rebrand-design.md`

---

### Task 1: Move docs to new locations

**Files:**
- Move: `CONFIG_SUMMARY.md` → `docs/config-summary.md`
- Move: `MODEL_RECOMMENDATIONS.md` → `docs/model-recommendations.md`
- Move: `ARCHITECTURE_OVERVIEW.md` → `docs/architecture.md`
- Delete: `QWEN.md`
- Delete: `REVISION_NOTES.md`
- Delete root: `CLAUDE.md`

**Step 1: Move the three docs**

```bash
git mv CONFIG_SUMMARY.md docs/config-summary.md
git mv MODEL_RECOMMENDATIONS.md docs/model-recommendations.md
git mv ARCHITECTURE_OVERVIEW.md docs/architecture.md
```

**Step 2: Delete the redundant/deprecated files**

```bash
git rm QWEN.md
git rm REVISION_NOTES.md
git rm CLAUDE.md
```

**Step 3: Commit**

```bash
git commit -m "chore: move docs to docs/, remove QWEN.md, CLAUDE.md, REVISION_NOTES.md"
```

---

### Task 2: Update LICENSE copyright line

**Files:**
- Modify: `LICENSE`

**Step 1: Edit the copyright line**

Change line 3 from:
```
Copyright (c) 2026 OpenCode AI Coding Cluster contributors
```
To:
```
Copyright (c) 2026 Lightweight Agentic Coding (lac) contributors
```

**Step 2: Commit**

```bash
git add LICENSE && git commit -m "chore: update LICENSE copyright to lac branding"
```

---

### Task 3: Update pyproject.toml

**Files:**
- Modify: `pyproject.toml`

**Step 1: Update project name and description**

Change:
```toml
name = "local-ai-cluster"
description = "Local AI Cluster CLI — profile management, runtime lifecycle, and provider orchestration"
```

To:
```toml
name = "lightweight-agentic-coding"
description = "lac — Lightweight Agentic Coding CLI. Profile management, runtime lifecycle, and provider orchestration for local AI coding."
```

**Step 2: Commit**

```bash
git add pyproject.toml && git commit -m "chore: update pyproject.toml to lac branding"
```

---

### Task 4: Update Python source branding strings

**Files:**
- Modify: `src/lac/cli.py`
- Modify: `src/lac/init.py`
- Modify: `src/lac/clients.py`
- Modify: `src/lac/lib/jsonc.py`
- Modify: `src/lac/lib/__init__.py`
- Modify: `src/lac/__init__.py`

**Step 1: Update `src/lac/cli.py`**

Line 1: Change `"""Local AI Cluster CLI — argument parsing, dispatch, and text rendering."""` to `"""lac CLI — argument parsing, dispatch, and text rendering."""`

Line 564: Change `description="Local AI Cluster 2.0 CLI"` to `description="lac — Lightweight Agentic Coding CLI"`

**Step 2: Update `src/lac/init.py`**

Line 302: Change `print("Local AI Cluster init")` to `print("  lac init — Lightweight Agentic Coding")`

**Step 3: Update `src/lac/clients.py`**

Line 51: Change `"This adapter reuses the curated Local AI Cluster workflow packs as references for Claude Code."` to `"This adapter reuses the curated lac workflow packs as references for Claude Code."`

**Step 4: Update `src/lac/__init__.py`**

Change `"""Local AI Cluster CLI."""` to `"""lac — Lightweight Agentic Coding CLI."""`

**Step 5: Update `src/lac/lib/__init__.py`**

Change `# Shared Local AI Cluster script utilities` to `# Shared lac script utilities`

**Step 6: Update `src/lac/lib/jsonc.py`**

Change `"""Shared JSONC helpers for Local AI Cluster verify scripts."""` to `"""Shared JSONC helpers for lac verify scripts."""`

**Step 7: Commit**

```bash
git add src/ && git commit -m "chore: update Python source branding to lac"
```

---

### Task 5: Update verify-documentation.sh paths

**Files:**
- Modify: `verify-documentation.sh`

**Step 1: Update the required file paths**

In the `required` array, change:
```bash
required=(
  README.md
  ARCHITECTURE_OVERVIEW.md
  MODEL_RECOMMENDATIONS.md
  CONFIG_SUMMARY.md
  REVISION_NOTES.md
  ...
)
```

To:
```bash
required=(
  README.md
  docs/architecture.md
  docs/model-recommendations.md
  docs/config-summary.md
  ...
)
```

(Remove `REVISION_NOTES.md` from the list entirely)

**Step 2: Run verify-documentation.sh to confirm it passes**

```bash
bash verify-documentation.sh
```

Expected: all checks pass (files exist at new paths).

**Step 3: Commit**

```bash
git add verify-documentation.sh && git commit -m "chore: update verify-documentation.sh for moved doc paths"
```

---

### Task 6: Update cross-references in remaining docs

**Files:**
- Modify: `docs/config-summary.md` (was CONFIG_SUMMARY.md)
- Modify: `docs/model-recommendations.md` (was MODEL_RECOMMENDATIONS.md)
- Modify: `docs/architecture.md` (was ARCHITECTURE_OVERVIEW.md)
- Modify: `.opencode/agents/architecture-reviewer.md`
- Modify: `.opencode/agents/research-synthesizer.md`
- Modify: `src/lac/data/opencode/agents/architecture-reviewer.md`
- Modify: `src/lac/data/opencode/agents/research-synthesizer.md`
- Modify: `docs/plans/replace-coder-next-with-mtp.md`

**Step 1: Find all remaining references to old file paths**

```bash
rg -l "ARCHITECTURE_OVERVIEW\.md|MODEL_RECOMMENDATIONS\.md|CONFIG_SUMMARY\.md|QWEN\.md" --glob '*.md'
```

**Step 2: Update each reference found**

Replace:
- `ARCHITECTURE_OVERVIEW.md` → `docs/architecture.md`
- `MODEL_RECOMMENDATIONS.md` → `docs/model-recommendations.md`
- `CONFIG_SUMMARY.md` → `docs/config-summary.md`
- `QWEN.md` → `docs/architecture.md` (or the most relevant section)

**Step 3: Commit**

```bash
git add docs/ .opencode/ .opencode/agents/ src/lac/data/opencode/agents/ && git commit -m "chore: update cross-references to moved doc paths"
```

---

### Task 7: Rewrite README.md

**Files:**
- Rewrite: `README.md`

**Step 1: Write the new README**

The new README (~150 lines) follows this structure per the design spec:

1. Title + one-liner
2. Attribution block (top)
3. Quick Start (3 commands)
4. Prerequisites + "New to Python or pip?" collapsible
5. "What just happened?"
6. Profile table (6 rows + 128GB note)
7. Daily use
8. Next steps (links into docs/)
9. Troubleshooting (keep existing table, update lac commands)
10. Attribution block (bottom — detailed)
11. Contributing

See the design spec for exact content of each section.

**Step 2: Verify the README is self-consistent**

Check that:
- No dead links remain
- All `lac` commands are correct
- All file paths reference the new locations
- The "Built on" attribution block includes: llama.cpp, Unsloth, OpenCode, Open Design, oMLX
- The detailed attribution includes all 8 upstream projects

**Step 3: Commit**

```bash
git add README.md && git commit -m "docs: rewrite README for lac rebrand and beginner focus"
```

---

### Task 8: Update remaining root markdown files

**Files:**
- Modify: `AGENTS.md`
- Modify: `SECURITY.md`
- Modify: `CONTRIBUTING.md`
- Modify: `CHANGELOG.md`
- Modify: `CODE_OF_CONDUCT.md` (if needed)
- Modify: `RELEASE_CHECKLIST.md`

**Step 1: Update AGENTS.md**

- Line 3: Change "This repository provides a private, replicable **Local AI Cluster**" to "This repository provides **lac — Lightweight Agentic Coding**"
- Remove line from QWEN.md that was folded in
- Update any "local-ai-cluster" references to "lac"
- Update any doc path references if they pointed to moved files

**Step 2: Update SECURITY.md**

- Line 21: Change "Do not make the repository public until a real private reporting path is active." — this stays but update any repo name references

**Step 3: Update CONTRIBUTING.md**

- Line 5: Change "This repository is a configuration-first template for OpenCode + llama.cpp." to match new branding
- Update any "local-ai-cluster" references

**Step 4: Update CHANGELOG.md**

- Merge REVISION_NOTES.md content if not already in CHANGELOG.md
- Update project name in header

**Step 5: Update CODE_OF_CONDUCT.md if it references project name**

**Step 6: Update RELEASE_CHECKLIST.md**

- Update "local-ai-cluster" references to "lac"

**Step 7: Commit**

```bash
git add AGENTS.md SECURITY.md CONTRIBUTING.md CHANGELOG.md CODE_OF_CONDUCT.md RELEASE_CHECKLIST.md && git commit -m "docs: update root docs for lac rebrand"
```

---

### Task 9: Run full verification

**Step 1: Run verification scripts**

```bash
bash verify-documentation.sh
bash scripts/verify-config-schema.sh
bash scripts/verify-profiles-sync.sh
bash scripts/verify-opencode-assets.sh
bash scripts/verify-provider-catalog.sh
bash scripts/verify-v2-contract.sh
```

Expected: all pass (or fail on pre-existing issues, not introduced by this rebrand).

**Step 2: Run CI checks locally**

```bash
bash -n scripts/*.sh
bash -n verify-*.sh
for f in runtime-config/launch/*.sh; do [ -f "$f" ] && bash -n "$f"; done
```

Expected: no syntax errors.

**Step 3: If all passes, final commit**

```bash
git commit -m "chore: final verification pass for lac rebrand" --allow-empty
```

If any checks fail, fix them in the relevant task, recommit, then re-verify.
