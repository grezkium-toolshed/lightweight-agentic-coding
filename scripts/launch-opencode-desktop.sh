#!/bin/bash
set -euo pipefail

AI_CLUSTER_ROOT="${AI_CLUSTER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OPENCODE_CONFIG_PATH="${OPENCODE_CONFIG_PATH:-$AI_CLUSTER_ROOT/runtime-config/opencode.active.json}"
OPENCODE_DESKTOP_APP="${OPENCODE_DESKTOP_APP:-OpenCode}"

if [[ ! -f "$OPENCODE_CONFIG_PATH" ]]; then
  echo "Missing generated OpenCode config: $OPENCODE_CONFIG_PATH" >&2
  echo "Run scripts/setup-config-device.sh --profile <profile> first." >&2
  exit 1
fi

export OPENCODE_CONFIG="$OPENCODE_CONFIG_PATH"

if command -v open >/dev/null 2>&1; then
  open -a "$OPENCODE_DESKTOP_APP"
  exit 0
fi

echo "Desktop auto-launch is only implemented for macOS in this script." >&2
echo "Open your OpenCode desktop app manually with OPENCODE_CONFIG=$OPENCODE_CONFIG_PATH" >&2
exit 1
