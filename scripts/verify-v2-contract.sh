#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

STATE_ROOT="$TMP_DIR/state"
export LAC_STATE_ROOT="$STATE_ROOT"
export AI_LOCAL_RUNTIME="llama.cpp"

python3 "$ROOT/scripts/lac.py" profile apply 24gb --json > "$TMP_DIR/profile-24gb.json"
cp "$STATE_ROOT/clients/opencode/opencode.json" "$TMP_DIR/opencode-24gb.json"
python3 "$ROOT/scripts/lac.py" profile apply macos-16gb --json > "$TMP_DIR/profile-macos-16gb.json"
cp "$STATE_ROOT/clients/opencode/opencode.json" "$TMP_DIR/opencode-macos-16gb.json"
OMLX_CHECK=0
if [[ "$(uname -s)" == "Darwin" ]]; then
  OMLX_CHECK=1
  OMLX_STATE_ROOT="$TMP_DIR/omlx-state"
  LAC_STATE_ROOT="$OMLX_STATE_ROOT" AI_LOCAL_RUNTIME=omlx python3 "$ROOT/scripts/lac.py" profile apply 24gb --json > "$TMP_DIR/profile-24gb-omlx.json"
  cp "$OMLX_STATE_ROOT/clients/opencode/opencode.json" "$TMP_DIR/opencode-24gb-omlx.json"
  OMLX_MACOS_16GB_STATE_ROOT="$TMP_DIR/omlx-macos-16gb-state"
  LAC_STATE_ROOT="$OMLX_MACOS_16GB_STATE_ROOT" AI_LOCAL_RUNTIME=omlx python3 "$ROOT/scripts/lac.py" profile apply macos-16gb --json > "$TMP_DIR/profile-macos-16gb-omlx.json"
  cp "$OMLX_MACOS_16GB_STATE_ROOT/clients/opencode/opencode.json" "$TMP_DIR/opencode-macos-16gb-omlx.json"
fi
python3 "$ROOT/scripts/lac.py" client render opencode --json > "$TMP_DIR/render-opencode.json"
python3 "$ROOT/scripts/lac.py" client render claude-code --json > "$TMP_DIR/render-claude.json"
python3 "$ROOT/scripts/lac.py" client render codex-reference --json > "$TMP_DIR/render-codex.json"
python3 "$ROOT/scripts/lac.py" doctor --bootstrap-hint --json > "$TMP_DIR/doctor-24gb.json"
python3 "$ROOT/scripts/lac.py" --json provider list > "$TMP_DIR/provider-list-top.json"
python3 "$ROOT/scripts/lac.py" provider list --json > "$TMP_DIR/provider-list-sub.json"
python3 "$ROOT/scripts/lac.py" provider models openrouter --json > "$TMP_DIR/provider-models-openrouter.json"
python3 "$ROOT/scripts/lac.py" provider status --json > "$TMP_DIR/provider-status-24gb.json"

python3 "$ROOT/scripts/lac.py" profile apply openrouter --json > "$TMP_DIR/profile-openrouter.json"
python3 "$ROOT/scripts/lac.py" doctor --bootstrap-hint --json > "$TMP_DIR/doctor-openrouter.json"
python3 "$ROOT/scripts/lac.py" provider list --json > "$TMP_DIR/provider-list-openrouter.json"
python3 "$ROOT/scripts/lac.py" provider status --json > "$TMP_DIR/provider-status-openrouter.json"
python3 "$ROOT/scripts/lac.py" smoke --json > "$TMP_DIR/smoke-openrouter.json"

python3 "$ROOT/scripts/lac.py" pack list --json > "$TMP_DIR/pack-list.json"
python3 "$ROOT/scripts/lac.py" pack show coding --json > "$TMP_DIR/pack-coding.json"
python3 "$ROOT/scripts/lac.py" scenario list --json > "$TMP_DIR/scenario-list.json"
python3 "$ROOT/scripts/lac.py" provider list --json > "$TMP_DIR/provider-list.json"
python3 "$ROOT/scripts/lac.py" provider status --json > "$TMP_DIR/provider-status.json"

INIT_STATE_1="$TMP_DIR/init-no-cloud-state"
LAC_STATE_ROOT="$INIT_STATE_1" python3 "$ROOT/scripts/lac.py" init --yes --profile 24gb --no-cloud --json > "$TMP_DIR/init-no-cloud.json"
INIT_STATE_2="$TMP_DIR/init-cloud-state"
LAC_STATE_ROOT="$INIT_STATE_2" python3 "$ROOT/scripts/lac.py" init --yes --profile 24gb --cloud openrouter,anthropic --json > "$TMP_DIR/init-cloud.json"
INIT_STATE_3="$TMP_DIR/init-default-cloud-state"
LAC_STATE_ROOT="$INIT_STATE_3" python3 "$ROOT/scripts/lac.py" init --yes --profile 24gb --json > "$TMP_DIR/init-default-cloud.json"

