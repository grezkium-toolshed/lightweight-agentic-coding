#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
"$ROOT/scripts/setup-config-device.sh" --profile 128gb-minimax
"$ROOT/scripts/launch-llama.sh"

echo "Primary MiniMax profile launched through root vNext scripts."
