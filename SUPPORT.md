# Support

lac is a community project maintained on a best-effort basis. It works today, but it is a
small side project, not a supported product — please set expectations accordingly.

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

Include your OS, hardware profile, selected runtime, relevant logs under `state/logs/`, and whether you installed from a checkout or wheel.

## Response Expectations

There is no support SLA. Maintainer attention, when available, prioritizes security reports, reproducible onboarding failures, runtime regressions, and provider/model drift.
