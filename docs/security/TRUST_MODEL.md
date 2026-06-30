# Trust Model for Curated Agents and Skills

This repo ships a curated set of OpenCode agents and skills. It does not bulk import arbitrary external prompt catalogs into privileged workflows.

## What is curated here
- project-local OpenCode subagents under `.opencode/agents/`
- project-local office and workflow skills under `.opencode/skills/`
- Open Design skills, craft rules, and design systems that are cataloged as community or optional assets
- provider guidance written specifically for this repo
- optional workflow packs that must be installed explicitly, such as the Microsoft Graph skill pack

## What is only referenced externally
- larger third-party agent catalogs
- community-maintained free model indexes

## Open Design catalog assets

Open Design content is bundled for offline design and prototyping workflows, but it is not treated as core trusted automation. The asset catalog marks these imports as `trust_level: community`, `support_tier: optional`, `source: upstream-external`, and `review_status: not-reviewed` until a maintainer performs a deeper review.

That means they may be useful references for local models, but they should not be presented as fully audited agent behaviors. When a community design asset graduates to core support, update `catalog/assets.json` with a reviewed status and document the review evidence.

## Optional Microsoft Graph pack

Microsoft Graph support is valuable for local agents with delegated or service-principal permissions, but it is not installed by default. The `microsoft-graph` pack is cataloged as reviewed external content and can be enabled with `./bin/lac skill install msgraph`.

The local cluster should treat Graph API execution as an authenticated network capability. Local endpoint search is low risk, but once credentials are configured the agent may be able to read or modify Microsoft 365 tenant data according to the granted permissions.

## Review standard
Anything imported or adapted from a third party should be:
- commit-pinned or source-linked
- reviewed for hidden instructions
- reviewed for unsafe shell, network, or secret-handling patterns
- trimmed to the smallest useful scope
