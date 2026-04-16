#!/bin/bash
# Verify that free cloud models in opencode.jsonc are still accessible.
# Usage: ./scripts/verify-free-models.sh
# Prerequisites: OPENROUTER_API_KEY and/or NVIDIA_API_KEY set in environment.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/opencode.jsonc"
TIMEOUT="${MODEL_VERIFY_TIMEOUT:-10}"
ERR=0

if [[ ! -f "$CONFIG" ]]; then
  echo "Config not found: $CONFIG" >&2
  exit 1
fi

# Extract model IDs from a provider block using python3
extract_models() {
  local provider="$1"
  python3 -c "
import json, sys
with open('$CONFIG') as f:
  text = f.read()
clean = '\n'.join(l for l in text.splitlines() if not l.strip().startswith('//'))
obj = json.loads(clean)
models = obj.get('provider', {}).get('$provider', {}).get('models', {})
for mid in models:
  print(mid)
"
}

# Check a single model via a minimal chat completion request
check_model() {
  local provider="$1"
  local model_id="$2"
  local base_url=""
  local api_key=""

  case "$provider" in
    openrouter)
      base_url="https://openrouter.ai/api/v1"
      api_key="${OPENROUTER_API_KEY:-}"
      ;;
    nvidia-nim)
      base_url="https://integrate.api.nvidia.com/v1"
      api_key="${NVIDIA_API_KEY:-}"
      ;;
    *)
      echo "  [?] $model_id — unknown provider: $provider"
      return
      ;;
  esac

  if [[ -z "$api_key" ]]; then
    if [[ "$provider" == "openrouter" ]]; then
      echo "  [?] $model_id — no API key set (set OPENROUTER_API_KEY)"
    elif [[ "$provider" == "nvidia-nim" ]]; then
      echo "  [?] $model_id — no API key set (set NVIDIA_API_KEY)"
    else
      echo "  [?] $model_id — no API key set"
    fi
    return
  fi

  local http_code
  http_code="$(curl -sf -o /dev/null -w "%{http_code}" \
    --max-time "$TIMEOUT" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "'"$model_id"'",
      "messages": [{"role":"user","content":"hi"}],
      "max_tokens": 4
    }' \
    "$base_url/chat/completions" 2>/dev/null || echo "000")"

  case "$http_code" in
    200|201)
      echo "  [ok] $model_id"
      ;;
    404)
      echo "  [!!] $model_id — REMOVED (404)"
      ERR=1
      ;;
    429)
      echo "  [--] $model_id — rate-limited (429)"
      ;;
    401|403)
      echo "  [!!] $model_id — auth error ($http_code)"
      ERR=1
      ;;
    000)
      echo "  [??] $model_id — connection timeout"
      ;;
    *)
      echo "  [??] $model_id — unexpected status $http_code"
      ;;
  esac
}

echo "=== Free Model Verification ==="
echo "Timeout per model: ${TIMEOUT}s"
echo ""

# --- OpenRouter free tier ---
echo "[openrouter] Free models:"
or_models="$(extract_models openrouter)"
if [[ -z "$or_models" ]]; then
  echo "  [warn] No models found in openrouter provider block"
else
  while IFS= read -r model; do
    check_model openrouter "$model"
  done <<< "$or_models"
fi
echo ""

# --- NVIDIA NIM ---
echo "[nvidia-nim] Free/trial models:"
nim_models="$(extract_models nvidia-nim)"
if [[ -z "$nim_models" ]]; then
  echo "  [warn] No models found in nvidia-nim provider block"
else
  while IFS= read -r model; do
    check_model nvidia-nim "$model"
  done <<< "$nim_models"
fi
echo ""

# --- Summary ---
if [[ "$ERR" -ne 0 ]]; then
  echo "=== Verification complete — some models are broken ==="
  echo "Update opencode.jsonc and docs/providers/OPENROUTER_FREE.md"
  echo "to remove removed models."
  exit 1
else
  echo "=== Verification complete — no broken models ==="
fi
