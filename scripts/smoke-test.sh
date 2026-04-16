#!/bin/bash
set -euo pipefail

AI_CLUSTER_ROOT="${AI_CLUSTER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
AI_CLUSTER_PORT="${AI_CLUSTER_PORT:-8080}"
PROFILE_MANIFEST_PATH="${PROFILE_MANIFEST_PATH:-$AI_CLUSTER_ROOT/runtime-config/profiles.json}"
ACTIVE_PROFILE_PATH="${ACTIVE_PROFILE_PATH:-$AI_CLUSTER_ROOT/runtime-config/active-profile.txt}"
BASE_URL="http://127.0.0.1:$AI_CLUSTER_PORT"
TIMEOUT="${SMOKE_TIMEOUT:-30}"

echo "=== Smoke Test ==="
echo "Server: $BASE_URL"
echo "Timeout: ${TIMEOUT}s"
echo ""

if [[ -f "$ACTIVE_PROFILE_PATH" && -f "$PROFILE_MANIFEST_PATH" ]]; then
  active_profile="$(tr -d '\r\n' < "$ACTIVE_PROFILE_PATH")"
  runtime_mode="$(python3 - << PY
import json
from pathlib import Path

manifest = json.loads(Path(r"$PROFILE_MANIFEST_PATH").read_text(encoding="utf-8"))
profile = manifest["profiles"].get(r"$active_profile", {})
print(profile.get("runtime_mode", "local"))
PY
)"
  if [[ "$runtime_mode" == "cloud" ]]; then
    echo "[skip] Active profile '$active_profile' is cloud-only; local llama-server smoke test not required."
    exit 0
  fi
fi

# 1. Check server health
echo "[1/4] Checking health endpoint..."
health_resp="$(curl -sf --max-time "$TIMEOUT" "$BASE_URL/health" 2>/dev/null || true)"
if [[ -z "$health_resp" ]]; then
  echo "[fail] Server is not reachable at $BASE_URL/health"
  echo "  Start llama-server first: ./scripts/launch-llama.sh"
  exit 1
fi
echo "[ok]  Health: $health_resp"

# 2. Check available models
echo "[2/4] Checking available models..."
models_resp="$(curl -sf --max-time "$TIMEOUT" "$BASE_URL/v1/models" 2>/dev/null || true)"
if [[ -z "$models_resp" ]]; then
  echo "[fail] /v1/models returned empty"
  exit 1
fi
model_count="$(echo "$models_resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('data',[])))" 2>/dev/null || echo "0")"
if [[ "$model_count" -eq 0 ]]; then
  echo "[fail] No models loaded"
  exit 1
fi
echo "[ok]  $model_count model(s) available"

# 3. Send a minimal chat completion request
echo "[3/4] Sending test chat completion..."
chat_resp="$(curl -sf --max-time "$TIMEOUT" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [{"role": "user", "content": "Say hello in one word."}],
    "max_tokens": 16,
    "temperature": 0.1
  }' \
  "$BASE_URL/v1/chat/completions" 2>/dev/null || true)"

if [[ -z "$chat_resp" ]]; then
  echo "[fail] No response from /v1/chat/completions"
  exit 1
fi

# Validate response structure
has_content="$(echo "$chat_resp" | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  choices = d.get('choices', [])
  if not choices:
    print('no_choices')
    sys.exit(0)
  msg = choices[0].get('message', {})
  content = msg.get('content', '')
  if content:
    print('ok')
  else:
    print('empty_content')
except Exception:
  print('parse_error')
" 2>/dev/null || echo "parse_error")"

case "$has_content" in
  ok)
    echo "[ok]  Chat completion returned content"
    ;;
  no_choices|empty_content)
    echo "[warn] Chat completion returned no/empty content (model may still be loading)"
    ;;
  parse_error)
    echo "[fail] Failed to parse chat completion response"
    echo "  Response: ${chat_resp:0:200}"
    exit 1
    ;;
esac

# 4. Report profile info if available
echo "[4/4] Checking active profile..."
if [[ -f "$ACTIVE_PROFILE_PATH" ]]; then
  profile="$(cat "$ACTIVE_PROFILE_PATH")"
  echo "[ok]  Active profile: $profile"
else
  echo "[warn] No active profile found (run setup-config-device.sh first)"
fi

echo ""
echo "=== Smoke test PASSED ==="
