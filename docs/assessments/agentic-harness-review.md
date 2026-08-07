# Agentic Harness Review — Local Analysis Tasks

Status: research brief (decision-ready)

## Decision question

Should assessment-analysis work run on OpenCode (the repo's default harness), or does
another agentic harness fit the task better — small and large local models, file
read/write over json/md/csv exports, operator-friendly?

## Evaluation criteria

1. **Local-server compatibility** — works against llama.cpp `llama-server` OpenAI-compatible
   endpoint (the repo's runtime) without cloud requirements.
2. **Tool-call reliability on small models** — tolerance for imperfect function-calling
   output from 9-12B quantized models.
3. **File-tool quality** — read/write/edit/grep/glob on local files, diff-aware edits.
4. **Agentic loop maturity** — multi-turn tool loops, session management, context
   compaction.
5. **End-user friction** — setup steps, CLI vs UI, onboarding for non-developer operators.
6. **License / corporate posture** — permissive license, no vendor lock-in.

## Candidates

| Harness | Local llama.cpp | Small-model tool calling | File tools | Loop maturity | Friction | License |
|---|---|---|---|---|---|---|
| **OpenCode** (current) | Native — this repo's runtime | Good; permissive `permission` rules, retry-friendly | Full (read/write/edit/grep/glob/bash) | High; context compaction, sessions, subagents | Low for CLI users; TUI | MIT (OpenCode Go subscription optional) |
| **OpenChamber** | Yes (bundled client in this repo) | Same model-level reliability; thin agent layer | Basic file browsing/editing in web UI | Low-mid; chat-oriented | Lowest (browser UI, remote access) | Open source |
| **Aider** | Yes (Ollama/llama.cpp) | Good — reparsing of model diffs is its specialty | Git-based edits, whole-file rewrite | Mid; single-diff loop, no subagents | Low-mid; CLI | Apache-2.0 |
| **Claude Code** | Yes — point it at the local server via a base-URL override (Unsloth publishes setup guides for running it against `llama-server`) | Inherits OpenCode-style reliability | Full | High | Mid; needs env config per run | Proprietary, subprocess license terms |
| **OpenAI Codex CLI** | Yes — local base-URL override per Unsloth's guide | Inherits | Full | High | Mid; login prompts for non-local fallbacks | Proprietary |

## Verdict

**Stay on OpenCode.** No failure mode was found that justifies switching for this task:

- OpenCode is the harness this repo is built around: profiles, presets, permissions,
  skills, and verified smoke tests all target it (`docs/architecture.md`, `AGENTS.md`).
- File analysis workloads are exactly OpenCode's core competency (read/write/grep/glob +
  bash for pandas), and its per-workspace `permission` rules implement the
  privacy-locked configuration the model review requires (`webfetch: deny`,
  workspace-scoped `edit`/`bash`).
- The models under review (Qwen 3.6/3.5, Gemma 4) have documented local tool-calling
  support; OpenCode does not add a reliability tax on top — tool-call failures are
  surfaced and retryable in the loop.

When an alternative would win:

- **OpenChamber** — when operators need a browser UI (e.g. meeting-room screenshots or
  remote access via Tailscale) instead of a terminal. It runs against the same
  `llama-server`, so it is complementary, not a replacement.
- **Aider** — when the task becomes strict whole-file code editing in git repos and
  diff-quality matters more than multi-tool loops; not a fit for data analysis.
- **Claude Code / Codex CLI** — only if the team standardizes on one of them for other
  work; both carry proprietary license terms that the local-first posture deliberately
  avoids.

## Assumptions

- The analysis workspace is a plain folder of json/md/csv + manifest — no IDE, no git
  workflow, no browser automation.
- Operators are comfortable starting one CLI command (`./bin/lac runtime start` +
  `opencode`) or, if they are not, OpenChamber covers the UI path.

## Open risks

- No comparative benchmark (same prompt, same model, both harnesses) has been run;
  the verdict rests on feature fit and repo integration rather than measured output
  quality differences.
- OpenCode TUI is not a web UI; if operators refuse terminals, OpenChamber becomes the
  default front-end while OpenCode remains the batch-capable engine.
