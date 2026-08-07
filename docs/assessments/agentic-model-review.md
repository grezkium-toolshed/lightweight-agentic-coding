# Agentic Model Review — Local File Analysis Capability

Status: research brief (decision-ready, not yet validated on real assessment data)

## Decision question

Can local models — small (4-12B) and large (27B+) — reliably do agentic file work: read
local files (json/md/csv assessment exports), create local files (reports, summaries),
and follow multi-step analysis instructions? What permissions and allowances do they
need?

## Core finding: file access is harness-side, not model-side

Reading and creating files is performed by the agent harness (OpenCode's `read`/`write`/
`edit`/`bash` tools), not by the model itself. The model contributes three things:

1. **Tool-call reliability** — emitting valid tool-call JSON (function calling) instead of
   prose when it decides to read, write, or run a command.
2. **Instruction following** — honoring system prompts, permission boundaries, and
   output contracts across multiple turns.
3. **Context handling** — using a large file without overflowing the context window or
   losing track of earlier findings in long sessions.

So "can a small model read files" translates to "how reliable is its tool calling and
instruction following at that size and quantization". File capability itself is available
to every model; the quality gap shows in multi-step loops and long analyses.

## Evidence

### Agentic tool-use benchmark (Tau2) — Gemma 4 family (official, Google via Unsloth)

| Model | Tau2 | LiveCodeBench v6 | Codeforces ELO |
|---|--:|--:|--:|
| Gemma 4 31B | **76.9%** | 80.0% | 2150 |
| Gemma 4 12B | **69.0%** | 72.0% | 1659 |
| Gemma 4 26B-A4B (MoE) | 68.2% | 77.1% | 1718 |
| Gemma 4 E4B | 42.2% | 52.0% | 940 |

Read: the 12B sits within ~8 points of the 31B on agentic tool use — usable for short,
structured analysis tasks. The E4B cliff (42.2%) marks it as chat/summarization-only.

### Qwen3.5/3.6 family

- Unsloth shipped a **universal chat-template tool-calling fix** for Qwen3.5 GGUFs
  (Mar 2026); tool calling is treated as reliable on this family at Q4 and above.
- This repo's guidance: Qwen 3.6 has **better tool-call reliability** than the previous
  Qwen Coder generation; `Qwen Coder Next` was removed from local presets in its favor
  (`docs/model-recommendations.md`).
- 27B vs 35B-A3B: 27B is the slightly more accurate pick when it fits; 35B-A3B wins on
  speed. For agentic work on 32 GB machines, the dense 27B is the repo default.

### This repo's tier guidance (from `docs/model-recommendations.md`)

- 4 GB: chat + light automation only.
- 8 GB: the agentic floor — small models, short sessions.
- 12-16 GB: real multi-step agentic work begins.
- 32 GB+: comfortable for 27B-class dense models; 128 GB covers 35B-A3B Q8 and the
  DeepSeek V4 Flash (ds4) path.

### Evidence gaps

- Exact BFCL v4 per-model scores for these local families were not captured (leaderboard
  renders client-side); treat vendor Tau2/LiveCodeBench as the agentic signal and run
  your own smoke tests before committing a fleet default.

## Model tiers for assessment analysis

Task profile: read mixed json/md/csv exports (xlsx converted to csv at staging time),
summarize findings, write a recommendations report, possibly run pandas for
aggregations. Mostly short-to-medium sessions, single workspace, operator reviews output.

| Tier | Models (profile) | Footprint | Verdict for assessment analysis |
|---|---|---|---|
| Small | Qwen3.5 9B Q4 (`macos-16gb`), Gemma 4 12B Q4/QAT (`gemma-8gb`+) | 6-8 GB | Fine for **single-file summarization and short sessions**; expect manual steering in loops. Gemma 4 12B preferred (Tau2 69.0). Avoid E4B/2B for anything agentic. |
| Mid | Qwen 3.6 27B Q4 (`24gb`/`32gb`), Gemma 4 31B Q4 (`gemma-32gb`) | 17-20 GB | **Recommended default for the 32 GB workstation.** Reliable multi-step tool calling, enough context for full-run analysis. |
| High | Qwen 3.6 35B-A3B Q8 (`64gb`+), DeepSeek V4 Flash q2 (`128gb-ds4-flash`) | 38-100 GB | Headroom for very long exports and heavier aggregation; the 128 GB M4 Max slot. |

Rule of thumb: **small models for assisted analysis, mid/high models for autonomous
analysis.** The staged-folder workflow (see `assessment-analysis-workflow.md`) is designed
so even small models succeed: short context units, manifest-driven file list, output
contract.

## Permissions and allowances for local file access

The model runs through the OpenCode harness against a local llama.cpp `llama-server` on
`127.0.0.1` — no provider, no cloud. Data cannot leave the machine by construction as
long as:

- `webfetch` is denied (no exfiltration channel, no prompt-injection channel).
- The model endpoint is the local server only (no cloud provider keys in the config).
- OpenCode permissions scope `edit` and `bash` to the assessment workspace.

Concrete permission block for an assessment workspace (see workflow doc for placement):

```jsonc
{
  "permission": {
    "edit": "allow",          // scoped to the assessment workspace dir
    "bash": "allow",          // needed for python/pandas on large CSVs
    "webfetch": "deny",       // privacy-locked: no network calls
    "ask": "always"           // optional: prompt before any outside-workspace write
  }
}
```

Trade-offs to know:

- `bash: allow` is what makes large-file analysis possible (pandas over context dumps)
  and is also the highest-trust allowance. `ask` mode is the conservative alternative
  but slows operator workflows.
- `edit: allow` restricted to the workspace means the model can only create/modify files
  under the run folder; it cannot touch the rest of the machine.
- Read access (`read`/`glob`/`grep`) is inherent to the harness for the opened workspace;
  use a dedicated workspace per run so "what the model can see" is exactly the
  agentic-only folder.

## Recommendation

1. Use **Gemma 4 12B (small)** and **Qwen 3.6 27B (mid)** as the two reference models:
   one for portable/16 GB machines, one for 32 GB workstations. Validate both with one
   smoke run on a real export before fleet rollout.
2. Adopt the **privacy-locked permission block** above for all assessment workspaces.
3. Treat E4B/2B and sub-Q4 quants as **non-agentic** — chat and summarization only.
4. On the 128 GB M4 Max, prefer the existing `64gb`/`128gb` profiles; the 35B-A3B Q8 is
   the quality ceiling for analysis loops today.

## Open risks

- No per-model BFCL data captured here; tool-call reliability differences between
  Qwen/Gemma at equal size remain untested in this repo.
- Long-context behavior (100K+ tokens in a single analysis) is where small models fail
  first; mitigation is the staged folder + manifest, not bigger context windows.
- Gemma 4 thinking mode (`<|think|>`) changes generation behavior; keep it disabled for
  analysis loops unless a smoke test shows benefit.
