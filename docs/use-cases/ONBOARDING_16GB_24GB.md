# Onboarding Scenario: 16GB or 24GB Local-First with Cloud Fallback

## Best fit
- developers and operators on mainstream laptops
- startup users who need a practical local baseline
- teams piloting agentic workflows without large local hardware

## Recommended path
1. Start with `16gb` or `24gb` profile.
2. Use local Qwen 3.5 as the default for privacy-sensitive or repeated work.
3. Add NVIDIA NIM or OpenRouter when you need stronger hosted models or lower local load.
4. Use the office-oriented skills for docs, spreadsheets, and decks.

## Good first commands
```bash
./scripts/setup-models-device.sh --profile 24gb
./scripts/setup-config-device.sh --profile 24gb
./scripts/launch-llama.sh
./scripts/launch-opencode.sh
```

## What to avoid
- jumping straight to 122B-class profiles
- assuming free cloud availability is stable
- loading too many models locally at once on 16GB devices
