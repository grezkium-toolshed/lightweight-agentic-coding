# Onboarding Scenario: 16GB or 24GB Local-First with Cloud Fallback

## Best fit
- developers and operators on mainstream laptops
- startup users who need a practical local baseline
- teams piloting agentic workflows without large local hardware

## Recommended path
1. Start with `./bin/lac init`; use `macos-16gb` for MacBook Air M4 16GB-class machines. On other systems, follow the measured accelerator budget rather than total RAM: a 16GB iGPU laptop commonly belongs in `4gb` or `6gb`.
2. Use the local Qwen baseline as the default for privacy-sensitive or repeated work.
3. Add OpenCode Go and/or OpenRouter when you need hosted capacity or lower local load.
4. Use the office-oriented skills for docs, spreadsheets, and decks.

## Good first commands

Interactive (recommended):
```bash
./bin/lac init
```

Read the final init summary first. It tells you which checks are ready, which ones block the next command, and whether API keys or local runtime tools are missing.

Non-interactive:
```bash
./bin/lac init --yes --profile macos-16gb --cloud openrouter
./bin/lac models sync macos-16gb
./bin/lac runtime start
./bin/lac client open opencode
```

Use `16gb` or `24gb` only when the device has a true measured 16–24GB accelerator budget, or when
you have deliberately chosen a CPU-only system-RAM configuration. WSL2 and unmeasured accelerators
fall back to `4gb`; see [the Windows guide](../WINDOWS.md).

## What to avoid
- jumping straight to 122B-class profiles
- assuming free cloud availability is stable
- loading too many models locally at once on 16GB devices
- using the larger `16gb` Qwen 27B profile on MacBook Air-class hardware when you need OS and context headroom