unset OPENROUTER_API_KEY ANTHROPIC_API_KEY OPENCODE_GO_API_KEY OPENCODE_ZEN_API_KEY OPENAI_API_KEY ANTIGRAVITY_API_KEY ZAI_API_KEY NVIDIA_API_KEY NVIDIA_NIM_API_KEY 2>/dev/null || true
python3 "$ROOT/scripts/lac.py" provider verify openrouter --json > "$TMP_DIR/verify-openrouter.json"
set +e
python3 "$ROOT/scripts/lac.py" provider verify --all --json > "$TMP_DIR/verify-all.json"
VERIFY_ALL_EXIT=$?
set -e
set +e
python3 "$ROOT/scripts/lac.py" provider verify bogus-id > "$TMP_DIR/verify-bogus.out" 2>&1
VERIFY_BOGUS_EXIT=$?
set -e

python3 - <<'PY' "$ROOT" "$STATE_ROOT" "$TMP_DIR" "$VERIFY_ALL_EXIT" "$VERIFY_BOGUS_EXIT" "$OMLX_CHECK"
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
state_root = Path(sys.argv[2])
tmp_dir = Path(sys.argv[3])
verify_all_exit = int(sys.argv[4])
verify_bogus_exit = int(sys.argv[5])
omlx_check = sys.argv[6] == "1"

profile_24 = json.loads((tmp_dir / "profile-24gb.json").read_text(encoding="utf-8"))
profile_macos_16gb = json.loads((tmp_dir / "profile-macos-16gb.json").read_text(encoding="utf-8"))
doctor_24 = json.loads((tmp_dir / "doctor-24gb.json").read_text(encoding="utf-8"))
doctor_openrouter = json.loads((tmp_dir / "doctor-openrouter.json").read_text(encoding="utf-8"))
smoke_openrouter = json.loads((tmp_dir / "smoke-openrouter.json").read_text(encoding="utf-8"))
opencode_config = json.loads((tmp_dir / "opencode-24gb.json").read_text(encoding="utf-8"))
opencode_config_macos_16gb = json.loads((tmp_dir / "opencode-macos-16gb.json").read_text(encoding="utf-8"))
opencode_manifest = json.loads((root / ".opencode/render-manifest.json").read_text(encoding="utf-8"))
provider_list_top = json.loads((tmp_dir / "provider-list-top.json").read_text(encoding="utf-8"))
provider_list_sub = json.loads((tmp_dir / "provider-list-sub.json").read_text(encoding="utf-8"))
provider_models_openrouter = json.loads((tmp_dir / "provider-models-openrouter.json").read_text(encoding="utf-8"))
provider_list_24 = provider_list_top
provider_list_openrouter = json.loads((tmp_dir / "provider-list-openrouter.json").read_text(encoding="utf-8"))

assert profile_24["profile_id"] == "24gb"
assert opencode_config["model"] == "local-cluster/qwen3.6-27b-q4"
assert opencode_config["provider"]["local-cluster"]["options"]["baseURL"] == "http://127.0.0.1:8080/v1"
assert profile_macos_16gb["profile_id"] == "macos-16gb"
assert opencode_config_macos_16gb["model"] == "local-cluster/gemma-4-12b-q4"
assert opencode_config_macos_16gb["small_model"] == "local-cluster/gemma-4-e4b-q8"
assert opencode_config_macos_16gb["provider"]["local-cluster"]["models"]["qwen3.5-9b-q4"]["limit"]["context"] == 262144
if omlx_check:
    profile_24_omlx = json.loads((tmp_dir / "profile-24gb-omlx.json").read_text(encoding="utf-8"))
    opencode_config_omlx = json.loads((tmp_dir / "opencode-24gb-omlx.json").read_text(encoding="utf-8"))
    assert profile_24_omlx["profile_id"] == "24gb"
    assert opencode_config_omlx["model"] == "local-cluster/Qwen3.6-27B-UD-MLX-6bit"
    assert opencode_config_omlx["provider"]["local-cluster"]["options"]["baseURL"] == "http://127.0.0.1:8000/v1"
    profile_macos_16gb_omlx = json.loads((tmp_dir / "profile-macos-16gb-omlx.json").read_text(encoding="utf-8"))
    opencode_config_macos_16gb_omlx = json.loads((tmp_dir / "opencode-macos-16gb-omlx.json").read_text(encoding="utf-8"))
    assert profile_macos_16gb_omlx["profile_id"] == "macos-16gb"
    assert opencode_config_macos_16gb_omlx["provider"]["local-cluster"]["options"]["baseURL"] == "http://127.0.0.1:8080/v1"
    assert opencode_config_macos_16gb_omlx["model"] == "local-cluster/gemma-4-12b-q4"
    assert opencode_config_macos_16gb_omlx["small_model"] == "local-cluster/gemma-4-e4b-q8"
