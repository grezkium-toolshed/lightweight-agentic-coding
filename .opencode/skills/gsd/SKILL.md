---
name: gsd
description: Structured Discuss → Plan → Execute → Verify → Ship workflow to prevent context rot in multi-session work
license: MIT
compatibility: opencode
metadata:
  audience: maintainers
  workflow: planning
---
## What I do
- Structure work into a repeatable pipeline: Discuss → Plan → Execute → Verify → Ship
- Keep context focused using lightweight state files to avoid token bloat across sessions
- Break work into atomic tasks with dependency-aware ordering
- Enforce plan-check gates before execution and verification gates before merging

## When to use me
Use this for multi-session feature work, release prep, or any task where context drift across sessions would degrade output quality. Skip for single-command fixes or one-shot edits.

## Workflow

### 1. Discuss
- Clarify scope, constraints, and success criteria
- Surface hidden assumptions or prerequisites
- Write a short scope summary to `.planning/STATE.md`

### 2. Plan
- Break scope into atomic tasks with dependencies
- Write task list to `.planning/ROADMAP.md`
- Run a plan-check pass: validate feasibility, identify risks, flag anything that overpromises

### 3. Execute
- Work tasks in dependency order, one wave at a time
- Keep context focused on the current wave — do not carry forward completed task details
- Commit each atomic task immediately upon completion

### 4. Verify
- Validate deliverables against the original scope
- Check for regressions, scope creep, or broken assumptions
- Update `.planning/STATE.md` with verification results

### 5. Ship
- Summarize what was done, what was deferred, and any follow-up items
- Clean up `.planning/` scratch files if the task is complete, or keep them for the next session

## State Files

Store all GSD state under `.planning/` (repo-local, not global):
- `.planning/STATE.md` — current phase, scope summary, open questions
- `.planning/ROADMAP.md` — atomic task list with dependency notes
- `.planning/config.json` — optional workflow settings (granularity, mode)

These should be gitignored if they contain sensitive or transient data.

## Guardrails
- Do not skip the plan-check gate before execution — it catches weak assumptions cheaply
- Do not carry completed task details into the next wave — start fresh to avoid context bloat
- If scope changes mid-execution, update STATE.md before continuing
- The `.planning/` directory is repo-local — do not install GSD as a global tool

## Notes
- Inspired by https://github.com/gsd-build/get-shit-done — adapted for repo-local OpenCode use without global config pollution
- Granularity setting: use `coarse` for docs/config updates, `standard` for feature work, `fine` for complex refactoring
