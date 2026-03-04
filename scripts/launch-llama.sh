#!/bin/bash
set -euo pipefail

AI_CLUSTER_ROOT="${AI_CLUSTER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LLAMA_SERVER_BIN="${LLAMA_SERVER_BIN:-llama-server}"
AI_CLUSTER_PORT="${AI_CLUSTER_PORT:-8080}"
PRESET_FILE="${PRESET_FILE:-$AI_CLUSTER_ROOT/runtime-config/presets.active.ini}"

if [[ ! -f "$PRESET_FILE" ]]; then
  echo "Missing presets file: $PRESET_FILE" >&2
  echo "Run scripts/setup-config-device.sh first." >&2
  exit 1
fi

if pgrep -f "llama-server.*port $AI_CLUSTER_PORT" >/dev/null 2>&1; then
  echo "llama-server already running on port $AI_CLUSTER_PORT"
  exit 0
fi

screen -dmS ai-cluster "$LLAMA_SERVER_BIN" --models-preset "$PRESET_FILE" --port "$AI_CLUSTER_PORT" --host 127.0.0.1

for _ in $(seq 1 60); do
  if curl -sf "http://127.0.0.1:$AI_CLUSTER_PORT/health" >/dev/null 2>&1; then
    echo "llama-server ready at http://127.0.0.1:$AI_CLUSTER_PORT"
    exit 0
  fi
  sleep 1
done

echo "llama-server failed to start. Check logs: screen -r ai-cluster" >&2
exit 1