assert opencode_manifest["target"] == "opencode"
assert doctor_24["assets"]["pack_count"] >= 4
assert provider_list_top == provider_list_sub
assert isinstance(provider_models_openrouter, list) and provider_models_openrouter, "provider models openrouter must be non-empty"
assert all(model["id"].startswith("openrouter/") for model in provider_models_openrouter)
assert any(provider["id"] == "local-cluster" and provider["configured"] is True for provider in provider_list_24)
assert any(provider["id"] == "local-cluster" and provider["configured"] is True for provider in doctor_24["provider_readiness"])
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
assert init_no_cloud["status"] in ("ready", "blocked")
assert init_no_cloud["recommendation"]["selected_profile"] == "24gb"
assert init_no_cloud["recommendation"]["default_cloud_overlays"] == ["opencode-go", "openrouter"]
assert init_no_cloud["generated"]["opencode_config"].endswith("clients/opencode/opencode.json")
assert "required" in init_no_cloud["prerequisites"] and "optional" in init_no_cloud["prerequisites"]
assert any(item["id"] == "python" and item["status"] == "ready" for item in init_no_cloud["prerequisites"]["required"])
assert any(item["status"] in ("ready", "blocked") for item in init_no_cloud["readiness"])
assert (tmp_dir / "init-no-cloud-state" / "clients/opencode/opencode.json").is_file()

init_cloud = json.loads((tmp_dir / "init-cloud.json").read_text(encoding="utf-8"))
assert init_cloud["applied"] is True
assert init_cloud["cloud"] == ["openrouter", "anthropic"]
assert init_cloud["status"] in ("ready", "blocked")
assert any("OPENROUTER_API_KEY" in step for step in init_cloud["next_steps"])
assert any("ANTHROPIC_API_KEY" in step for step in init_cloud["next_steps"])
assert any(item["id"] == "openrouter-api-key" for item in init_cloud["prerequisites"]["required"])
openrouter_key_check = next(item for item in init_cloud["prerequisites"]["required"] if item["id"] == "openrouter-api-key")
assert "install_hint" in openrouter_key_check
assert any("OPENROUTER_API_KEY" in command for command in openrouter_key_check["install_hint"]["commands"])

init_default_cloud = json.loads((tmp_dir / "init-default-cloud.json").read_text(encoding="utf-8"))
assert init_default_cloud["applied"] is True
assert init_default_cloud["cloud"] == ["opencode-go", "openrouter"]
assert init_default_cloud["status"] in ("ready", "blocked")
assert any("OPENCODE_GO_API_KEY" in step for step in init_default_cloud["next_steps"])
assert any("OPENROUTER_API_KEY" in step for step in init_default_cloud["next_steps"])
assert any(item["id"] == "opencode-go-api-key" for item in init_default_cloud["prerequisites"]["required"])

assert any(provider["id"] == "local-cluster" and provider["configured"] is False for provider in provider_list_openrouter)
assert any(provider["id"] == "local-cluster" and provider["configured"] is False for provider in doctor_openrouter["provider_readiness"])
provider_status_openrouter = json.loads((tmp_dir / "provider-status-openrouter.json").read_text(encoding="utf-8"))
assert provider_status_openrouter["configured_count"] + provider_status_openrouter["unconfigured_count"] == len(provider_list_openrouter)

expected_paths = [
    state_root / "active/profile.txt",
    state_root / "runtime/presets.active.ini",
    state_root / "clients/opencode/opencode.json",
    state_root / "reports/doctor.json",
    state_root / "reports/smoke.json",
]

for path in expected_paths:
    assert path.is_file(), f"missing generated file: {path}"

verify_openrouter = json.loads((tmp_dir / "verify-openrouter.json").read_text(encoding="utf-8"))
assert verify_openrouter["id"] == "openrouter"
assert verify_openrouter["status"] == "skipped"
assert verify_openrouter["configured"] is False
assert verify_openrouter["endpoint"].startswith("https://openrouter.ai/")

verify_all = json.loads((tmp_dir / "verify-all.json").read_text(encoding="utf-8"))
assert "results" in verify_all and "summary" in verify_all
assert len(verify_all["results"]) == len(provider_list)
for record in verify_all["results"]:
    assert set(record.keys()) >= {"id", "status", "configured", "endpoint", "verified_at"}
    assert record["status"] in ("ok", "skipped", "error")
# local-cluster may fail if llama-server isn't running; every cloud provider
# without a key must skip, so there should be at least (total - 1) skips.
assert verify_all["summary"]["skipped"] >= len(verify_all["results"]) - 1

assert verify_bogus_exit != 0, "verify bogus-id must exit non-zero"

print("[ok] v2 CLI contract checks")
PY
