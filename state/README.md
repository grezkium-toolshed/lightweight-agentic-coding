# Generated State

This directory is a legacy, opt-in generated-state root for repository development.
Normal checkout and installed commands use the platform user-state directory so
their behavior does not depend on the current working directory. Run
`lac doctor --json` for the effective path.

Generated files live here so users can distinguish source inputs from rendered runtime state:

- `active/`: selected profile markers and summaries
- `runtime/`: rendered llama.cpp preset and runtime metadata
- `clients/`: rendered client configs and adapter manifests
- `logs/`: runtime logs
- `reports/`: doctor and smoke-test JSON reports

## Important notes

- This directory is ignored by git (see `.gitignore`). Do not commit files here.
- Select this directory only deliberately, for example with
  `LAC_STATE_ROOT="$PWD/state"` in a disposable development shell.
- `<state-root>/clients/opencode/opencode.json` is the rendered OpenCode config that OpenCode reads at runtime.
- Do not hand-edit files here. Regenerate them with `./bin/lac`.
