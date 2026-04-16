# Private Until Release

This repo is intentionally being prepared for a future public beta release, but it should remain private until the release gates below are complete.

## Release gates
- CI workflow (`.github/workflows/ci.yml`) is green for the current branch
- runtime scripts validated on macOS, Linux, and Windows
- docs consistent with current files and commands
- curated agents and skills reviewed for trust and usefulness
- provider docs refreshed against current APIs and auth expectations
- no machine-specific assumptions in tracked files
- no accidental model or cache artifacts in the tree
- release reviewer pass completed
- `RELEASE_CHECKLIST.md` completed
- a real private vulnerability reporting path enabled

## Practical rule
Do not optimize for public polish at the cost of runtime correctness. Public beta comes after the system is stable, documented, and validated on the documented paths.
