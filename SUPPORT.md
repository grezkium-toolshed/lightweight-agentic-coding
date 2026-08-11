# Support

lac is a free community product maintained on a best-effort basis. There is no support SLA.

## Validation status (public beta)

**Tested and supported platform: Apple Silicon MacBooks.** The 128 GB ds4/DwarfStar path has
measured M4 Max MacBook Pro evidence. Profile validation remains separate from platform support:
the `48gb` profile is still manual and unverified on an exact 48 GB configuration.

**Experimental, test at your own risk:** Windows, Linux, Intel Macs, ordinary iGPUs,
Snapdragon/Adreno, and any other hardware without recorded physical-runtime evidence. WSL2 is the
preferred Windows local-model route; native OpenChamber with Go/Zen is a cloud alternative rather
than a local-only deployment. See [Windows routes and requirements](docs/WINDOWS.md). Local release
checks cover contracts, packaging, parsers, wrappers, and rendered configuration. An optional manual
GitHub workflow can repeat those compatibility checks, but neither path proves GPU/runtime
compatibility or performance on physical machines. Reports are
welcome, but experimental results do not create a support guarantee.

The isolated clean-install bootstrap and OpenChamber flow passed the v0.3 release gate on Apple Silicon.

## Where to Ask

- Bugs in setup, profiles, runtime launch, or generated config: use the bug report issue template.
- Documentation mismatches: use the docs mismatch issue template.
- Provider or free-model drift: use the provider/model drift issue template.
- New hardware profile requests: use the hardware profile request issue template.
- Security issues: follow `SECURITY.md`. Do not post exploit details in public issues.

## Before Opening an Issue

Run the local diagnostics that match your problem:

```bash
lac doctor --json
lac runtime status --json
lac provider verify --all --json
```

Include your OS, hardware profile, selected runtime, the `paths` and sanitized
`opencode_coexistence` sections from `lac doctor --json`, and whether you installed
from a checkout or wheel. Do not post raw OpenCode effective configuration or credentials.
See [OpenCode coexistence and privacy checks](docs/OPENCODE-COEXISTENCE.md).

## Response Expectations

There is no support SLA. Maintainer attention, when available, prioritizes security reports, reproducible onboarding failures, runtime regressions, and provider/model drift.
