# Onboarding Scenario: 32GB+ Local-Heavy Workflow

## Best fit
- home-lab users
- engineers with stronger local hardware
- teams that want local-first coding, documentation, and research workflows

## Recommended path
1. Start with `32gb` or `64gb` profile.
2. Use Qwen 3.6 MoE as the main general model.
3. Use `qwen3-coder-next` as a specialist for high-value coding work.
4. Add hosted-model fallbacks only when there is a clear quality or speed benefit.

## Good first commands

Interactive:
```bash
./bin/lac init
```

Non-interactive:
```bash
./bin/lac init --yes --profile 32gb
./bin/lac models sync 32gb
./bin/lac runtime start
```

## Good first checks
- `./bin/lac doctor`
- `curl http://127.0.0.1:8080/health`
- `curl http://127.0.0.1:8080/v1/models`
