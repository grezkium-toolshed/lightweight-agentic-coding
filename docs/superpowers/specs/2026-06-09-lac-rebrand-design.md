# lac Rebrand Design Spec

**Date:** 2026-06-09
**Status:** Approved
**Scope:** Rebrand repo from "local-ai-cluster / ai-coding-cluster" to "lac — Lightweight Agentic Coding", reposition for beginners, consolidate root docs, and add prominent upstream attribution.

## Target user

Knows about local AI coding tools (Codex, OpenClaw, Hermes) but hasn't set up OpenCode/llama.cpp. Doesn't know about model quants, parameter tuning, or model families. Wants to try local agentic coding without being an expert.

## Killer features

1. **Zero-friction first run** — clone, 3 commands, coding with a local model
2. **Hardware-aware model matching** — user doesn't pick quants; `lac init` detects hardware and recommends a profile

## Naming

| What | Name |
|---|---|
| Repo | `lightweight-agentic-coding` |
| CLI | `lac` |
| Brand | lac — Lightweight Agentic Coding |

## Design decisions

- MIT license (unchanged), copyright line updated to "Lightweight Agentic Coding (lac) contributors"
- Skills and agents (33+6+12+20 under `.opencode/`) all kept, discoverable via README links
- Platforms: macOS/Linux/Windows equal treatment, macOS noted as most tested
- Install: `pip install .` with per-OS prerequisite help for beginners
- Attribution: prominent blocks at README top and bottom
- CLI, profiles, presets, runtime, catalogs, CI, scripts all unchanged

## Root document consolidation

14 → 7 files at root. Target root:

```
README.md
AGENTS.md
CHANGELOG.md
CODE_OF_CONDUCT.md
CONTRIBUTING.md
LICENSE
SECURITY.md
```

### File actions

| File | Action |
|---|---|
| `QWEN.md` | Fold overview content into README. Delete. |
| `CLAUDE.md` | Move to `templates/claude-code/CLAUDE.md` (already exists there). Delete root copy. |
| `REVISION_NOTES.md` | Merge into CHANGELOG.md. Delete. |
| `CONFIG_SUMMARY.md` | Move to `docs/config-summary.md`. |
| `MODEL_RECOMMENDATIONS.md` | Move to `docs/model-recommendations.md`. |
| `ARCHITECTURE_OVERVIEW.md` | Move to `docs/architecture.md`. |
| `README.md` | Complete rewrite (~150 lines, beginner-focused). |
| `RELEASE_CHECKLIST.md` | Already duplicated in `docs/release/`. Keep root copy, update identity references. |
| `AGENTS.md` | Update branding references to "lac — Lightweight Agentic Coding". |
| `CHANGELOG.md` | Merge REVISION_NOTES.md content. Update project name. |
| `SECURITY.md` | Update repo name reference. |
| `CONTRIBUTING.md` | Update branding references. |
| `CODE_OF_CONDUCT.md` | Update project name reference if present. |
| `LICENSE` | Update copyright line only. |

### Reference updates

All internal doc paths (e.g., README links to `ARCHITECTURE_OVERVIEW.md`) must be updated to new locations. Cross-references in `docs/` files must point to `docs/` paths, not root.

## README structure

~150 lines with this structure:

1. **Title + one-liner** — "lac — Lightweight Agentic Coding. Clone, run 3 commands, start coding with a local AI model."
2. **Attribution block (top)** — "Built on" section naming upstream projects
3. **Quick Start** — 3-command path, identical across macOS/Linux/Windows
4. **Prerequisites** — collapsible "New to Python or pip?" with per-OS install instructions using `python3 -m pip`
5. **"What just happened?"** — plain-language explanation of profiles, local server, client
6. **Profile table** — 6 rows (micro, 16gb, 24gb, 32gb, openrouter) + note about 128GB power user options. macOS tested-most-thoroughly note
7. **Daily use** — common commands
8. **Next steps** — links into docs/ for cloud providers, advanced profiles, oMLX, skills & agents
9. **Attribution block (bottom)** — detailed acknowledgment of each upstream project

## Attribution

