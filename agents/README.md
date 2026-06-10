# Curated Agents

> **Warning:** Do NOT add agents here. This directory is a human-facing index only. Add new agents to `.opencode/agents/` for runtime discovery.

This repo ships curated agent definitions for OpenCode under `.opencode/agents/`.
Asset metadata for workflow packs, trust level, and support tier lives in `catalog/assets.json`.

Why both directories exist:
- `.opencode/agents/` is the runtime-discoverable location OpenCode loads automatically.
- `agents/` is the human-facing index for maintainers and contributors.

Contract:
- Do not treat `agents/` as a runtime load path.
- Keep canonical runnable agent files in `.opencode/agents/`.

Naming overlap policy:
- Some names intentionally exist in both agents and skills (for example `documentation-generator` and `research-synthesizer`).
- Agent with that name defines orchestration behavior and delegation boundaries.
- Skill with that name defines execution workflow and guardrails for a specific capability.
- Use the agent when you need role-level routing; use the skill when you need repeatable task instructions.

## Agent Index

| Agent | Description | Mode | Edit |
|---|---|---|---|
| `architecture-reviewer` | Review architecture, boundaries, tradeoffs, and long-term maintainability | subagent | deny |
| `release-reviewer` | Check whether the repo is ready for an internal or public release | subagent | deny |
| `reality-checker` | Stress-test plans and claims for weak assumptions or operational gaps | subagent | deny |
| `devops-reviewer` | Review infrastructure-as-code, Dockerfiles, CI/CD pipelines, and deployment configs for correctness and security | subagent | deny |
| `documentation-generator` | Produce or refactor clear docs for setup, workflows, and onboarding | subagent | ask |
| `research-synthesizer` | Summarize external model, provider, or tooling options into practical recommendations | subagent | deny |

These agents are intentionally narrow. The repo does not import large third-party persona catalogs by default.
