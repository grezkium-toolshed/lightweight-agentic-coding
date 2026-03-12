# Trust Model for Curated Agents and Skills

This repo ships a small curated set of OpenCode agents and skills. It does not bulk import large external prompt catalogs.

## What is curated here
- project-local OpenCode subagents under `.opencode/agents/`
- project-local office and workflow skills under `.opencode/skills/`
- provider guidance written specifically for this repo

## What is only referenced externally
- larger third-party agent catalogs
- broader skill collections used as design references
- community-maintained free model indexes

## Review standard
Anything imported or adapted from a third party should be:
- commit-pinned or source-linked
- reviewed for hidden instructions
- reviewed for unsafe shell, network, or secret-handling patterns
- trimmed to the smallest useful scope
