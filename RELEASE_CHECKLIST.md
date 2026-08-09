# Public Release Checklist

Do not publish a tag until every pre-tag item below is complete for the exact sanitized release
commit. Changing repository visibility is a separate operator action that requires fresh explicit
approval.

Status legend: `[x]` done · `[~]` local or earlier evidence exists, exact-head/external gate pending · `[ ]` blocked or not yet run.

## v0.3.0 pre-tag gates

- [x] `./scripts/verify.sh`, `./scripts/integration-test.sh`, and
  `./scripts/verify-package-build.sh` passed locally on 2026-08-09 for the v0.3.0 release tree,
  including 38 local model selections and installed-wheel version `0.3.0`.
- [ ] Linux/macOS/Windows CI and Python 3.10–3.13 package jobs pass on the exact sanitized
  release commit. Windows/Linux results prove configuration compatibility, not physical support.
- [ ] A fresh Dependabot read after the dependency graph rescan shows zero critical/high alerts;
  every medium/low alert has a recorded disposition.
- [x] The 128 GB ds4/DwarfStar resource path has recorded M4 Max MacBook Pro measurements.
  This does not validate unrelated platforms or the 48 GB profile.
- [x] The `48gb` profile remains `auto_recommend: false` and is described as manual/unverified.
- [ ] On a genuinely clean Apple Silicon MacBook environment, run the exact release head without
  `LAC_BOOTSTRAP_SKIP_DEMO`: install the promised toolchain, verify the checksum-protected micro
  model, health and model listing, `lac smoke`, a real response, and OpenChamber opening. Rerun
  bootstrap and confirm idempotency.
- [ ] Record the tested commit, MacBook model/chip, macOS version, elapsed time, sanitized logs,
  and screenshots outside the repository.
- [ ] Confirm version `0.3.0`, changelog, public-org links, `main` branch links, and the hosted
  bootstrap URL. The hosted `v0.3.0` URL can be read back only after the tag exists.
- [ ] Run the release boundary check over the full sanitized history and confirm a clean release
  worktree.

## Tag and GitHub release

- [ ] Create annotated tag `v0.3.0` on the reviewed sanitized commit and verify the tag resolves
  exactly to `origin/main`.
- [ ] Create and read back the GitHub release notes. v0.3.0 is git-install-only; no PyPI artifact,
  Trusted Publishing setup, or billing flow is part of this release.

## Approval-gated public flip

- [ ] Obtain fresh explicit operator approval to make the repository public.
- [ ] Change visibility, re-enable Private Vulnerability Reporting, and read both settings back.
- [ ] From an anonymous/fresh environment, verify clone, CI badge, issues/support/security links,
  the raw bootstrap URL, and the hosted one-liner.
- [ ] If any public read-back fails, return the repository to private, fix it internally, and repeat
  the port and release gates.

Never commit credentials, downloaded model files, customer data, or unsanitized evidence.
