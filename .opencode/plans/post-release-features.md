# Plan: Post-Release Features

**Status:** Draft
**Order:** 1 → 2 → 4 → 3 → 5 (recommended execution order)

---

## Phase 1 — `lac demo`: Instant On-Ramp

**Goal:** 60 seconds from clone to first chat. No hardware requirements.

### Two modes

**`lac demo` (interactive):** Asks cloud or local, then executes.

**`lac demo --cloud` (default):** Uses OpenRouter free tier.
1. Check for `OPENROUTER_API_KEY`. If missing, prompt user to enter one or open browser to signup.
2. Apply `openrouter` profile, render config.
3. Launch OpenChamber at `http://localhost:3000`.
4. User chats immediately — zero downloads, zero local runtime.

**`lac demo --local`:** Downloads a tiny model.
1. Needs a new `micro` profile with a small GGUF (~1-3B param model, ~1-2GB).
2. Runs `lac models sync micro`, `lac runtime start`.
3. Launches OpenChamber.

### Files to create/modify

| File | Change |
|---|---|
| `src/lac/cli.py` | New `demo` parser + dispatch handler |
| `src/lac/models.py` | New `micro` entry in PROFILE_MODELS (small GGUF from Unsloth) |
| `runtime-config/presets/micro.ini` | Tiny model preset (low context, low threads) |
| `src/lac/data/runtime-config/presets/micro.ini` | Mirror |
| `runtime-config/profiles.json` | `micro` profile definition with runtime_mode=local |
| `src/lac/data/runtime-config/profiles.json` | Mirror |
| `docs/use-cases/QUICKSTART.md` (new) | Docs for the demo flow |

### Model candidate

Qwen3.5-4B or Qwen3.5-1.5B GGUF from Unsloth. Both are <2GB and run on any hardware including laptops with no GPU.

---

## Phase 2 — `lac doctor --fix`: Self-Healing

**Goal:** `lac doctor --fix` identifies problems and offers to fix them, in dependency order.

### Fix registry

| Priority | Problem | Fix | Risk |
|---|---|---|---|
| P0 | Missing opencode | `curl -fsSL https://opencode.ai/install \| bash` | Safe |
| P1 | Missing llama-server | `brew install llama.cpp` / `apt install` / build | May need sudo |
| P2 | Missing generated state | `lac profile apply <profile>` | Safe |
| P2 | Missing model files | `lac models sync <profile>` | Long-running |
| P3 | Runtime stopped | `lac runtime start` | Safe |
| P3 | Runtime unhealthy | `lac runtime stop && lac runtime start` | Safe |
| P4 | Stale client renders | `lac client render openchamber` | Safe |
| P4 | Outdated config | `lac profile apply <profile>` | Safe |

### Design

- Each fix is a function: `check(ctx) → bool` + `fix(ctx) → bool`
- `--fix` runs all checks, prints plan, asks confirmation (or `--yes` to auto-confirm)
- Dependency ordering: P0 before P1 before P2...
- Failures don't block later fixes
- `--json` output for scripting

### Files

| File | Change |
|---|---|
| `src/lac/doctor.py` (new) | Fix registry — check/fix functions, ordering, dispatch |
| `src/lac/cli.py` | Add `--fix` flag to `doctor` parser, wire dispatch |

---

## Phase 3 — `lac bench`: Performance Benchmarking

**Goal:** Measure tokens/sec, TTFT, peak memory per model slot.

### Usage

```bash
lac bench                              # benchmark all active preset slots
lac bench --model qwen3.6-27b-mtp-q4   # specific model
lac bench --draft-n 1,2,4,6            # sweep MTP draft token counts
lac bench --prompt "write a poem"      # custom prompt
lac bench --json                       # machine-readable output
```

### Metrics

- Model load time
- Time to first token (TTFT)
- Generation throughput (tok/s)
- Peak VRAM/RAM (via `nvidia-smi` or `memory_profiler` or llama-server status)
- Output sample (first 200 chars)

