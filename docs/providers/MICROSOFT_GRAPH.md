# Microsoft Graph Skill Pack

Microsoft Graph support is optional. Install it only on workstations where agents should help with Microsoft 365, Entra ID, Intune, Teams, SharePoint, Exchange, Planner, To Do, or Security Graph workflows.

The upstream skill comes from Graph.pm / `merill/msgraph`. It bundles local indexes for endpoint search and can also execute Graph API calls after authentication.

## Install

```bash
./bin/lac skill status msgraph
./bin/lac skill install msgraph
./bin/lac skill verify msgraph
```

The default installer downloads the pinned upstream `v1.0.19` release zip, verifies its
SHA-256 (`363926d4d3f49a7f19cb6f50589e6646267e89a4f72764b5fc043db36a5a6764`), and expands it
into `.opencode/skills/msgraph/`. That directory is ignored by git so local installs do not
dirty the repo. A local `--source` install is available when you have reviewed an archive or
directory yourself.

For offline or reviewed installs, provide a local extracted folder or zip:

```bash
./bin/lac skill install msgraph --source /path/to/msgraph
./bin/lac skill install msgraph --source /path/to/msgraph.zip
```

Remove it with:

```bash
./bin/lac skill remove msgraph
```

## Authentication

The skill supports delegated user auth and app-only auth. Credentials must stay outside the repo.

Delegated workstation flow:

```bash
.opencode/skills/msgraph/scripts/run.sh auth signin
.opencode/skills/msgraph/scripts/run.sh auth status
```

Headless/device-code flow:

```bash
.opencode/skills/msgraph/scripts/run.sh auth signin --device-code
```

App-only service principal flow:

```bash
export MSGRAPH_CLIENT_ID="00000000-0000-0000-0000-000000000000"
export MSGRAPH_TENANT_ID="contoso.onmicrosoft.com"
export MSGRAPH_CLIENT_SECRET="..."
.opencode/skills/msgraph/scripts/run.sh auth signin
```

Certificate, managed identity, and workload identity federation are also supported by the upstream skill. Use those instead of client secrets for unattended team or CI-style environments when possible.

## Least Privilege

Create a dedicated Entra app registration for agent automation. Grant only the Graph application permissions needed for the intended workflow, then grant admin consent explicitly.

Recommended starting posture:
- prefer read-only permissions first, such as `User.Read.All`, `Group.Read.All`, or product-specific `.Read.All` scopes
- use separate app registrations for Intune, identity, mail, and security operations if the permission sets differ
- avoid broad write permissions until a workflow has been reviewed
- never commit `MSGRAPH_CLIENT_SECRET`, certificates, token caches, or exported environment files

## Agent Usage

Good read-only prompts:
- "Find the current Graph endpoint and permissions for conditional access policies."
- "List the properties and filter operators for the Intune `managedDevice` resource."
- "Show the Graph query for unread messages, limited to subject, sender, and received time."

Write operations require explicit confirmation and the upstream `--allow-writes` flag. DELETE is blocked by the upstream skill.

## Notes

OpenCode discovers project skills from `.opencode/skills/`. The cluster keeps `msgraph` opt-in because installing the skill adds a broad API knowledge and execution surface. Local index search is offline, but authenticated Graph calls use Microsoft Graph over the network.
