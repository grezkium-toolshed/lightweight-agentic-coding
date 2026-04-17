# Claude Code Project Guidance

This repository is a Local AI Cluster:
- local-first runtime is llama.cpp
- OpenCode is the best-supported local client path
- Claude Code is supported here through docs, templates, and reusable workflow patterns

## Preferred usage model
- Use local Qwen 3.6 profiles for cost-sensitive and privacy-sensitive work.
- Use Anthropic-hosted models when lower operational friction matters more than local execution.
- Keep agents specialized and short. Prefer a small curated set over broad persona catalogs.

## Repository expectations
- Validate commands against the actual scripts in `scripts/`.
- Do not assume public-release readiness; the repo is intentionally private until release gates are met.
- When proposing agents or skills, optimize for reproducibility and maintenance cost.

## Good uses for this setup
- coding and refactoring
- documentation generation
- spreadsheet, deck, and report automation
- startup planning and review workflows
