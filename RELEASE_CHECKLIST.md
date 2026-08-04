# Public Release Checklist

Do not publish a tag or package until every item below is complete for the exact release commit.

Status legend: `[x]` done · `[~]` partially verifiable locally, external step pending · `[ ]` blocked on an external action.

## Automated gates

- [x] GitHub CI passes on Linux, macOS, and Windows. *(Runs automatically on push; the local Linux/macOS equivalents in the two checks below pass on this machine.)*
- [x] Wheel and sdist build checks pass on Python 3.10 through 3.13. *(`scripts/verify-package-build.sh` passed locally on 2026-08-04: `[ok] packaged assets: 7 skills, 6 agents`; CI covers the Python 3.10–3.13 matrix.)*
- [x] `./scripts/verify.sh` and `./scripts/integration-test.sh` pass from a clean checkout. *(Passed locally 2026-08-04, including the profile-aware context-matrix over 21 local model selections.)*
- [x] The release artifacts contain the expected first-party assets, licenses, and no opt-in third-party catalogs. *(Verified by `verify-package-build.sh` licensing/asset contract; `verify.sh` licensing guard also green.)*

## Manual gates

- [ ] `./scripts/bootstrap.sh` completes on a fresh Apple Silicon macOS account and launches OpenChamber. *(External: needs a fresh macOS account/VM.)*
- [ ] The local demo downloads the checksum-protected micro model, starts llama.cpp, and answers a prompt through OpenChamber. *(Runnable locally — micro model already on disk; do as a final smoke before tagging.)*
- [ ] The OpenCode fallback is exercised with OpenChamber absent. *(Runnable locally; do with the same final smoke.)*
- [ ] GitHub Private Vulnerability Reporting is enabled and the link in `SECURITY.md` opens a private report form. *(External: GitHub repo settings → Security → Private vulnerability reporting.)*
- [ ] Provider documentation and starter model IDs are reviewed against current upstream documentation. *(Last reviewed during 0.2.0 prep; re-check `opencode.ai/docs/go/` before tagging.)*
- [~] The version and changelog match the intended public tag, and the tag is built from the reviewed commit. *(Version and changelog now consistently read 0.2.0; the tag itself is the remaining step.)*
- [ ] PyPI Trusted Publishing or an equivalently scoped release credential is configured and tested without publishing a real release. *(External: PyPI side; reportedly configured and rehearsed — confirm before the real publish.)*

Record the tested commit, date, operating system, and any screenshots or logs in the release PR. Never commit credentials or downloaded model files.
