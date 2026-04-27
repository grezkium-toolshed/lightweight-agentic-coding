#!/bin/bash
set -euo pipefail

# Integration test for Local AI Cluster
# Validates the full CLI workflow without starting llama-server.
# This can run in CI without GPU.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export AI_CLUSTER_STATE_ROOT="$TMP_DIR/state"
FAILED=0

run() {
  echo "[test] $*"
  if ! "$@"; then
    echo "[FAIL] $*"
    FAILED=1
  fi
}

echo "=== Integration Test ==="
echo "Temp dir: $TMP_DIR"

# 1. Profile apply generates config
run python3 "$ROOT/scripts/lac.py" profile apply 24gb --json > "$TMP_DIR/profile-24gb.json"

# 2. Generated OpenCode config exists and is valid JSON
if [[ -f "$TMP_DIR/state/clients/opencode/opencode.json" ]]; then
  echo "[ok] opencode.json generated"
  python3 -c "import json; json.load(open('$TMP_DIR/state/clients/opencode/opencode.json'))"
else
  echo "[FAIL] opencode.json not generated"
  FAILED=1
fi

# 3. Doctor runs without error
run python3 "$ROOT/scripts/lac.py" doctor --bootstrap-hint --json > "$TMP_DIR/doctor.json"

# 4. Client render works for all supported clients
for client in opencode claude-code codex-reference; do
  run python3 "$ROOT/scripts/lac.py" client render "$client" --json > "$TMP_DIR/render-$client.json"
done

# 5. Provider list works
run python3 "$ROOT/scripts/lac.py" provider list --json > "$TMP_DIR/providers.json"

# 6. Pack and scenario lists work
run python3 "$ROOT/scripts/lac.py" pack list --json > "$TMP_DIR/packs.json"
run python3 "$ROOT/scripts/lac.py" scenario list --json > "$TMP_DIR/scenarios.json"

# 7. Init wizard works with --yes
INIT_STATE="$TMP_DIR/init-state"
AI_CLUSTER_STATE_ROOT="$INIT_STATE" run python3 "$ROOT/scripts/lac.py" init --yes --profile 24gb --no-cloud --json > "$TMP_DIR/init.json"

# 8. Validate generated preset
if [[ -f "$INIT_STATE/runtime/presets.active.ini" ]]; then
  echo "[ok] presets.active.ini generated"
else
  echo "[FAIL] presets.active.ini not generated"
  FAILED=1
fi

if [[ "$FAILED" -eq 0 ]]; then
  echo "=== All integration tests passed ==="
  exit 0
else
  echo "=== Some integration tests failed ==="
  exit 1
fi
