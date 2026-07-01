# Scenario Guide

Version 2 starts from jobs-to-be-done first, then maps you to a profile, provider mode, and workflow pack.

## Solo Coder

- Recommended profiles: `24gb`, `32gb`, `openrouter`
- Recommended packs: `coding`
- Best client target: OpenCode

## Research Operator

- Recommended profiles: `24gb`, `gemma-24gb`, `openrouter`
- Recommended packs: `research`, `office`
- Best client target: OpenCode

## Office Automation

- Recommended profiles: `16gb`, `24gb`, `openrouter`
- Recommended packs: `office`
- Best client target: OpenCode

## Team Pilot

- Recommended profiles: `32gb`, `64gb`, `openrouter`
- Recommended packs: `coding`, `research`, `office`, `team-rollout`
- Best client target: OpenCode
- Hybrid and multi-workspace guidance: `docs/use-cases/HYBRID_WORKSPACES.md`

## Workflow Packs

The canonical machine-readable scenario mapping lives in `catalog/scenarios.json`.
Workflow pack definitions, assets, supported clients, and trust metadata live in `catalog/workflow-packs.json`.

| Pack | Label | Use |
|---|---|---|
| `coding` | Coding Pack | Architecture review, structured execution, and coding workflows. |
| `research` | Research Pack | Evidence-backed research synthesis and investigation workflows. |
| `office` | Office Pack | Document, presentation, spreadsheet, and PDF workflows. |
| `team-rollout` | Team Rollout Pack | Release and reality-check support for team adoption. |
| `design` | Design Pack | Optional Open Design skills, brand systems, and prototyping workflows. |
| `devops` | DevOps Pack | Infrastructure, Dockerfile, and CI/CD review workflows. |
| `microsoft-graph` | Microsoft Graph Pack | Optional Microsoft Graph skill workflows for authorized API use. |
