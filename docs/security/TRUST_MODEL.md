# Trust Model for Curated Agents and Skills

This repo ships a small curated set of OpenCode agents and skills. It does not bulk import large external prompt catalogs.

## What is curated here
- project-local OpenCode subagents under `.opencode/agents/`
- project-local office and workflow skills under `.opencode/skills/`
- provider guidance written specifically for this repo
- optional workflow packs that must be installed explicitly, such as the Microsoft Graph skill pack

## What is only referenced externally
- larger third-party agent catalogs
- broader skill collections used as design references
- community-maintained free model indexes

## Optional Microsoft Graph pack

Microsoft Graph support is valuable for local agents with delegated or service-principal permissions, but it is not installed by default. The `microsoft-graph` pack is cataloged as reviewed external content and can be enabled with `./bin/lac skill install msgraph`.

The local cluster should treat Graph API execution as an authenticated network capability. Local endpoint search is low risk, but once credentials are configured the agent may be able to read or modify Microsoft 365 tenant data according to the granted permissions.

## Review standard
Anything imported or adapted from a third party should be:
- commit-pinned or source-linked
- reviewed for hidden instructions
- reviewed for unsafe shell, network, or secret-handling patterns
- trimmed to the smallest useful scope
