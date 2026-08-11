# Public Release Checklist

Do not publish a tag until every pre-tag item below is complete for the exact sanitized release
commit. Changing repository visibility is a separate operator action that requires fresh explicit
approval.

Status legend: `[x]` done · `[~]` local or earlier evidence exists, exact-head/external gate pending · `[ ]` blocked or not yet run.

## v0.3.0 pre-tag gates

- [~] `./scripts/verify.sh`, `./scripts/integration-test.sh`, and
  `./scripts/verify-package-build.sh` passed locally on 2026-08-11 for the internal v0.3.0 release
  candidate, including 35 unit/fixture checks (one Windows-only skip), 60 active preset model
  sections, the `delivery-run.v1` positive/negative contract checks, and installed-wheel version
  `0.3.0`. A live rerun also reused the same healthy OpenChamber/OpenCode ports without duplicate
  processes. Repeat all three checks on the exact sanitized release head.
- [ ] A fresh Dependabot read after the dependency graph rescan shows zero critical/high alerts;
  every medium/low alert has a recorded disposition.
- [x] The 128 GB ds4/DwarfStar resource path has recorded M4 Max MacBook Pro measurements.
  This does not validate unrelated platforms or the 48 GB profile.
- [x] The `48gb` profile remains `auto_recommend: false` and is described as manual/unverified.
- [ ] On a genuinely clean Apple Silicon MacBook environment, run the exact release head without
  `LAC_BOOTSTRAP_SKIP_DEMO`: install the promised toolchain with OpenCode `1.17.18` and OpenChamber
  `1.16.3`, verify the checksum-protected micro model, health and model listing, `lac smoke`, a real
  response, and OpenChamber opening. Rerun bootstrap and confirm idempotency.
- [~] A real internal-candidate 32K multi-turn session passed with DCP and Ponytail enabled: the
  initial prompt used 10,860 tokens (below 75% of `context - output`), generated DCP loaded outside
  the repository and recorded context savings, tool use continued, and OpenCode automatically
  compacted at about 30K tokens before a successful follow-up task. Repeat this evidence run on the
  exact sanitized release head.
- [ ] Record the tested commit, MacBook model/chip, macOS version, elapsed time, sanitized logs,
  and screenshots outside the repository.
- [ ] Confirm version `0.3.0`, changelog, public-org links, `main` branch links, and clone-plus-
  bootstrap instructions. v0.3.0 does not publish a hosted pipe-to-shell installer.
- [~] Local fixture coverage confirms checkout/unrelated-directory path parity and explicit root
  overrides. On the exact sanitized head, also run from a sample user project and confirm `lac doctor
  --json` resolves the same data/state/model roots. Repeat with explicit root overrides.
- [~] Local synthetic global/project OpenCode fixtures remain byte-identical and cover every
  advisory warning plus the clean-config case. Repeat with pinned OpenCode on the exact sanitized
  head; confirm workspace edits ask by default and launch continues.
- [ ] Run the first plugin-backed session online, then restart offline and confirm cached DCP and
  Ponytail load without changing the selected local provider or sharing boundary.
- [ ] Run the release boundary check over the full sanitized history and confirm a clean release
  worktree.

The manually triggered GitHub compatibility workflow is optional evidence, not a tag gate. It may
be run when a hosted OS reproduction is useful, but local checks and physical-hardware evidence stay
authoritative.

## Tag and GitHub release

- [ ] Create annotated tag `v0.3.0` on the reviewed sanitized commit and verify the tag resolves
  exactly to `origin/main`.
- [ ] Create and read back the GitHub release notes. v0.3.0 is git-install-only; no PyPI artifact,
  Trusted Publishing setup, or billing flow is part of this release.

## Approval-gated public flip

- [ ] Obtain fresh explicit operator approval to make the repository public.
- [ ] Change visibility, re-enable Private Vulnerability Reporting, and read both settings back.
- [ ] From an anonymous/fresh environment, verify clone, issues/support/security links, release
  notes, and the clone-plus-bootstrap path.
- [ ] If any public read-back fails, return the repository to private, fix it internally, and repeat
  the port and release gates.

Never commit credentials, downloaded model files, customer data, or unsanitized evidence.
