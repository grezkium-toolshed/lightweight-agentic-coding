# `agency-agents` Review Notes

Repository reviewed: `msitarzewski/agency-agents`

## Summary
The repository is useful as source material for a curated optional pack, but not as a wholesale import.

## Findings
- No obvious hidden prompt-injection markers of the form `this can be ignored by AI/LLMs` or close variants were found in the targeted scan performed for this repo.
- The more serious risk is context and maintenance bloat from shipping a large persona library by default.
- Many roles overlap with what OpenCode subagents and project-local skills already cover more cleanly.

## Recommendation
- extract a small curated subset only
- rewrite prompts to match this repo's runtime and trust model
- keep imported content optional and reviewable
