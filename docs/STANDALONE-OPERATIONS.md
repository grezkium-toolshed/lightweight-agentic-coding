# Standalone operations

lac is a local-first assistant and model-runtime orchestrator. It does not need
M365 Threat Digest, Tenantsmith, Tracker, or a sibling checkout. Its local
architecture is the `lac` CLI, one selected model server (llama.cpp, oMLX, or
ds4), a generated OpenCode configuration, and an optional OpenChamber client.

## Prerequisites and limitations

The supported release platform is Apple Silicon macOS with Python 3.10+.
llama.cpp and OpenCode are required for the default local workflow;
OpenChamber is optional. Windows, Linux, Intel Macs, other GPUs, and profiles
without exact-hardware evidence are experimental. Local model quality and speed
depend on available memory. lac is not a hosted service and does not provide an
authenticated remote model listener.

## Install and first successful workflow

```bash
git clone https://github.com/grezkium-toolshed/lightweight-agentic-coding.git
cd lightweight-agentic-coding
./scripts/bootstrap.sh
lac doctor --json
lac runtime status --json
```

Until `v0.3.0` and its assets exist, install only from a reviewed checkout. A
successful standalone workflow starts the runtime, renders the effective local
provider URL, and opens OpenCode or OpenChamber without either sibling present.

## Start, stop, status, health, and logs

```bash
lac runtime start
lac runtime status --json
lac ports show --json
lac provider verify local-cluster --json
lac client open opencode
lac runtime stop
```

Runtime logs are under the effective state root's `logs/` directory. Installed
macOS copies default to `~/Library/Application Support/lac/state`; Linux uses
`$XDG_STATE_HOME/lac` or `~/.local/state/lac`; Windows uses
`%LOCALAPPDATA%\lac\state`. `LAC_STATE_ROOT` selects a deliberate alternative.

## Ports and exposure

Runtime defaults are 8080 for llama.cpp and 8000 for oMLX/ds4. OpenChamber
defaults to 3000 and its managed OpenCode server to 4095. Defaults and persisted
automatic ports probe only through `+20`; an explicit occupied port fails with
the endpoint, a best-effort listener PID, and an override command. Inspect the
effective URLs with `lac ports show --json`; reset only port state with
`lac ports reset`.

Native services stay on loopback. Bind and connect hosts are distinct in the
network record, but non-loopback runtime binding is rejected because this
release has no remote authentication boundary. Use an authenticated tunnel if
remote access is required. Never expose a local model or client port merely
because the default was occupied.

## Data, backup, retention, and removal

Installed models and refreshed catalog data use the platform user-data root
(`~/Library/Application Support/lac` on macOS,
`$XDG_DATA_HOME/lac`/`~/.local/share/lac` on Linux, and
`%LOCALAPPDATA%\lac` on Windows). `AI_MODELS_DIR` and `LAC_DATA_ROOT` can select
explicit locations. State contains generated client configuration, reports,
PIDs, logs, and `network.v1.json`; it must not contain provider secrets.

Back up only models or generated configuration you intentionally want to keep.
Logs and diagnostic reports have no automatic retention policy in v0.3, so
review and remove them according to your own local-data policy.

- Update: fetch a reviewed release, reinstall the wheel or rerun the idempotent
  bootstrap, then run `lac doctor`, `lac runtime start`, and provider checks.
- Roll back: stop the runtime, reinstall the previously retained tag/wheel, and
  reapply its profile. Back up state first if the older version may not read a
  newer generated configuration.
- Uninstall: stop the runtime, uninstall the Python package, and remove optional
  OpenCode/OpenChamber components separately. User data and state are preserved.
- Purge: lac has no implicit purge. After backing up what you need, explicitly
  confirm the exact resolved `LAC_DATA_ROOT`, `LAC_STATE_ROOT`, and
  `AI_MODELS_DIR` paths before removing them with platform file-management
  tools. Never delete an unresolved environment variable or a broad home/root
  directory.

## Authentication, permissions, and privacy

The local runtime needs no account. Optional cloud providers read credentials
from documented environment variables; lac reports only whether a variable is
configured and does not write the value to logs or JSON. Optional Microsoft
Graph skills have their own permission and authentication guidance and are not
installed or authorized by standalone startup. Model weights and optional
clients retain their upstream licenses and trust boundaries.

Local operation does not itself guarantee that workspace data stays local if
you enable a cloud provider. Treat provider selection, workspace contents, and
client tools as one privacy decision.

## Optional Toolshed integration and failure behavior

Threat Digest may use lac's effective loopback AI endpoint. This is opt-in: lac
does not install, start, or require Digest, and it has no Tenantsmith runtime
dependency. If either sibling is absent, unavailable, or incompatible, lac's
runtime, client, model, and profile workflows continue unchanged.

For troubleshooting, run `lac doctor --json`, `lac runtime status --json`, and
`lac ports show --json`, then consult the root README and `SUPPORT.md`. Security
reports follow `SECURITY.md`. Community support is best effort with no SLA.