### Design

- Uses running llama-server if available; starts one temporarily if not
- Sends standardized chat completion request (256 in, 512 out)
- For `--draft-n`, reuses same prompt across values
- Outputs table + `--json`

### Files

| File | Change |
|---|---|
| `src/lac/bench.py` (new) | Benchmark logic |
| `src/lac/cli.py` | New `bench` parser + handler |
| `docs/use-cases/BENCHMARKING.md` (new) | Usage guide |

---

## Phase 4 — Curated Pack Expansion

**Goal:** Broaden scenario coverage beyond coding/docs/office.

### Candidate packs

| Pack | Agent(s) | Reuses existing skills? |
|---|---|---|
| **devops** | Terraform plan reviewer, Dockerfile auditor, CI/CD pipeline reviewer | Yes — reuses `skill:gsd` |
| **database-migration** | Schema diff analyst, migration script generator, rollback planner | New skill needed |
| **security-audit** | Dependency scanner, secret detector, permission reviewer | New skill |
| **data-engineering** | ETL pipeline reviewer, data contract validator | New skill |

### First pack: devops

1. Create `.opencode/agents/devops-reviewer.md` — follows existing agent format (frontmatter + markdown body)
2. Add to `catalog/assets.json` — new asset entry with `type: "agent"`, `pack: "devops"`, `trust_level: "core"`
3. Add to `catalog/workflow-packs.json` — new pack entry with assets list
4. Mirror to `src/lac/data/catalog/`
5. Optionally update `scenarios.json` to include devops in relevant scenarios

### Files per new pack

| File | Change |
|---|---|
| `.opencode/agents/<name>.md` | Agent definition |
| `catalog/assets.json` + `src/lac/data/` | Asset entry |
| `catalog/workflow-packs.json` + `src/lac/data/` | Pack entry |

---

## Phase 5 — Remote GPU Bursting

**Phase 5a — Docs + Scripts (minimum viable):**

`docs/providers/GPU_BURSTING.md`:
- RunPod / Vast / Lambda Labs setup
- Creating a llama-server template on RunPod
- SSH key setup
- `autossh` tunnel to forward remote :8080 to local :8080
- Pricing comparison (spot vs on-demand, A6000 vs A100 vs H100)

`scripts/tunnel-to-cloud.sh`:
- `autossh` wrapper with auto-reconnect
- Checks for local port conflicts
- Prints connection URL

**Phase 5b — CLI integration (if demand validated):**

| File | Change |
|---|---|
| `src/lac/cli.py` | `lac provider start|stop|tunnel <provider>` subcommands |
| `src/lac/providers.py` or new `src/lac/cloud.py` | Cloud provider lifecycle (RunPod API, SSH tunnel mgmt) |
| `docs/providers/GPU_BURSTING.md` | Expand with CLI steps |

Phase 5b is a full sprint on its own. Start with 5a first.

---

## Execution Order & Dependencies

```
Phase 1 (demo) ──────┐
                      ├──→ Phase 2 (doctor --fix) ──→ Phase 3 (bench)
                      │         (reuses install hints)
Phase 4 (packs) ──────┘
                               Phase 5a (docs+scripts)
                                      │ (if demand validated)
                               Phase 5b (full CLI)
```

- Phase 1 and Phase 4 are independent — can be done in parallel
- Phase 2 depends on Phase 1's `_install_hint` additions (but has its own)
- Phase 3 is independent
- Phase 5 is independent of all others

## Effort Summary

| Phase | Python | Config/Docs | Complexity |
|---|---|---|---|
| 1. demo | ~100 lines | 4 files | Low |
| 2. doctor --fix | ~150 lines | None | Medium |
| 3. bench | ~120 lines | 1 doc file | Low-Medium |
| 4. packs | ~50 lines | 3+ files | Low |
| 5a. bursting docs | ~80 lines shell | 1 doc file | Low |
| 5b. bursting CLI | ~200 lines | None | High |
