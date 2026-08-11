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

The runtime stays llama.cpp-first, with explicit specialist runtimes:
- `llama-server` is the default local API surface
- `ds4-server` is the explicit 128 GB+ DeepSeek V4 Flash path for users who need DwarfStar instead of oMLX/MTP
- oMLX remains an optional macOS MLX serving path for compatible Qwen/Gemma profiles
- profile presets live under `runtime-config/presets/`
- `state/runtime/presets.active.ini` is generated from the chosen hardware profile
- Qwen 3.6 MoE is the target baseline model family for general work
- Qwen 3.6 MTP (27B Q4, 35B-A3B Q6) replaces coder-next as the fast coding and architect model

## CLI orchestration

The current release provides a first-class CLI:
- `./bin/lac` on Unix-like systems
- `./bin/lac.ps1` for the experimental native Windows path

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

The default posture is **local always included, cloud as an optional overlay**. Most local profiles apply a llama.cpp layer; specialist profiles can select another local runtime such as ds4. Cloud providers are separate, each gated by its own env var and inert until configured. `lac init` is the on-ramp.

Supported cloud overlays in `opencode.template.jsonc`:
- OpenRouter free tier
- OpenCode Go (flat subscription)
- NVIDIA NIM (free / trial)
- Anthropic API (API-key only; Claude.ai subscription does not apply)

OpenCode Zen remains available through OpenCode's built-in `/connect` flow rather than a duplicated
lac provider profile. Any hosted overlay changes the data boundary and is not local-only.

There is no dedicated "hybrid profile" tier — hybridness comes from enabling overlays on top of any local profile.

## Workflow pack strategy

The repo deliberately avoids a large built-in persona catalog.

Instead it ships a curated asset catalog plus workflow packs:
- `coding`
- `design`
- `devops`
- `research`
- `office`
- `team-rollout`
- `microsoft-graph`

Pack metadata lives in `catalog/workflow-packs.json`, and individual asset trust/support metadata lives in `catalog/assets.json`.

### Stack boundary

lac may analyze staged assessment artifacts and draft operator-reviewable output, but it is not a
Microsoft 365 administration or deployment system. In the wider evidence-to-proof stack it owns
the private, hardware-fit execution boundary only. Approval, tenant writes, rollback, independent
read-back, customer publication, and durable multi-customer history remain with the components
that own those responsibilities.

The candidate `contracts/delivery-run.v1.schema.json` is a content-addressed linking manifest. It
does not replace source schemas, contain tenant identifiers or local paths, or act as approval.
See `docs/STACK.md` for the public component map and the production-pilot evidence gate.

## Release posture

Public release is gated by `RELEASE_CHECKLIST.md`. The authoritative automated gates run locally
(`verify.sh`, `integration-test.sh`, and the clean wheel/sdist build). An optional manually triggered
GitHub workflow repeats Linux/macOS checks and an installed Windows wheel plus PowerShell smoke lane;
it is not a release gate and never runs automatically. These are configuration-compatibility checks,
not physical Windows/Linux support evidence. Apple Silicon MacBooks are the supported platform; the ds4 path
has measured M4 Max 128 GB evidence, while the 48 GB profile remains manual pending its exact
hardware contract. The `v0.3.0` tag and GitHub release were created from reviewed sanitized
commit `5989506` after the clean MacBook bootstrap, exact-head local checks, and dependency-alert
review passed. Documentation-only successors do not move that accepted tag. The repository was
made public after separate approval; visibility, Private Vulnerability Reporting, anonymous clones,
public links, and the tagged bootstrap path were read back successfully. Versioning follows SemVer.

Third-party integrations follow a strict posture: lac bundles only first-party agents and
workflow skills. External catalogs (Open Design) are opt-in fetch, and external OpenCode
plugins (Dynamic Context Pruning, ponytail) are referenced from npm in
`opencode.template.jsonc` rather than vendored. See `THIRD_PARTY_NOTICES.md`.
