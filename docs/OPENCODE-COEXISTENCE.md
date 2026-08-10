# OpenCode coexistence and privacy checks

lac generates its own OpenCode configuration, but OpenCode merges configuration
from multiple locations rather than replacing the user's existing setup. The
upstream [configuration precedence](https://opencode.ai/docs/config/) includes
global configuration, `OPENCODE_CONFIG`, project configuration, and configuration
directories. Later settings may override lac defaults, while arrays such as
plugins may be combined.

lac never edits, renames, migrates, or deletes an existing global or project
OpenCode configuration. It sets these safe defaults in the generated config:

- conversation sharing disabled;
- automatic OpenCode updates disabled for the validated launch;
- confirmation required before workspace edits.

The launch environment also disables OpenCode auto-update. Project instructions
and skills remain discoverable because lac does not disable project config.

## Check the effective session

Run:

```bash
lac doctor --json
```

Review `opencode_coexistence`. `checked: true` means lac successfully asked the
installed OpenCode to resolve its merged configuration. It does not mean every
inherited setting is safe. The report lists detected config paths but never
stores the raw merged config, credentials, or environment values.

Warnings are advisory and do not prevent `lac client open` from continuing:

| Warning | Meaning |
|---|---|
| `effective-config-unavailable` | lac could not resolve the merged OpenCode config. Do not assume local-only behavior until reviewed manually. |
| `existing-config-merged` | Existing global or project settings are participating in the session. |
| `sharing-enabled` | The effective sharing mode is not disabled. |
| `nonlocal-default-model` | A local profile resolved to a different provider. |
| `local-provider-unavailable` | `enabled_providers` excludes the profile's local provider. |
| `extra-plugin` | An inherited plugin can observe or transform the session. |
| `enabled-mcp` | An inherited MCP integration can call another process or service. |
| `autoupdate-enabled` | A later setting re-enabled client updates. |
| `edit-without-approval` | A later setting allows workspace edits without confirmation. |

To inspect the same upstream result directly:

```bash
opencode debug config --pure
```

That output may contain details from the user's configuration. Review it locally;
do not attach it to a public issue without sanitizing it.

## Existing authentication, sessions, and desktop processes

lac does not isolate OpenCode's data directory. Existing authentication and
session/cache state remain available to OpenCode. Merely having cloud credentials
does not send a prompt away, but selecting a hosted model, sharing a conversation,
or invoking a remote plugin/MCP ends lac's local-only boundary.

OpenCode or OpenChamber Desktop processes that were already running may retain
their earlier environment. Fully quit the application before relaunching it with
`lac client open`. `lac runtime stop` stops only the selected model server; close
OpenCode and OpenChamber separately.

## Safe workspace practice

The generated default asks before editing files, and shell commands ask except
for a small read-only allowlist. Existing project configuration can override
those permissions. Use Git or a disposable copy, read every confirmation, and
review the resulting diff before accepting work.

The local-only statement is valid only when a local model is active and the
effective configuration has no unresolved egress warning. Installation, model
downloads, and first DCP/Ponytail use still require network access.