### Top block (right after one-liner)

> Built on [llama.cpp](https://github.com/ggml-org/llama.cpp), [Unsloth](https://unsloth.ai) model quantizations, [OpenCode](https://opencode.ai), and [Open Design](https://open-design.ai). With optional support for [oMLX](https://github.com/danielzgtg/omlx).

### Bottom block (before Contributing)

> ## Acknowledgments
>
> lac is a thin orchestration layer standing on the shoulders of:
> - **[llama.cpp](https://github.com/ggml-org/llama.cpp)** by Georgi Gerganov and contributors — the local inference engine
> - **[Unsloth](https://unsloth.ai)** — model quantizations and tuning guidance for Qwen and Gemma families
> - **[OpenCode](https://opencode.ai)** — the agentic coding client
> - **[Open Design](https://open-design.ai)** by nexu-io — design skills, craft rulebooks, and brand design systems
> - **[oMLX](https://github.com/danielzgtg/omlx)** — optional macOS MLX inference backend
> - **[OpenChamber](https://github.com/openchamber/openchamber)** by @btriapitsyn — web/mobile/desktop remote access
> - **[free-coding-models](https://github.com/vava-nessa/free-coding-models)** by @vava-nessa — free cloud model index and NIM helper tooling
> - **[Qwen](https://github.com/QwenLM/Qwen)** and **[Gemma](https://ai.google.dev/gemma)** model families

## Install path improvements

The prerequisites section must address the #1 friction: beginners not knowing how to use pip.

Collapsible `<details>` block "New to Python or pip?" with per-OS instructions:
- macOS: `python3 --version` → if missing or <3.10: `brew install python`. Then `python3 -m pip install --user ./lightweight-agentic-coding`
- Linux: `python3 --version` → if missing: `sudo apt install python3 python3-pip`. Then `python3 -m pip install --user ./lightweight-agentic-coding`
- Windows: `py -3 --version` → if missing: `winget install Python.Python.3.12`. Then `py -3 -m pip install ./lightweight-agentic-coding`

Always use `python3 -m pip` (the "always works" form that doesn't depend on `pip` being on PATH).

## What stays the same

- CLI (`lac`) — all subcommands, flags, `--json` output, exit codes
- Profile system — `runtime-config/profiles.json`, `.ini` presets, `lac profile apply`
- Agent and skill files — `.opencode/agents/`, `.opencode/skills/`, `.opencode/craft/`, `.opencode/design-systems/`
- Template — `opencode.template.jsonc`
- Runtime — llama.cpp-first, `state/` structure, port 8080, oMLX fallback
- Catalogs — `catalog/` JSON files, `lac catalog sync-free`, provider verification
- CI — `.github/workflows/ci.yml` (may need path updates for moved docs)
- Scripts — `scripts/` and `verify-*.sh` (may need path corrections for moved docs)

## Package identity

`pyproject.toml` updates:
- `name` → `lightweight-agentic-coding`
- `description` → updated to match new branding
- Entry point stays `lac`

## Files touched

Primary changes:
- `README.md` — complete rewrite
- `AGENTS.md` — branding update
- `LICENSE` — copyright line
- `pyproject.toml` — project name/description
- `CHANGELOG.md` — merge REVISION_NOTES.md, update name
- `SECURITY.md` — repo name reference
- `CONTRIBUTING.md` — branding references
- `CODE_OF_CONDUCT.md` — name reference if present

Moves:
- `ARCHITECTURE_OVERVIEW.md` → `docs/architecture.md`
- `MODEL_RECOMMENDATIONS.md` → `docs/model-recommendations.md`
- `CONFIG_SUMMARY.md` → `docs/config-summary.md`
- `CLAUDE.md` → verify `templates/claude-code/CLAUDE.md` content, delete root
- `QWEN.md` → content folded into README, delete
- `REVISION_NOTES.md` → content merged into CHANGELOG.md, delete

Reference updates:
- All cross-references in docs/ pointing to moved files
- CI scripts referencing moved doc paths (`verify-documentation.sh`, `verify-v2-contract.sh`, etc.)
- `src/lac/` internal branding strings
