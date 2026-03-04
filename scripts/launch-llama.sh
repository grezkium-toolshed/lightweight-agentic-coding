#!/bin/bash
set -euo pipefail

AI_CLUSTER_ROOT="${AI_CLUSTER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LLAMA_SERVER_BIN="${LLAMA_SERVER_BIN:-llama-server}"
AI_CLUSTER_PORT="${AI_CLUSTER_PORT:-8080}"
PRESET_FILE="${PRESET_FILE:-$AI_CLUSTER_ROOT/runtime-config/presets.active.ini}"
LOG_DIR="$AI_CLUSTER_ROOT/runtime-config/logs"
LOG_FILE="$LOG_DIR/llama-server.log"
SHOW_LOGS=false
TAIL_HINT=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --show-logs)
      SHOW_LOGS=true
      shift
      ;;
    --no-tail-hint)
      TAIL_HINT=false
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--show-logs] [--no-tail-hint]" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$PRESET_FILE" ]]; then
  echo "Missing presets file: $PRESET_FILE" >&2
  echo "Run scripts/setup-config-device.sh first." >&2
  exit 1
fi

mkdir -p "$LOG_DIR"
if [[ -f "$LOG_FILE" ]]; then
  mv -f "$LOG_FILE" "${LOG_FILE}.1"
fi

if pgrep -f "llama-server.*port $AI_CLUSTER_PORT" >/dev/null 2>&1; then
  echo "llama-server already running on port $AI_CLUSTER_PORT"
  echo "Log file: $LOG_FILE"
  if $TAIL_HINT; then
    echo "Tail logs: tail -f $LOG_FILE"
  fi
  exit 0
fi

screen -dmS ai-cluster bash -lc "\"$LLAMA_SERVER_BIN\" --models-preset \"$PRESET_FILE\" --port \"$AI_CLUSTER_PORT\" --host 127.0.0.1 >> \"$LOG_FILE\" 2>&1"

for _ in $(seq 1 60); do
  if curl -sf "http://127.0.0.1:$AI_CLUSTER_PORT/health" >/dev/null 2>&1; then
    echo "llama-server ready at http://127.0.0.1:$AI_CLUSTER_PORT"
    echo "Log file: $LOG_FILE"
    if $TAIL_HINT; then
      echo "Tail logs: tail -f $LOG_FILE"
      echo "Attach session: screen -r ai-cluster"
    fi
    if $SHOW_LOGS; then
      tail -f "$LOG_FILE"
    fi
    exit 0
  fi
  sleep 1
done

echo "llama-server failed to start. Recent logs:" >&2
if [[ -f "$LOG_FILE" ]]; then
  tail -n 40 "$LOG_FILE" >&2 || true
  echo "Full log: $LOG_FILE" >&2
fi
echo "Screen session: screen -r ai-cluster" >&2
exit 1
