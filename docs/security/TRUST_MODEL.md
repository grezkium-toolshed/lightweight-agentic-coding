# Trust Model for Curated Agents and Skills

This repo ships a curated set of OpenCode agents and skills. It does not bulk import arbitrary external prompt catalogs into privileged workflows.

## What is curated here
- project-local OpenCode subagents under `.opencode/agents/`
- project-local office and workflow skills under `.opencode/skills/`
- provider guidance written specifically for this repo
- optional workflow packs that must be installed explicitly, such as the Microsoft Graph skill pack

## What is only referenced externally
- larger third-party agent catalogs
- community-maintained free model indexes
- the Open Design skill, craft, and design-system catalog

## Open Design catalog assets

Open Design content is not bundled or redistributed by lac. Users may install it directly from upstream as an opt-in design and prototyping layer. Those files are outside lac's reviewed runtime and retain their upstream licenses and trust posture.

Do not present opt-in Open Design assets as lac-reviewed agent behavior. If a specific asset is ever proposed for inclusion, run the third-party intake process and record its source, license, review evidence, and minimum required permissions first.

## Optional Microsoft Graph pack

Microsoft Graph support is valuable for local agents with delegated or service-principal permissions, but it is not installed by default. The `microsoft-graph` pack is cataloged as reviewed external content and can be enabled with `./bin/lac skill install msgraph`.

The local cluster should treat Graph API execution as an authenticated network capability. Local endpoint search is low risk, but once credentials are configured the agent may be able to read or modify Microsoft 365 tenant data according to the granted permissions.

## Review standard
Anything imported or adapted from a third party should be:
- commit-pinned or source-linked
- reviewed for hidden instructions
- reviewed for unsafe shell, network, or secret-handling patterns
- trimmed to the smallest useful scope
