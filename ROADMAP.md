# Roadmap

lac is a free, accountless tool for privacy-sensitive individuals and self-directed employees who are allowed to run local software. Developers, researchers, and small-team pilots are secondary audiences.

Generic offline chat is already served by [LM Studio](https://www.lmstudio.ai/docs/app/offline), [Jan](https://www.jan.ai/docs), and [AnythingLLM](https://www.anythingllm.co/). lac focuses on hardware-aware setup, curated agentic workflows, and reproducible local configuration. This roadmap is evidence-gated and intentionally undated.

lac remains independently useful. In the wider Microsoft 365 security stack it is the private,
hardware-fit analysis and drafting layer—not the commercial control plane, a tenant-management
portal, or deployment authority. The coordinated stack roadmap and lac SemVer are related but
separate; see [the evidence-to-proof stack](docs/STACK.md).

## Toward v1.0 — trustworthy self-service

- Stabilize the public beta as reproducible self-service on Apple Silicon MacBooks.
- Keep Windows, Linux, Intel Macs, ordinary iGPUs, and Snapdragon/Adreno experimental until
  physical-runtime evidence justifies a support change.
- Deterministic hardware selection with conservative fallbacks.
- Make every MacBook profile either hardware-verified or clearly marked as a candidate; enable
  automatic 48 GB selection only if its exact hardware contract passes.
- Keep manifest, preset, model, and generated-client contracts consistent and reproducible.
- Clear privacy boundaries between local work and optional cloud providers.
- Complete the public v0.3 release gates before starting substantial v1.5 or v2.0 work.

## lac v1.5 — hardware-fit workbench

- A read-only `lac hardware [--json]` diagnostic command that never applies a profile.
- Cross-vendor memory diagnostics that distinguish dedicated VRAM, iGPU budgets, Apple unified memory, and Snapdragon shared memory.
- Measured model resource contracts: weights, context, KV cache, runtime headroom, and observed throughput.
- Validation badges backed by recorded target-hardware evidence.
- Clearer reporting of the selected budget source, confidence, fit, and remaining headroom.
- Physical validation beyond MacBooks only when representative hardware is available. Add a
  native DXGI budget probe only if Windows runtime output proves insufficient.
- Scenario-led workflow packs for everyday work, research, coding, and stack analysis.
- Task evidence cards that record the model, hardware, context, result, limitations, and data-egress boundary.
- Continued use of external OpenAI-compatible clients instead of a new lac desktop application.

## Coordinated stack v1.5 — one proven delivery chain

These are cross-repository outcomes, not lac CLI promises:

- Prove one finding through assessment, priority, approved intent, deterministic change,
  independent read-back, customer-safe package, and repeat-run delta.
- Adopt the candidate `delivery-run.v1` manifest across the participating products only after
  that pilot establishes the minimum useful fields.
- Preserve explicit Report/Alert/Remediate modes plus impact, licensing, applicability, consent,
  exception, and rollback metadata in the systems that own those decisions.
- Distinguish new, persistent, resolved, accepted, and regressed findings on repeat runs.
- Keep the Threat Digest observation adapter after the first production proof so it cannot delay
  the simpler finding-to-verification loop.

## lac v2.0 — private-work workspace

- Scenario-led `lac init` entry points for everyday work, research, coding, and small-team pilots.
- Reproducible workspaces generated from scenario, hardware profile, proven workflow packs,
  client, and local-versus-optional-cloud boundary.
- Proven workflow packs with representative task evidence and durable, machine-readable
  scenario and profile metadata.
- Explicit local-versus-optional-cloud boundaries at each entry point.
- A stable OpenAI-compatible runtime boundary and machine-readable model/runtime provenance.
- Reproducible workspace setup without turning lac into enterprise management software;
  scheduling, fleet operations, tenant isolation, SSO, audit, and billing stay in the separate
  private stack Platform.

## Coordinated stack v2.0 — private operating Platform

Build the private Platform only around needs proven by real delivery runs:

- durable delivery-run and evidence history;
- scheduling and recurring comparisons;
- approval, exception, and rollback records;
- a portfolio view of customer state, blocked actions, and verified improvements;
- customer-package generation from explicitly approved evidence; and
- adapters to CIPP, Lighthouse, Maester, and Microsoft APIs when they are the better source or
  execution layer.

General Microsoft 365 administration, hosted inference, a local-AI user interface, a broad
connector marketplace, billing machinery, and enterprise identity infrastructure are not initial
Platform goals.

## Non-goals

lac does not plan to provide fleet management, MDM deployment, SSO, centralized policy enforcement, procurement or compliance assurance, hosted inference, telemetry, billing, or support SLAs.

The tool stays free and accountless. Advanced one-to-one setup or training may someday be offered as a separately agreed human service; it is not a product tier, entitlement, billing feature, or roadmap dependency.

## Evidence gates

- A profile becomes automatically recommended only after its resource contract passes on representative hardware.
- Parser support and physical-hardware validation are reported separately.
- The `48gb` profile remains manual until a real 48 GB MacBook Pro completes sync, apply, start, health/model checks, `lac smoke`, memory-pressure checks, and representative everyday-work and tool-using tasks at its declared context.
- Candidate model families do not replace defaults until official weights, llama.cpp compatibility, exact resource estimates, and target-hardware results are available.
- A workflow pack earns a proven label only after a representative task records its model,
  hardware, context, output quality, limitations, and data-egress boundary.
- The stack's evidence-to-proof claim remains a candidate until the approved production pilot
  completes the full chain and the repeat-run delta without undocumented manual state.
