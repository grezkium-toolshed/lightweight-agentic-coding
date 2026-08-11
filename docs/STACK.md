# The evidence-to-proof stack

lac is independently useful as a free, private local-AI workbench. In the wider
product stack, its narrower role is the **hardware-fit execution layer** for
analysis and drafting. It is not the commercial control plane and it does not
receive deployment authority.

The stack is aimed at solo operators and small MSPs that need to turn Microsoft
365 security evidence into a governed, customer-understandable improvement:

> assess → prioritize → approve → change → verify → explain → repeat

This is the product outcome. The individual repositories remain useful on their
own, but a collection of tools is not yet proof of the outcome.

## Component boundaries

| Component | Role in the loop | Boundary |
|---|---|---|
| Threat Digest | Supplies reviewed external threat context | Context may influence priority, but cannot create a tenant finding by itself |
| lac | Runs private analysis and drafting on supported hardware | Produces drafts and evidence references; never approves or executes a tenant change |
| Tenantsmith | Assesses and prioritizes posture, prepares customer communication, and performs deterministic, explicitly approved changes | Raw evidence and customer identity stay protected; consent, applicability, impact, rollback, and read-back remain mandatory |
| Platform (future, private) | Preserves delivery history, scheduling, exceptions, and portfolio state | Receives opaque references and approved projections, not unrestricted tenant data or deployment authority |

lac stays free, accountless, and usable without any other component. Commercial
value belongs to the governed delivery engagement and, later, the private
operating Platform—not to locking local inference behind an account or product
tier.

## What we copy, differentiate, and avoid

Private chat, document retrieval, local APIs, model downloads, tools, and reusable
skills are market expectations. [LM Studio](https://www.lmstudio.ai/docs/app/offline),
[Jan](https://www.jan.ai/docs/desktop/quickstart), and
[Open WebUI](https://docs.openwebui.com/features/workspace/) already cover broad
parts of that surface.

Microsoft 365 management also has mature baselines, drift handling, and tests as
code through products such as [CIPP](https://docs.cipp.app/user-documentation/tenant/standards),
[Microsoft Lighthouse](https://learn.microsoft.com/en-us/microsoft-365/lighthouse/m365-lighthouse-deploy-standard-tenant-configurations-overview),
and [Maester](https://maester.dev/docs/intro/). The stack should compose with
those systems when they are the better source or execution layer.

| Copy as an expectation | Differentiate through | Avoid |
|---|---|---|
| Clear hardware fit, recovery, and local/cloud state | Measured lac resource contracts, deterministic configuration, exact context limits, and task evidence | Another model marketplace, RAG platform, or chat UI |
| Report/Alert/Remediate separation, impact, applicability, licensing, exclusions, and drift | Approval-gated changes tied to the original finding and followed by independent read-back | Rebuilding a general Microsoft 365 administration portal |
| Versioned checks and repeat runs | One evidence chain from source through approved intent, deployment outcome, customer-safe proof, and later delta | Maximizing raw check counts or competing with an exposure graph |
| Installable workflows with visible progress | Curated packs proven on representative MSP tasks with hardware and data-egress boundaries | An uncurated workflow marketplace |

## The first proof

The differentiator is still evidence-gated. It becomes a shipped stack capability
only after one separately approved production-pilot control completes the whole
loop:

1. Preserve the original finding and its source evidence.
2. Record the customer-understandable priority and proposed intent.
3. Record applicability, licensing, consent, expected impact, and rollback.
4. Execute the approved change through Tenantsmith.
5. Read the setting back independently.
6. Reassess and record the measured delta.
7. Produce the customer-safe package from the same evidence chain.

The candidate [`delivery-run.v1`](../contracts/delivery-run.v1.schema.json)
manifest links those existing artifacts by opaque identifiers and SHA-256
references. It does not replace any component's native schema, contain credentials
or tenant identifiers, or authorize a deployment. The synthetic
[example](../contracts/fixtures/delivery-run.v1.example.json) demonstrates the
completed shape. The repository's existing `./scripts/verify.sh` gate performs
dependency-free positive, negative, and cross-reference checks.

The production pilot—not the schema or synthetic fixture—is the acceptance test.
Until that pilot passes, describe the manifest and the cross-product loop as a
candidate integration contract rather than a proven product capability.

## Opinionated engagements

The stack should package a small number of outcomes rather than hundreds of loose
features:

1. Baseline assessment and customer review package.
2. One approved security-improvement cycle with rollback and read-back evidence.
3. Recurring monthly posture and threat-context review with new, persistent,
   resolved, accepted, and regressed findings.

## Measures of value

Baseline these before choosing targets:

- operator time from collection to a customer-ready priority package;
- recommendations with source, applicability, licensing, and impact evidence;
- changes with approval, preflight, rollback, and independent read-back;
- time to identify a regression on the next run;
- customer-review preparation time;
- artifacts passed between components without manual rewriting; and
- customer-facing claims traceable to exact evidence.

The first integration proof passes only when one finding can be followed from
collection through approved change, verification, customer package, and repeat-run
delta without undocumented manual state.
