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

# 7. Optional msgraph skill lifecycle works against a temp skill root
SKILL_ROOT="$TMP_DIR/opencode-skills"
FAKE_MSGRAPH="$TMP_DIR/fixtures/msgraph"
mkdir -p "$FAKE_MSGRAPH/scripts"
cat > "$FAKE_MSGRAPH/SKILL.md" <<'EOF'
---
name: msgraph
description: Fake Microsoft Graph skill fixture
---
EOF
cat > "$FAKE_MSGRAPH/scripts/run.sh" <<'EOF'
#!/bin/sh
if [ "$1" = "--help" ]; then
  echo "auth graph-call openapi-search"
  exit 0
fi
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then
  echo '{"status":"not-signed-in"}'
  exit 0
fi
echo "unexpected command: $*" >&2
exit 1
EOF
chmod +x "$FAKE_MSGRAPH/scripts/run.sh"
echo "[test] skill status msgraph"
if ! env AI_CLUSTER_OPENCODE_SKILLS_DIR="$SKILL_ROOT" python3 "$ROOT/scripts/lac.py" skill status msgraph --json > "$TMP_DIR/skill-status-before.json"; then
  echo "[FAIL] skill status msgraph"
  FAILED=1
fi
python3 -c "import json; data=json.load(open('$TMP_DIR/skill-status-before.json')); assert data['installed'] is False"
echo "[test] skill install msgraph"
if ! env AI_CLUSTER_OPENCODE_SKILLS_DIR="$SKILL_ROOT" python3 "$ROOT/scripts/lac.py" skill install msgraph --source "$FAKE_MSGRAPH" --json > "$TMP_DIR/skill-install.json"; then
  echo "[FAIL] skill install msgraph"
  FAILED=1
fi
test -f "$SKILL_ROOT/msgraph/SKILL.md" || { echo "[FAIL] msgraph SKILL.md was not installed"; FAILED=1; }
echo "[test] skill verify msgraph"
if ! env AI_CLUSTER_OPENCODE_SKILLS_DIR="$SKILL_ROOT" python3 "$ROOT/scripts/lac.py" skill verify msgraph --json > "$TMP_DIR/skill-verify.json"; then
  echo "[FAIL] skill verify msgraph"
  FAILED=1
fi
python3 -c "import json; data=json.load(open('$TMP_DIR/skill-verify.json')); assert data['ok'] is True; assert 'MSGRAPH_CLIENT_SECRET' not in json.dumps(data)"
echo "[test] client render opencode with msgraph"
if ! env AI_CLUSTER_OPENCODE_SKILLS_DIR="$SKILL_ROOT" python3 "$ROOT/scripts/lac.py" client render opencode --json > "$TMP_DIR/render-opencode-msgraph.json"; then
  echo "[FAIL] client render opencode with msgraph"
  FAILED=1
fi
python3 -c "import json; data=json.load(open('$TMP_DIR/render-opencode-msgraph.json')); graph=[p for p in data['packs'] if p['id']=='microsoft-graph'][0]; assert graph['installed'] is True"
echo "[test] skill remove msgraph"
if ! env AI_CLUSTER_OPENCODE_SKILLS_DIR="$SKILL_ROOT" python3 "$ROOT/scripts/lac.py" skill remove msgraph --json > "$TMP_DIR/skill-remove.json"; then
  echo "[FAIL] skill remove msgraph"
  FAILED=1
fi
test ! -e "$SKILL_ROOT/msgraph" || { echo "[FAIL] msgraph skill directory was not removed"; FAILED=1; }

# 8. Init wizard works with --yes
INIT_STATE="$TMP_DIR/init-state"
AI_CLUSTER_STATE_ROOT="$INIT_STATE" run python3 "$ROOT/scripts/lac.py" init --yes --profile 24gb --no-cloud --json > "$TMP_DIR/init.json"

# 9. Validate generated preset
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
