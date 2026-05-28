# Onboarding Scenario: 32GB+ Local-Heavy Workflow

## Best fit
- home-lab users
- engineers with stronger local hardware
- teams that want local-first coding, documentation, and research workflows

## Recommended path
1. Start with `./bin/lac init`; let it recommend `32gb`, `64gb`, or a larger profile from detected RAM.
2. Use Qwen 3.6 MoE as the main general model.
3. Use Qwen 3.6 MTP (27B Q4 or 35B-A3B Q6) as the fast coding and architect model.
4. Add hosted-model fallbacks only when there is a clear quality or speed benefit.
5. (Optional) Install OpenChamber for phone/tablet access:
   ```bash
   lac client open openchamber
   ```

## Good first commands

Interactive:
```bash
./bin/lac init
```

Use the final init summary as the source of truth for the next command. It reports generated config paths, blocked prerequisites, optional helpers, and whether local model downloads are still needed.

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
