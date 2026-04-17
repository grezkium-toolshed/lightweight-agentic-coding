# Revision Notes

## Current direction

The repo is moving from an OpenCode-centric local setup toward a broader Local AI Cluster for agentic work.

## Notable changes in this pass

- repositioned docs around Local AI Cluster use cases
- introduced a first-class `lac` CLI under `bin/`
- moved generated runtime state into `state/`
- expanded the profile manifest into a richer product contract
- added workflow-pack, asset, provider, and scenario catalogs under `catalog/`
- added client adapters for OpenCode, Claude Code, and Codex reference views
- added JSON doctor and smoke reports for local observability
- set repo direction toward Qwen 3.6 MoE as the default local baseline
- clarified Gemma 4 as the multilingual and EU-language-friendly alternative
- added explicit OpenCode compaction, watcher, instruction, and permission config
- added NVIDIA NIM as a documented OpenCode provider option
- added curated OpenCode subagents under `.opencode/agents/`
- added curated OpenCode skills under `.opencode/skills/`
- added Claude Code templates instead of a duplicated runtime stack
- added security intake docs for third-party agents and skills
- added private-until-release guidance and release gates

## Intentional non-changes

- llama.cpp is still the default runtime
- OpenCode remains the strongest local client path
- setup-models download flow still reuses the existing platform-native scripts behind the CLI
