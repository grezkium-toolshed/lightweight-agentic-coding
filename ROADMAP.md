# Roadmap

lac is a free, accountless tool for privacy-sensitive individuals and self-directed employees who are allowed to run local software. Developers, researchers, and small-team pilots are secondary audiences.

Generic offline chat is already served by [LM Studio](https://www.lmstudio.ai/docs/app/offline), [Jan](https://www.jan.ai/docs), and [AnythingLLM](https://www.anythingllm.co/). lac focuses on hardware-aware setup, curated agentic workflows, and reproducible local configuration. This roadmap is evidence-gated and intentionally undated.

## Toward v1.0 — trustworthy self-service

- Reproducible installation and honest platform support.
- Deterministic hardware selection with conservative fallbacks.
- Validated core profiles and consistent manifest, preset, model, and client contracts.
- Clear privacy boundaries between local work and optional cloud providers.

## v1.5 — hardware-fit workbench

- Cross-vendor memory diagnostics that distinguish dedicated VRAM, iGPU budgets, Apple unified memory, and Snapdragon shared memory.
- Measured model resource contracts: weights, context, KV cache, runtime headroom, and observed throughput.
- Validation badges backed by recorded target-hardware evidence.
- Clearer reporting of the selected budget source, confidence, fit, and remaining headroom.

## v2.0 — private-work workspace

- Scenario-led entry points for everyday work, research, coding, and small-team pilots.
- Proven workflow packs with durable, machine-readable scenario and profile metadata.
- Explicit local-versus-optional-cloud boundaries at each entry point.
- Reproducible workspace setup without turning lac into enterprise management software.

## Non-goals

lac does not plan to provide fleet management, MDM deployment, SSO, centralized policy enforcement, procurement or compliance assurance, hosted inference, telemetry, billing, or support SLAs.

The tool stays free and accountless. Advanced one-to-one setup or training may someday be offered as a separately agreed human service; it is not a product tier, entitlement, billing feature, or roadmap dependency.

## Evidence gates

- A profile becomes automatically recommended only after its resource contract passes on representative hardware.
- Parser support and physical-hardware validation are reported separately.
- The `48gb` profile remains manual until a real 48 GB MacBook Pro completes sync, apply, start, health/model checks, `lac smoke`, memory-pressure checks, and representative everyday-work and tool-using tasks at its declared context.
- Candidate model families do not replace defaults until official weights, llama.cpp compatibility, exact resource estimates, and target-hardware results are available.
