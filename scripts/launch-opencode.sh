#!/bin/bash
set -euo pipefail

AI_CLUSTER_ROOT="${AI_CLUSTER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OPENCODE_CONFIG_PATH="${OPENCODE_CONFIG_PATH:-$AI_CLUSTER_ROOT/runtime-config/opencode.active.json}"

if [[ ! -f "$OPENCODE_CONFIG_PATH" ]]; then
  echo "Missing generated OpenCode config: $OPENCODE_CONFIG_PATH" >&2
  echo "Run scripts/setup-config-device.sh --profile <profile> first." >&2
  exit 1
fi

export OPENCODE_CONFIG="$OPENCODE_CONFIG_PATH"
opencode
