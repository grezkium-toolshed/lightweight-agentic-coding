# Curated Agents

This repo ships curated agent definitions for OpenCode under `.opencode/agents/`.

Why both directories exist:
- `.opencode/agents/` is the runtime-discoverable location OpenCode loads automatically.
- `agents/` is the human-facing index for maintainers and contributors.

Current curated set:
- `architecture-reviewer`
- `release-reviewer`
- `reality-checker`
- `documentation-generator`
- `research-synthesizer`

These agents are intentionally narrow. The repo does not import large third-party persona catalogs by default.
