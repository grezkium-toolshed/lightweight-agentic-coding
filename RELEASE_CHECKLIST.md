# Public Release Checklist

Do not publish a tag or package until every item below is complete for the exact release commit.

## Automated gates

- [ ] GitHub CI passes on Linux, macOS, and Windows.
- [ ] Wheel and sdist build checks pass on Python 3.10 through 3.13.
- [ ] `./scripts/verify.sh` and `./scripts/integration-test.sh` pass from a clean checkout.
- [ ] The release artifacts contain the expected first-party assets, licenses, and no opt-in third-party catalogs.

## Manual gates

- [ ] `./scripts/bootstrap.sh` completes on a fresh Apple Silicon macOS account and launches OpenChamber.
- [ ] The local demo downloads the checksum-protected micro model, starts llama.cpp, and answers a prompt through OpenChamber.
- [ ] The OpenCode fallback is exercised with OpenChamber absent.
- [ ] GitHub Private Vulnerability Reporting is enabled and the link in `SECURITY.md` opens a private report form.
- [ ] Provider documentation and starter model IDs are reviewed against current upstream documentation.
- [ ] The version and changelog match the intended public tag, and the tag is built from the reviewed commit.
- [ ] PyPI Trusted Publishing or an equivalently scoped release credential is configured and tested without publishing a real release.

Record the tested commit, date, operating system, and any screenshots or logs in the release PR. Never commit credentials or downloaded model files.
