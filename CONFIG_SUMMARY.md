# Config Summary

## Canonical runtime config

- `opencode.jsonc`: source template for OpenCode config in this repo
- `runtime-config/presets/<profile>.ini`: profile templates
- `runtime-config/presets.active.ini`: generated active llama.cpp preset
- `runtime-config/active-profile.txt`: generated selected profile marker
- `runtime-config/opencode.active.json`: generated OpenCode runtime config
- `runtime-config/logs/`: generated runtime logs

## OpenCode config choices

`opencode.jsonc` now includes:
- local llama.cpp provider config
- free cloud fallback providers
- explicit compaction settings
- watcher ignore rules for noisy paths
- instruction globs for stable repo guidance
- safer bash permissions
- built-in access to curated project-local agents and skills

## OpenCode local discovery

OpenCode automatically discovers:
- `.opencode/agents/*.md`
- `.opencode/skills/*/SKILL.md`

This repo uses those directories as the canonical runtime asset layer.

Maintainer index directories:
- `agents/`
- `skills/`

## Logging and monitoring

llama-server launch logs go to:
- `runtime-config/logs/llama-server.log`

Monitor with:
- Unix: `tail -f runtime-config/logs/llama-server.log`
- Windows: `Get-Content runtime-config/logs/llama-server.log -Wait -Tail 50`

## Release posture

This repo is still private by design. Public release should happen only after the release-gate checklist is complete.
