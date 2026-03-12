# Onboarding Scenario: Claude Code Hosted-Model Workflow

## Best fit
- teams that want lower setup friction
- users who prefer Anthropic-hosted models over local runtime management
- startup workflows where velocity matters more than local-only execution

## Recommended path
1. Read `templates/claude-code/README.md` and `templates/claude-code/CLAUDE.md`.
2. Keep this repo as the shared workflow and documentation baseline.
3. Reuse the curated agent and skill concepts, but keep Claude-specific instructions in `CLAUDE.md`.
4. Use the OpenCode + llama.cpp path only where local-first execution is a clear advantage.

## Important limitation
This repo does not duplicate the runtime stack for Claude Code. Claude Code is supported through documentation and templates, not a mirrored launcher system.
