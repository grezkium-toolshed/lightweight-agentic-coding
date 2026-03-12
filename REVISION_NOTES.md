# Revision Notes

## Current direction

The repo is moving from an OpenCode-centric local setup toward a broader Local AI Cluster for agentic work.

## Notable changes in this pass

- repositioned docs around Local AI Cluster use cases
- kept llama.cpp + Qwen 3.5 profile runtime unchanged
- added explicit OpenCode compaction, watcher, instruction, and permission config
- added NVIDIA NIM as a documented OpenCode provider option
- added curated OpenCode subagents under `.opencode/agents/`
- added curated OpenCode skills under `.opencode/skills/`
- added Claude Code templates instead of a duplicated runtime stack
- added security intake docs for third-party agents and skills
- added private-until-release guidance and release gates

## Intentional non-changes

- runtime scripts and hardware profile flow remain the same
- llama.cpp is still the default runtime
- OpenCode remains the strongest local client path
