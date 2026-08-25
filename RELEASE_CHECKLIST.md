# Public Release Checklist

The `v0.3.0` tag was created only after every pre-tag item below completed for the exact sanitized
release commit. Changing repository visibility is a separate operator action that requires fresh
explicit approval.

Status legend: `[x]` done · `[~]` local or earlier evidence exists, exact-head/external gate pending · `[ ]` blocked or not yet run.

## v0.5.0 pre-tag gates (Qwen 3.8 oMLX recipes + Ornith 1.5)

Released 2026-08-25 by explicit operator decision ahead of local hardware benching: every
throughput number in the docs and release notes is attributed to the recipe authors'
published measurements, the new Ornith defaults ship as `standard` validation, and the
hardware runs below are tracked as post-release evidence in the same way v0.3.0 tracked its
non-blocking items.

- [x] `./scripts/verify.sh`, `./scripts/integration-test.sh`, and
  `./scripts/verify-package-build.sh` pass on the merged change, including the three oMLX
  assertions (24gb opt-out fallback; 32gb renders the oQ4e MLX slot; 16gb unmapped-default
  fallback) and 58 preset model sections.
- [x] Self-review completed (8-angle, 10 findings, 9 fixed pre-merge — oMLX settings
  hygiene, staged-weights gating, probe dedup); the one deferred finding is the Ornith
  checksum item below.

### v0.5.0 post-release evidence (not tag blockers, by operator decision)

- [ ] Bench the oMLX recipes on the maintainer testbed (`AI_LOCAL_RUNTIME=omlx lac runtime
  start` + `lac bench`, ANE kernel installed for the 32–64 GB recipe): record decode and
  prefill tok/s vs the 14.3 tok/s llama.cpp Q8 baseline. Until then the recipe numbers in
  docs are the recipe authors' published measurements, not this repo's evidence.
- [ ] Smoke the Ornith 1.5 9B default (`lac profile apply 8gb` → `runtime start` → `smoke`,
  plus one vision request through the mmproj) and the 35B-A3B alternate slot before promoting
  their `standard` validation labels.
- [ ] Record SHA256 checksums for the Ornith GGUFs from the first validated testbed download
  (they ship size-checked only until then).

## v0.4.0 pre-tag gates (Qwen 3.8 main family + `lac context`)

Tagged 2026-08-25: annotated `v0.4.0` on public sanitized commit `0bb1e56` (the
release-readiness head; the oMLX/Ornith work remains unreleased on `main` pending its own
gates). All three check suites reran green on the exact public commit, a fresh Dependabot
read returned zero alerts, and the GitHub release was created and read back
(non-draft, tag resolves to `0bb1e56`). The port's release boundary check passed all 164
public commits.

- [x] `./scripts/verify.sh`, `./scripts/integration-test.sh`, and
  `./scripts/verify-package-build.sh` passed on the merged Qwen 3.8 change (internal
  `799bc56` + release-readiness follow-ups) and reran green on public `0bb1e56` on
  2026-08-25, including 35 unit/fixture checks (one Windows-only skip), 58 active preset
  model sections (floor lowered from 60 when the Qwen 3.8 swap slimmed duplicate Qwen 3.6
  slots), the qwen3.8 oMLX-fallback assertion, the `delivery-run.v1` contract checks, and
  installed-wheel version `0.4.0`.
- [~] The Qwen 3.8 Q8 path (`48gb`/`64gb`/`128gb-multi` config) was validated on the
  maintainer's M4 Max 128 GB testbed: llama.cpp b10360 load at 256K context, mmproj vision
  completion, 14.3 tok/s bench, checksums recorded for Q8/mmproj/35B-A3B Q8.
- [x] The `48gb` profile remains `auto_recommend: false` and is described as manual/unverified;
  its 256K/Q8 memory fit is documented as tight (29.3 + ~8.5 GiB KV + compute vs the 40 GiB
  post-headroom budget) with `Q8_0` as the manual pressure fallback.
- [ ] Record separate physical evidence for the Qwen 3.8 Q3/Q4 16–32 GB defaults and for 48 GB
  before changing their current validation labels (16/24 GB were lowered to `standard` with the
  Qwen 3.8 swap until that evidence exists).
- [x] Fresh Dependabot read (zero alerts, 2026-08-25) and release boundary check (164
  public commits, clean) on the exact sanitized commit before tag.

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
- [x] Captured sanitized Qwen and ds4 static visuals plus an accelerated Qwen showcase GIF. The
  GIF displays the measured elapsed time and discloses its 3× presentation speed; all visuals use
  synthetic prompts and omit account, path, URL, and session identifiers.
- [ ] Record separate physical evidence for 16 GB, 24 GB, 48 GB, Windows/WSL, iGPU, and
  Snapdragon/Adreno paths before changing their current validation or support labels.

The automated gates and boundary check were rerun on tagged head `5989506`. Later documentation-
only successors through `main` rerun verification and the release boundary check without moving
the accepted tag.

The manually triggered GitHub compatibility workflow is optional evidence, not a tag gate. It may
be run when a hosted OS reproduction is useful, but local checks and physical-hardware evidence stay
authoritative.

## Tag and GitHub release

- [x] Created annotated tag `v0.3.0` on reviewed sanitized commit `5989506` and verified the tag
  resolved exactly to the accepted release head.
- [x] Created and read back the GitHub release notes. v0.3.0 is git-install-only; no PyPI artifact,
  Trusted Publishing setup, or billing flow is part of this release.

## Public launch

- [x] Obtained fresh explicit operator approval and made only
  `grezkium-toolshed/lightweight-agentic-coding` public.
- [x] Re-enabled Private Vulnerability Reporting and read back public visibility plus VPR enabled.
- [x] With GitHub credentials disabled, cloned default `main` and annotated tag `v0.3.0`, verified
  the repository, issues, security-reporting route, release, raw README, showcase GIF, and tagged
  bootstrap URLs, and ran the tagged bootstrap in isolated install-only mode.
- [x] All public read-backs passed; the rollback-to-private condition was not triggered.

Never commit credentials, downloaded model files, customer data, or unsanitized evidence.
