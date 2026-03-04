#!/bin/bash
set -euo pipefail

AI_CLUSTER_ROOT="${AI_CLUSTER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OPENCODE_CONFIG_PATH="${OPENCODE_CONFIG_PATH:-$AI_CLUSTER_ROOT/opencode.jsonc}"

export OPENCODE_CONFIG="$OPENCODE_CONFIG_PATH"
opencode
