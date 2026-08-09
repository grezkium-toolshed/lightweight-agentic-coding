# Config Summary

## Canonical runtime config

- `opencode.template.jsonc`: source template for OpenCode config in this repo
- `runtime-config/presets/<profile>.ini`: profile templates
- `runtime-config/profiles.json`: source-of-truth profile manifest
- `state/runtime/presets.active.ini`: generated active llama.cpp preset
- `state/active/profile.txt`: generated selected profile marker
- `state/clients/opencode/opencode.json`: generated OpenCode runtime config
- `state/logs/`: generated runtime logs
- `state/reports/`: generated doctor and smoke JSON reports
- `state/network.v1.json`: persisted local port selections (in an installed copy,
  the platform user-state directory rather than the package tree)

## OpenCode config choices

`opencode.template.jsonc` now includes:
- local llama.cpp provider config
- free cloud fallback providers
- explicit compaction settings
- watcher ignore rules for noisy paths
- instruction globs for stable repo guidance
- safer bash permissions
- built-in access to curated project-local agents and skills

## CLI contract

The supported current CLI contract is:
- `./bin/lac init` (interactive onboarding; `--yes --profile <id> [--cloud <ids>] [--no-cloud]` for non-interactive)
- `./bin/lac profile list`
- `./bin/lac profile apply <profile>`
- `./bin/lac models sync [profile]`
- `./bin/lac runtime start|status|stop`
- `./bin/lac client render <target>`
- `./bin/lac pack list|show <pack>`
- `./bin/lac scenario list|show <scenario>`
- `./bin/lac provider list|status`
- `./bin/lac provider verify <id> [--timeout N] [--refresh-catalog]` (or `--all` to sweep every catalog provider; hits each provider's baseURL and reports `ok` / `skipped` / `error`, plus the local health endpoint)
- `./bin/lac doctor`
- `./bin/lac smoke`

`lac init` is the primary onboarding surface. Its text output groups hardware detection, selected profile, cloud overlays, generated files, readiness, required checks, optional checks, and next steps. Its JSON output includes the same decision data for automation: `status`, `recommendation`, `prerequisites`, `readiness`, `generated`, and `next_steps`. The `hardware` object preserves `ram_gb` and `vram_gb` and adds `memory_kind`, `effective_budget_gb`, `probe_source`, `gpu_vendor`, `gpu_device`, `confidence`, `runtime_acceleration`, and normalized `accelerators`.

The global `--json` flag is supported repo-wide for machine-readable output. Without it, `init`, `doctor`, and `smoke` print compact human-readable summaries; the JSON written to `state/reports/*.json` for doctor and smoke is identical either way.

`lac ports show --json` reports the effective `lac.network.v1` endpoints and
their precedence source: CLI, environment, optional `LAC_NETWORK_CONFIG`,
persisted user state, then defaults. `lac ports reset` removes only the
persisted state record. Only records marked as automatic participate in the
next no-override resolution; other successful allocations remain visible under
`last_successful_allocations` in `lac ports show --json`. Local services bind and connect over loopback by
default; runtime remote binding is intentionally unsupported until lac has an
authenticated remote-listener contract.

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

Runtime launch logs go to:
- `state/logs/llama-server.log`
- `state/logs/omlx.log`
- `state/logs/ds4.log`

Monitor with:
- Unix: `tail -f state/logs/llama-server.log`
- Windows: `Get-Content state/logs/llama-server.log -Wait -Tail 50`

The ds4/DwarfStar runtime also uses `state/runtime/ds4.pid`, `state/runtime/ds4.json`, and `state/runtime/ds4-kv/` for local process state and disk KV cache.

## Release posture
