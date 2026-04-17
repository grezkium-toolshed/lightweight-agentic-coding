# Config Summary

## Canonical runtime config

- `opencode.jsonc`: source template for OpenCode config in this repo
- `runtime-config/presets/<profile>.ini`: profile templates
- `runtime-config/profiles.json`: source-of-truth profile manifest
- `state/runtime/presets.active.ini`: generated active llama.cpp preset
- `state/active/profile.txt`: generated selected profile marker
- `state/clients/opencode/opencode.json`: generated OpenCode runtime config
- `state/logs/`: generated runtime logs
- `state/reports/`: generated doctor and smoke JSON reports

## OpenCode config choices

`opencode.jsonc` now includes:
- local llama.cpp provider config
- free cloud fallback providers
- explicit compaction settings
- watcher ignore rules for noisy paths
- instruction globs for stable repo guidance
- safer bash permissions
- built-in access to curated project-local agents and skills

## CLI contract

The supported v2 interface is:
- `./bin/lac profile list`
- `./bin/lac profile apply <profile>`
- `./bin/lac models sync <profile>`
- `./bin/lac runtime start|status|stop`
- `./bin/lac client render <target>`
- `./bin/lac doctor`
- `./bin/lac smoke`

The legacy `scripts/*.sh` and `scripts/*.ps1` commands remain as thin compatibility wrappers.

## OpenCode local discovery

OpenCode automatically discovers:
- `.opencode/agents/*.md`
- `.opencode/skills/*/SKILL.md`

This repo uses those directories as the runtime asset layer and tracks pack metadata separately in:
- `catalog/assets.json`
- `catalog/workflow-packs.json`

Maintainer index directories:
- `agents/`
- `skills/`

## Logging and monitoring

llama-server launch logs go to:
- `state/logs/llama-server.log`

Monitor with:
- Unix: `tail -f state/logs/llama-server.log`
- Windows: `Get-Content state/logs/llama-server.log -Wait -Tail 50`

## Release posture

This repo is still private by design. Public release should happen only after the release-gate checklist is complete.
