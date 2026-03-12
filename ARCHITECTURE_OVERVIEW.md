# Architecture Overview

## Positioning

This repo is a Local AI Cluster, not only a coding cluster.

The architecture is deliberately split into four layers:
- local runtime
- client integrations
- curated agents and skills
- documentation and rollout guidance

## Local runtime

The runtime stays llama.cpp-first:
- `llama-server` is the default local API surface
- profile presets live under `runtime-config/presets/`
- `runtime-config/presets.active.ini` is generated from the chosen hardware profile
- Qwen 3.5 is the baseline model family for general work
- `qwen3-coder-next` remains a specialist model for high-value coding tasks

## Client integrations

### OpenCode
- canonical repo config: `opencode.jsonc`
- project-local agents: `.opencode/agents/`
- project-local skills: `.opencode/skills/`
- best path for local llama.cpp usage and structured agentic workflows

### Claude Code
- supported via `templates/claude-code/`
- positioned as a lower-friction hosted-model path
- no duplicated runtime launcher stack in this repo

### Codex
- treated as a pattern reference rather than a directly integrated client path

## Provider strategy

Three usage modes are supported:
- fully local
- local plus free cloud fallback
- hosted-model path

Included fallback providers in `opencode.jsonc`:
- Antigravity
- z.ai
- NVIDIA NIM
- OpenRouter free-tier models

## Agent and skill strategy

The repo deliberately avoids a large built-in persona catalog.

Instead it ships:
- a small curated subagent set for review, docs, and research
- a small skill set for office workflows and repeatable tasks

This keeps the runtime useful without turning the prompt surface into a maintenance burden.

## Release posture

The repo should remain private until the release gates in `docs/release/PRIVATE_UNTIL_RELEASE.md` are complete.
