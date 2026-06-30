# Support

lac is preparing for a public beta. Support is best-effort until the release gates in `docs/release/MANUAL_VALIDATION.md` are closed.

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

For public-beta validation work, run:

```bash
./scripts/verify-public-beta-local.sh
./scripts/release-manual-next-steps.sh
```

Include your OS, hardware profile, selected runtime, relevant logs under `state/logs/`, and whether you installed from a checkout or wheel.

## Response Expectations

There is no production support SLA during public beta. Maintainers prioritize security reports, release-blocking onboarding failures, reproducible runtime regressions, and provider/model drift.
