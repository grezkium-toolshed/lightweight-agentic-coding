# Onboarding Scenario: 16GB or 24GB Local-First with Cloud Fallback

## Best fit
- developers and operators on mainstream laptops
- startup users who need a practical local baseline
- teams piloting agentic workflows without large local hardware

## Recommended path
1. Start with `16gb` or `24gb` profile.
2. Use the local Qwen baseline as the default for privacy-sensitive or repeated work.
3. Add NVIDIA NIM or OpenRouter when you need stronger hosted models or lower local load.
4. Use the office-oriented skills for docs, spreadsheets, and decks.

## Good first commands
```bash
./bin/lac models sync 24gb
./bin/lac profile apply 24gb
./bin/lac runtime start
./bin/lac client open opencode
```

## What to avoid
- jumping straight to 122B-class profiles
- assuming free cloud availability is stable
- loading too many models locally at once on 16GB devices
