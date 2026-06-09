# Release State

Track progress toward public beta release. Updated as work progresses.

## Current Phase: Pre-beta refinement

Release index: `docs/release/README.md`

### Scope
- Complete pre-beta quality improvements
- Validate documented onboarding paths on real hardware
- Finalize provider and model recommendations before public visibility

### Open Questions
- [ ] Live validation on all documented hardware tiers (16gb, 24gb, 32gb, 64gb, gemma-*)
- [ ] Repo naming and public framing aligned with `lac` — Lightweight Agentic Coding

### Completed
- [x] Gemma 4 model family added (models, presets, setup scripts, templates)
- [x] Pre-beta review findings fixed (missing gemma model in config, dead code, fragile grep)
- [x] OpenRouter free tier documented around a live catalog refresh path with starter defaults kept for clean-clone fallback
- [x] OpenRouter free-model availability moved from manual snapshot review to catalog-driven docs/tests
- [x] GSD workflow skill added for multi-session work
- [x] OpenRouter hardware profile added (cloud-only, zero downloads)
- [x] Skill and agent authoring templates created
- [x] Smoke test and profile sync scripts added
- [x] CI workflow added at `.github/workflows/ci.yml`

### Deferred (post-beta)
- Windows CI lane restoration; for now, validate Windows via local/manual checks until native PowerShell verification coverage exists
- Performance telemetry
- Profile composition (mix local + cloud in one profile)
- Structured feedback loop

### Next Session
Pick up from the "Open Questions" above. If a question is resolved, move it to "Completed" and add the next item.
