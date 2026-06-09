# Hybrid Workspaces

Hybrid workspaces are setups where one person or team can use both local models and hosted models from the same OpenCode configuration across multiple project roots, machines, or trust zones.

This repo supports two useful hybrid shapes:

1. **Local plus hosted overlays**: keep llama.cpp and local Qwen/Gemma profiles as the baseline, then add OpenCode Go and OpenRouter together. Go gives predictable subscription capacity; OpenRouter gives free/trial fallback and broad hosted-model experiments.
2. **Multiple workspace roots**: keep this repo as the shared control-plane template, then render or copy its OpenCode config, agents, skills, and docs into separate project workspaces as needed.

## Recommended Patterns

### Personal Multi-Repo Setup

Use this when you have several private repos on the same workstation and want the same client to offer both local and cloud models.

- Keep `lightweight-agentic-coding` as the canonical setup repo.
- Apply one local profile globally, usually `24gb`, `32gb`, or `64gb`.
- Use `opencode-go` and `openrouter` together when you want reliable hosted coding models plus a free/trial fallback.
- Keep project-specific rules in each project repo, not in the cluster repo.
- Reuse `.opencode/agents` and `.opencode/skills` from this repo only when the workflow applies broadly.

Useful commands:

```bash
./bin/lac init --yes --profile 32gb --cloud opencode-go,openrouter
./bin/lac models sync 32gb
./bin/lac client render opencode
./bin/lac provider verify opencode-go
./bin/lac provider verify openrouter
```

### Team Pilot Setup

Use this when a small team wants the same workflow vocabulary without identical hardware.

- Standardize on workflow packs: `coding`, `research`, `office`, and `team-rollout`.
- Let each developer pick a hardware profile based on their machine.
- Prefer `opencode-go` for predictable shared hosted capacity and `openrouter` for free/trial fallback.
- Keep local profiles enabled for private, repeated, or data-sensitive work.
- Document which tasks may use hosted providers before the rollout.

Suggested defaults:

| Machine class | Local profile | Hosted overlay |
|---|---|---|
| MacBook Air-class 16 GB | `macos-16gb` | `opencode-go`, `openrouter` |
| 16-24 GB | `24gb` or `16gb` | `opencode-go`, `openrouter` |
| 32 GB | `32gb` | `opencode-go`, `openrouter` |
| 64 GB+ | `64gb` | `opencode-go`, `openrouter`, optional `anthropic` |
| No local runtime | `opencode-go` | none required |

### Trust-Zone Split

Use this when some work can leave the machine and some cannot.

- Local-only: secrets, customer data, unreleased strategy, private incident analysis.
- Hosted okay: public docs, dependency research, scaffolding, non-sensitive refactors, test generation from sanitized context.
- Mixed: design review, architecture planning, and release notes after removing sensitive details.

Do not rely on model choice alone as a data boundary. The practical boundary is the workspace context and what files or prompts are sent to the provider.

## Profile Choices

Use cloud-only profiles when local runtime management is not the goal:

```bash
./bin/lac profile apply opencode-go
./bin/lac client open opencode
```

Use overlays when local execution remains the baseline:

```bash
./bin/lac init --yes --profile 32gb --cloud opencode-go,openrouter
./bin/lac models sync 32gb
./bin/lac runtime start
./bin/lac client open opencode
```

In OpenCode, use `/models` to switch between local IDs such as `local-cluster/qwen3.6-27b-q4`, subscription IDs such as `opencode-go/qwen3.6-plus`, and OpenRouter IDs such as `openrouter/qwen/qwen3-coder:480b-free`.

For OpenCode Desktop on macOS, use the same generated config:

```bash
./bin/lac client open opencode --desktop
```

This supports hybrid profiles and cloud-only profiles such as `opencode-go`. If the desktop app is already running, quit and relaunch it after switching profiles.

## What To Keep Per Workspace

Keep these local to each project workspace:

- project-specific rules
- repo-specific agents
- sensitive allow/deny guidance
- generated state and logs
- credentials or auth stores

Keep these in the cluster repo:

- shared profile definitions
- shared provider catalog
- general-purpose agents and skills
- setup scripts and validation checks
- onboarding docs

## Operational Checks

Before using a hybrid workspace:

```bash
./bin/lac doctor
./bin/lac provider status
./bin/lac provider verify opencode-go
./bin/lac client render opencode
```

For local profiles, also verify the runtime:

```bash
./bin/lac runtime start
./bin/lac smoke
```

When diagnosing model-load or runtime startup issues, run the server in the foreground:

```bash
./bin/lac runtime start --foreground
```

This keeps runtime logs in the terminal instead of only writing them to `state/logs/`. llama.cpp remains the default local runtime. On macOS, `AI_LOCAL_RUNTIME=omlx` selects the oMLX OpenAI-compatible serving path when the active profile has compatible MLX mappings; `AI_LOCAL_RUNTIME=mlx` is accepted as an alias for oMLX. If a profile includes a model without a supported MLX mapping, the CLI falls back to llama.cpp.

## Open Questions

The repo does not yet manage multiple workspace configs from one command. If that becomes a priority, the likely next feature is a `workspace` command group that can register project roots and render client adapters into each one.
