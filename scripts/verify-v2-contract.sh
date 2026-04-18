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

python3 "$ROOT/scripts/lac.py" pack list --json > "$TMP_DIR/pack-list.json"
python3 "$ROOT/scripts/lac.py" pack show coding --json > "$TMP_DIR/pack-coding.json"
python3 "$ROOT/scripts/lac.py" scenario list --json > "$TMP_DIR/scenario-list.json"
python3 "$ROOT/scripts/lac.py" provider list --json > "$TMP_DIR/provider-list.json"
python3 "$ROOT/scripts/lac.py" provider status --json > "$TMP_DIR/provider-status.json"

INIT_STATE_1="$TMP_DIR/init-no-cloud-state"
AI_CLUSTER_STATE_ROOT="$INIT_STATE_1" python3 "$ROOT/scripts/lac.py" init --yes --profile 24gb --no-cloud --json > "$TMP_DIR/init-no-cloud.json"
INIT_STATE_2="$TMP_DIR/init-cloud-state"
AI_CLUSTER_STATE_ROOT="$INIT_STATE_2" python3 "$ROOT/scripts/lac.py" init --yes --profile 24gb --cloud openrouter,anthropic --json > "$TMP_DIR/init-cloud.json"

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

pack_list = json.loads((tmp_dir / "pack-list.json").read_text(encoding="utf-8"))
assert isinstance(pack_list, list) and pack_list, "pack list must be non-empty"
pack_ids = {pack["id"] for pack in pack_list}
assert {"coding", "research", "office", "team-rollout"}.issubset(pack_ids)
assert all(pack["asset_count"] >= 1 for pack in pack_list)

pack_coding = json.loads((tmp_dir / "pack-coding.json").read_text(encoding="utf-8"))
assert pack_coding["id"] == "coding"
asset_ids = {asset["id"] for asset in pack_coding["assets"]}
assert "agent:architecture-reviewer" in asset_ids

scenario_list = json.loads((tmp_dir / "scenario-list.json").read_text(encoding="utf-8"))
scenario_ids = {scenario["id"] for scenario in scenario_list}
assert {"solo-coder", "research-operator", "office-automation", "team-pilot"}.issubset(scenario_ids)

provider_list = json.loads((tmp_dir / "provider-list.json").read_text(encoding="utf-8"))
provider_ids = {provider["id"] for provider in provider_list}
assert {"local-cluster", "openrouter"}.issubset(provider_ids)
for provider in provider_list:
    assert "env_var" in provider and "risk_level" in provider and "last_verified_at" in provider

provider_status_payload = json.loads((tmp_dir / "provider-status.json").read_text(encoding="utf-8"))
assert provider_status_payload["configured_count"] + provider_status_payload["unconfigured_count"] == len(provider_list)

for required_provider in ("opencode-zen", "opencode-go", "codex-auth", "anthropic"):
    assert required_provider in provider_ids, f"providers.json missing '{required_provider}'"

init_no_cloud = json.loads((tmp_dir / "init-no-cloud.json").read_text(encoding="utf-8"))
assert init_no_cloud["applied"] is True
assert init_no_cloud["profile"] == "24gb"
assert init_no_cloud["cloud"] == []
assert (tmp_dir / "init-no-cloud-state" / "clients/opencode/opencode.json").is_file()

init_cloud = json.loads((tmp_dir / "init-cloud.json").read_text(encoding="utf-8"))
assert init_cloud["applied"] is True
assert init_cloud["cloud"] == ["openrouter", "anthropic"]
assert any("OPENROUTER_API_KEY" in step for step in init_cloud["next_steps"])
assert any("ANTHROPIC_API_KEY" in step for step in init_cloud["next_steps"])

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
