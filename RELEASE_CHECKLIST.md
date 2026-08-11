# Public Release Checklist

Do not publish a tag until every pre-tag item below is complete for the exact sanitized release
commit. Changing repository visibility is a separate operator action that requires fresh explicit
approval.

Status legend: `[x]` done · `[~]` local or earlier evidence exists, exact-head/external gate pending · `[ ]` blocked or not yet run.

## v0.3.0 pre-tag gates

- [x] `./scripts/verify.sh`, `./scripts/integration-test.sh`, and
  `./scripts/verify-package-build.sh` passed on sanitized product commit `50c4d00` on 2026-08-11,
  including 35 unit/fixture checks (one Windows-only skip), 60 active preset model sections, the
  `delivery-run.v1` positive/negative contract checks, and installed-wheel version `0.3.0`. The
  final tagged head may add only this release-evidence documentation and must rerun the same gates.
- [x] A fresh Dependabot read on 2026-08-11 after the `50c4d00` push returned zero open alerts.
- [x] The 128 GB ds4/DwarfStar resource path has recorded M4 Max MacBook Pro measurements.
  This does not validate unrelated platforms or the 48 GB profile.
- [x] The `48gb` profile remains `auto_recommend: false` and is described as manual/unverified.
- [x] On 2026-08-11, sanitized product commit `50c4d00` passed an isolated Apple Silicon MacBook
  acceptance run without `LAC_BOOTSTRAP_SKIP_DEMO`: lac `0.3.0` and OpenChamber `1.16.3` used
  temporary pipx/pnpm/data/state roots, OpenCode `1.17.18` remained aligned, and the
  checksum-protected micro model matched `00fe7986...ef11a4`. Runtime `/health`, `/v1/models`,
  OpenChamber HTTP 200, protected OpenCode HTTP 401, and two real `lac smoke` responses passed.
  The final rerun preserved runtime/OpenChamber/OpenCode listener PIDs and the managed-session
  timestamp instead of spawning duplicates.
- [x] A real internal-candidate 32K multi-turn session passed with DCP and Ponytail enabled: the
  initial prompt used 10,860 tokens (below 75% of `context - output`), generated DCP loaded outside
  the repository and recorded context savings, tool use continued, and OpenCode automatically
  compacted at about 30K tokens before a successful follow-up task. The eight ported source,
  configuration, documentation, and test files were byte-identical between the tested internal
  commit and sanitized `50c4d00`; the exact sanitized integration gate passed all 60 model sections.
- [x] Acceptance evidence records sanitized product commit `50c4d00`, MacBook Pro / M4 Max / 128 GB,
  macOS 26.6, llama.cpp build 10280, 9-second runtime readiness, and a final 68 ms smoke response.
  Machine identifiers and unsanitized configuration are excluded. Screenshots are optional release
  assets rather than tag evidence.
- [x] Confirmed version `0.3.0`, changelog, public-org links, `main` branch links, and clone-plus-
  bootstrap instructions. v0.3.0 does not publish a hosted pipe-to-shell installer.
- [x] Checkout/unrelated-directory path parity and explicit root overrides passed fixture coverage.
  The installed wheel was also run from a temporary sample project and resolved the same isolated
  data/state/model roots with no legacy checkout state.
- [x] Synthetic global/project OpenCode fixtures remain byte-identical and cover every advisory
  warning plus the clean-config case. The pinned OpenCode acceptance run inspected the real merged
  configuration, continued after the expected inherited-plugin warning, kept sharing disabled and
  edits confirmation-gated, and selected the loopback local provider.
- [x] The release boundary check passed all 148 sanitized commits and the release worktree remained
  clean after verification, integration, and package-build checks.

## Post-launch evidence (not v0.3.0 tag blockers)

- [ ] Restart a first-use plugin-backed session without network access and confirm cached DCP and
  Ponytail load without changing the selected local provider or sharing boundary.
- [ ] Capture sanitized static screenshots for release/documentation use; do not add a v0.3 GIF.
- [ ] Record separate physical evidence for 16 GB, 24 GB, 48 GB, Windows/WSL, iGPU, and
  Snapdragon/Adreno paths before changing their current validation or support labels.

Before tagging, rerun the automated gates and boundary check on the documentation-only successor
to `50c4d00` and confirm its product/package content remains unchanged.

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
