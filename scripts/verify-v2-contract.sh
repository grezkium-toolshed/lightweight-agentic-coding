#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

STATE_ROOT="$TMP_DIR/state"
export AI_CLUSTER_STATE_ROOT="$STATE_ROOT"

python3 "$ROOT/scripts/lac.py" profile apply 24gb --json > "$TMP_DIR/profile-24gb.json"
cp "$STATE_ROOT/clients/opencode/opencode.json" "$TMP_DIR/opencode-24gb.json"
python3 "$ROOT/scripts/lac.py" client render opencode --json > "$TMP_DIR/render-opencode.json"
python3 "$ROOT/scripts/lac.py" client render claude-code --json > "$TMP_DIR/render-claude.json"
python3 "$ROOT/scripts/lac.py" client render codex-reference --json > "$TMP_DIR/render-codex.json"
python3 "$ROOT/scripts/lac.py" doctor --bootstrap-hint --json > "$TMP_DIR/doctor-24gb.json"

python3 "$ROOT/scripts/lac.py" profile apply openrouter --json > "$TMP_DIR/profile-openrouter.json"
python3 "$ROOT/scripts/lac.py" smoke --json > "$TMP_DIR/smoke-openrouter.json"

python3 - <<'PY' "$ROOT" "$STATE_ROOT" "$TMP_DIR"
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
state_root = Path(sys.argv[2])
tmp_dir = Path(sys.argv[3])

profile_24 = json.loads((tmp_dir / "profile-24gb.json").read_text(encoding="utf-8"))
doctor_24 = json.loads((tmp_dir / "doctor-24gb.json").read_text(encoding="utf-8"))
smoke_openrouter = json.loads((tmp_dir / "smoke-openrouter.json").read_text(encoding="utf-8"))
opencode_config = json.loads((tmp_dir / "opencode-24gb.json").read_text(encoding="utf-8"))
opencode_manifest = json.loads((root / ".opencode/render-manifest.json").read_text(encoding="utf-8"))

assert profile_24["profile_id"] == "24gb"
assert opencode_config["model"] == "local-cluster/qwen3-14b-q4"
assert opencode_manifest["target"] == "opencode"
assert doctor_24["assets"]["pack_count"] >= 4
assert smoke_openrouter["skipped"] is True
assert smoke_openrouter["reason"] == "cloud-profile"

expected_paths = [
    state_root / "active/profile.txt",
    state_root / "runtime/presets.active.ini",
    state_root / "clients/opencode/opencode.json",
    state_root / "reports/doctor.json",
    state_root / "reports/smoke.json",
]

for path in expected_paths:
    assert path.is_file(), f"missing generated file: {path}"

print("[ok] v2 CLI contract checks")
PY
