# Generated State

This directory is the v2 generated-state root for lac.

Generated files live here so users can distinguish source inputs from rendered runtime state:

- `active/`: selected profile markers and summaries
- `runtime/`: rendered llama.cpp preset and runtime metadata
- `clients/`: rendered client configs and adapter manifests
- `logs/`: runtime logs
- `reports/`: doctor and smoke-test JSON reports

## Important notes

- This directory is ignored by git (see `.gitignore`). Do not commit files here.
- You can override the state root with the `LAC_STATE_ROOT` environment variable.
- `state/clients/opencode/opencode.json` is the rendered OpenCode config that OpenCode reads at runtime.
- Do not hand-edit files here. Regenerate them with `./bin/lac`.
