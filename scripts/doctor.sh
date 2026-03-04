#!/bin/bash
set -euo pipefail

AI_CLUSTER_ROOT="${AI_CLUSTER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
AI_MODELS_DIR="${AI_MODELS_DIR:-$AI_CLUSTER_ROOT/models}"
AI_CLUSTER_PORT="${AI_CLUSTER_PORT:-8080}"

err=0

check_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    echo "[ok] $f"
  else
    echo "[!!] missing: $f"
    err=1
  fi
}

check_file "$AI_CLUSTER_ROOT/opencode.jsonc"
check_file "$AI_CLUSTER_ROOT/runtime-config/presets.active.ini"

if command -v llama-server >/dev/null 2>&1; then
  echo "[ok] llama-server in PATH"
else
  echo "[!!] llama-server not found in PATH"
  err=1
fi

if command -v opencode >/dev/null 2>&1; then
  echo "[ok] opencode in PATH"
else
  echo "[!!] opencode not found in PATH"
  err=1
fi

if [[ -f "$AI_CLUSTER_ROOT/runtime-config/active-profile.txt" ]]; then
  profile="$(cat "$AI_CLUSTER_ROOT/runtime-config/active-profile.txt")"
  echo "[ok] active profile: $profile"
else
  profile=""
  echo "[!!] missing runtime-config/active-profile.txt"
  err=1
fi

if [[ -n "$profile" ]]; then
  case "$profile" in
    128gb-qwen122b|128gb-minimax)
      echo "[ok] 128GB profile selected; keep effective usage <=115GB headroom policy"
      ;;
  esac
fi

if curl -sf "http://127.0.0.1:$AI_CLUSTER_PORT/health" >/dev/null 2>&1; then
  echo "[ok] server health endpoint reachable"
else
  echo "[!!] server is not reachable at http://127.0.0.1:$AI_CLUSTER_PORT/health"
fi

if [[ "$err" -ne 0 ]]; then
  exit 1
fi
