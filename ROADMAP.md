# Roadmap

lac is a free, accountless tool for privacy-sensitive individuals and self-directed employees who are allowed to run local software. Developers, researchers, and small-team pilots are secondary audiences.

Generic offline chat is already served by [LM Studio](https://www.lmstudio.ai/docs/app/offline), [Jan](https://www.jan.ai/docs), and [AnythingLLM](https://www.anythingllm.co/). lac focuses on hardware-aware setup, curated agentic workflows, and reproducible local configuration. This roadmap is evidence-gated and intentionally undated.

## Toward v1.0 — trustworthy self-service

- Stabilize the public beta as reproducible self-service on Apple Silicon MacBooks.
- Keep Windows, Linux, Intel Macs, ordinary iGPUs, and Snapdragon/Adreno experimental until
  physical-runtime evidence justifies a support change.
- Deterministic hardware selection with conservative fallbacks.
- Make every MacBook profile either hardware-verified or clearly marked as a candidate; enable
  automatic 48 GB selection only if its exact hardware contract passes.
- Keep manifest, preset, model, and generated-client contracts consistent and reproducible.
- Clear privacy boundaries between local work and optional cloud providers.

## v1.5 — hardware-fit workbench

- A read-only `lac hardware [--json]` diagnostic command that never applies a profile.
- Cross-vendor memory diagnostics that distinguish dedicated VRAM, iGPU budgets, Apple unified memory, and Snapdragon shared memory.
- Measured model resource contracts: weights, context, KV cache, runtime headroom, and observed throughput.
- Validation badges backed by recorded target-hardware evidence.
- Clearer reporting of the selected budget source, confidence, fit, and remaining headroom.
- Physical validation beyond MacBooks only when representative hardware is available. Add a
  native DXGI budget probe only if Windows runtime output proves insufficient.

## v2.0 — private-work workspace

- Scenario-led `lac init` entry points for everyday work, research, coding, and small-team pilots.
- Reproducible workspaces generated from scenario, hardware profile, proven workflow packs,
  client, and local-versus-optional-cloud boundary.
- Proven workflow packs with representative task evidence and durable, machine-readable
  scenario and profile metadata.
- Explicit local-versus-optional-cloud boundaries at each entry point.
- A stable OpenAI-compatible runtime boundary and machine-readable model/runtime provenance.
- Reproducible workspace setup without turning lac into enterprise management software;
  scheduling, fleet operations, tenant isolation, SSO, audit, and billing stay in the separate
  private stack-v2 platform.

## Non-goals

lac does not plan to provide fleet management, MDM deployment, SSO, centralized policy enforcement, procurement or compliance assurance, hosted inference, telemetry, billing, or support SLAs.

The tool stays free and accountless. Advanced one-to-one setup or training may someday be offered as a separately agreed human service; it is not a product tier, entitlement, billing feature, or roadmap dependency.

## Evidence gates

- A profile becomes automatically recommended only after its resource contract passes on representative hardware.
- Parser support and physical-hardware validation are reported separately.
- The `48gb` profile remains manual until a real 48 GB MacBook Pro completes sync, apply, start, health/model checks, `lac smoke`, memory-pressure checks, and representative everyday-work and tool-using tasks at its declared context.
- Candidate model families do not replace defaults until official weights, llama.cpp compatibility, exact resource estimates, and target-hardware results are available.
