# Curated Agents

This repo ships curated agent definitions for OpenCode under `.opencode/agents/`.

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

Current curated set:
- `architecture-reviewer`
- `release-reviewer`
- `reality-checker`
- `documentation-generator`
- `research-synthesizer`

These agents are intentionally narrow. The repo does not import large third-party persona catalogs by default.
