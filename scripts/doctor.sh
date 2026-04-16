#!/bin/bash
set -euo pipefail

AI_CLUSTER_ROOT="${AI_CLUSTER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
AI_CLUSTER_PORT="${AI_CLUSTER_PORT:-8080}"
PROFILE_MANIFEST_PATH="${PROFILE_MANIFEST_PATH:-$AI_CLUSTER_ROOT/runtime-config/profiles.json}"
ACTIVE_PROFILE_PATH="${ACTIVE_PROFILE_PATH:-$AI_CLUSTER_ROOT/runtime-config/active-profile.txt}"
ACTIVE_PRESET_PATH="${ACTIVE_PRESET_PATH:-$AI_CLUSTER_ROOT/runtime-config/presets.active.ini}"
ACTIVE_OPENCODE_CONFIG_PATH="${ACTIVE_OPENCODE_CONFIG_PATH:-$AI_CLUSTER_ROOT/runtime-config/opencode.active.json}"
LOG_FILE="$AI_CLUSTER_ROOT/runtime-config/logs/llama-server.log"

STRICT=false
BOOTSTRAP_HINT=false
err=0

usage() {
  cat << USAGE
Usage: $0 [--strict] [--bootstrap-hint]

  --strict          Treat missing generated state and runtime health issues as failures.
  --bootstrap-hint  Print setup guidance when generated runtime files are missing.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict)
      STRICT=true
      shift
      ;;
    --bootstrap-hint)
      BOOTSTRAP_HINT=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

note_generated_state() {
  if $BOOTSTRAP_HINT; then
    echo "  hint: run ./scripts/setup-config-device.sh --profile <profile> to regenerate runtime-config state"
  fi
}

check_file() {
  local f="$1"
  local generated="${2:-false}"
  if [[ -f "$f" ]]; then
    echo "[ok] $f"
    return
  fi

  if [[ "$generated" == "true" ]]; then
    echo "[warn] missing generated file: $f"
    note_generated_state
    if $STRICT; then
      err=1
    fi
    return
  fi

  echo "[!!] missing: $f"
  err=1
}

read_manifest_field() {
  local profile="$1"
  local field="$2"
  python3 - << PY
import json
from pathlib import Path

manifest = json.loads(Path(r"$PROFILE_MANIFEST_PATH").read_text(encoding="utf-8"))
profile = manifest["profiles"].get(r"$profile", {})
print(profile.get(r"$field", ""))
PY
}

check_file "$AI_CLUSTER_ROOT/opencode.jsonc"
check_file "$PROFILE_MANIFEST_PATH"
check_file "$ACTIVE_PRESET_PATH" true
check_file "$ACTIVE_PROFILE_PATH" true
check_file "$ACTIVE_OPENCODE_CONFIG_PATH" true
check_file "$AI_CLUSTER_ROOT/.opencode/agents/architecture-reviewer.md"
check_file "$AI_CLUSTER_ROOT/.opencode/skills/docx-workflow/SKILL.md"

profile=""
runtime_mode="local"
if [[ -f "$ACTIVE_PROFILE_PATH" ]]; then
  profile="$(tr -d '\r\n' < "$ACTIVE_PROFILE_PATH")"
  echo "[ok] active profile: $profile"
  if [[ -f "$PROFILE_MANIFEST_PATH" ]]; then
    runtime_mode="$(read_manifest_field "$profile" runtime_mode)"
    if [[ -z "$runtime_mode" ]]; then
      runtime_mode="local"
    fi
  fi
else
  echo "[warn] active profile is not configured yet"
fi

if [[ -n "$profile" ]]; then
  case "$profile" in
    128gb-multi|128gb-qwen122b|128gb-minimax)
      echo "[ok] 128GB profile selected; keep effective usage <=115GB headroom policy"
      ;;
  esac
fi

if command -v opencode >/dev/null 2>&1; then
  echo "[ok] opencode in PATH"
else
  echo "[!!] opencode not found in PATH"
  err=1
fi

if [[ "$runtime_mode" == "cloud" ]]; then
  echo "[ok] active profile does not require local llama-server"
else
  if command -v llama-server >/dev/null 2>&1; then
    echo "[ok] llama-server in PATH"
  else
    echo "[!!] llama-server not found in PATH"
    err=1
  fi

  if curl -sf "http://127.0.0.1:$AI_CLUSTER_PORT/health" >/dev/null 2>&1; then
    echo "[ok] server health endpoint reachable"
  else
    echo "[warn] server is not reachable at http://127.0.0.1:$AI_CLUSTER_PORT/health"
    if $STRICT; then
      err=1
    fi
  fi

  if [[ -f "$LOG_FILE" ]]; then
    echo "[ok] launch log file: $LOG_FILE"
  else
    echo "[warn] launch log file missing: $LOG_FILE"
    if $STRICT; then
      err=1
    fi
  fi
fi

if [[ "$err" -ne 0 ]]; then
  exit 1
fi
