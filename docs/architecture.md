# Architecture Overview

## Positioning

This repo is a lac — Lightweight Agentic Coding, not only a coding-focused local setup.

The architecture is deliberately split into five layers:
- local runtime
- CLI orchestration
- client adapters
- curated workflow packs
- documentation and rollout guidance

## Local runtime

The runtime stays llama.cpp-first:
- `llama-server` is the default local API surface
- profile presets live under `runtime-config/presets/`
- `state/runtime/presets.active.ini` is generated from the chosen hardware profile
- Qwen 3.6 MoE is the target baseline model family for general work
- Qwen 3.6 MTP (27B Q4, 35B-A3B Q6) replaces coder-next as the fast coding and architect model

## CLI orchestration

Version 2 introduces a first-class CLI:
- `./bin/lac` on Unix-like systems
- `./bin/lac.ps1` on Windows

This CLI is the supported control plane for:
- profile selection and generated-state rendering
- runtime lifecycle operations
- client adapter rendering
- doctor and smoke reporting

## Client integrations

### OpenCode
- canonical repo config template: `opencode.template.jsonc`
- rendered config: `state/clients/opencode/opencode.json`
- runtime assets: `.opencode/agents/` and `.opencode/skills/`
- best path for local llama.cpp usage and structured agentic workflows

### Claude Code
- supported via `templates/claude-code/`
- rendered reference adapter: `state/clients/claude-code/`
- positioned as a lower-friction hosted-model path

### Codex
- rendered reference adapter: `state/clients/codex-reference/`
- treated as a pattern reference rather than a directly integrated runtime path

### OpenChamber
- web/PWA/desktop interface for OpenCode with mobile/remote access
- managed through: `lac client open openchamber` (or `--desktop` for macOS app)
- remote access via Tailscale or Cloudflare tunnel: `lac client open openchamber --remote-host http://<tailscale-ip>:4095`
- config root: `state/clients/openchamber/`

## Provider strategy

The default posture is **local always included, cloud as an optional overlay**. Every profile applies a local llama.cpp layer; cloud providers are separate, each gated by its own env var and inert until configured. `lac init` is the on-ramp.

Supported cloud overlays in `opencode.template.jsonc`:
- OpenRouter free tier
- OpenCode Go (flat subscription) and OpenCode Zen (pay-per-request)
- Codex via ChatGPT subscription (third-party OAuth helper)
- Anthropic API (API-key only; Claude.ai subscription does not apply)
- Antigravity, z.ai, NVIDIA NIM

There is no dedicated "hybrid profile" tier — hybridness comes from enabling overlays on top of any local profile.

## Workflow pack strategy

The repo deliberately avoids a large built-in persona catalog.

Instead it ships a curated asset catalog plus workflow packs:
- `coding`
- `research`
- `office`
- `team-rollout`

Pack metadata lives in `catalog/workflow-packs.json`, and individual asset trust/support metadata lives in `catalog/assets.json`.

## Release posture

The repo should remain private until the release gates in `docs/release/PRIVATE_UNTIL_RELEASE.md` are complete.
