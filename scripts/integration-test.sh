#!/bin/bash
set -euo pipefail

# Integration test for lac
# Validates the full CLI workflow without starting llama-server.
# This can run in the optional hosted compatibility workflow without a GPU.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAC="$ROOT/bin/lac"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export LAC_STATE_ROOT="$TMP_DIR/state"
export LAC_DATA_ROOT="$TMP_DIR/data"
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
run "$LAC" profile apply 24gb --json > "$TMP_DIR/profile-24gb.json"

# 2. Generated OpenCode config exists and is valid JSON
if [[ -f "$TMP_DIR/state/clients/opencode/opencode.json" ]]; then
  echo "[ok] opencode.json generated"
  python3 -c "import json; json.load(open('$TMP_DIR/state/clients/opencode/opencode.json'))"
else
  echo "[FAIL] opencode.json not generated"
  FAILED=1
fi
if [[ -f "$TMP_DIR/state/clients/opencode/dcp.jsonc" ]]; then
  echo "[ok] profile-aware dcp.jsonc generated"
  python3 -c "import json; json.load(open('$TMP_DIR/state/clients/opencode/dcp.jsonc'))"
else
  echo "[FAIL] dcp.jsonc not generated"
  FAILED=1
fi

# 2b. Network contract carries an explicit local override into generated clients
# and exposes/reset its persisted allocation through the CLI.
NETWORK_STATE="$TMP_DIR/network-state"
AI_LOCAL_RUNTIME=llama.cpp LAC_PORT=8181 LAC_STATE_ROOT="$NETWORK_STATE" "$LAC" profile apply 24gb --json > "$TMP_DIR/network-profile.json"
AI_LOCAL_RUNTIME=llama.cpp LAC_PORT=8181 LAC_STATE_ROOT="$NETWORK_STATE" "$LAC" ports show --json > "$TMP_DIR/ports.json"
python3 - <<'PY' "$NETWORK_STATE" "$TMP_DIR/ports.json"
import json
import sys
from pathlib import Path

state_root = Path(sys.argv[1])
ports = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
config = json.loads((state_root / "clients/opencode/opencode.json").read_text(encoding="utf-8"))
assert config["provider"]["local-cluster"]["options"]["baseURL"] == "http://127.0.0.1:8181/v1"
assert ports["contractType"] == "lac.network.v1"
assert ports["services"]["runtime"]["port"] == 8181
assert ports["services"]["runtime"]["port_source"] == "env"
PY
LAC_STATE_ROOT="$NETWORK_STATE" "$LAC" ports reset --json > "$TMP_DIR/ports-reset.json"

# 3. Doctor runs without error and reports resolved mutable paths/coexistence.
echo "[test] $LAC doctor --bootstrap-hint --json"
if ! "$LAC" doctor --bootstrap-hint --json > "$TMP_DIR/doctor.json"; then
  echo "[FAIL] doctor --json"
  FAILED=1
fi
python3 - <<'PY' "$TMP_DIR/doctor.json" "$TMP_DIR/data" "$TMP_DIR/state"
import json
import sys
from pathlib import Path

report = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert report["paths"]["data_root"] == sys.argv[2]
assert report["paths"]["state_root"] == sys.argv[3]
assert report["paths"]["models_root"] == str(Path(sys.argv[2]) / "models")
assert "checked" in report["opencode_coexistence"]
assert "warnings" in report["opencode_coexistence"]
PY
if "$LAC" doctor --fix > /dev/null 2>&1; then
  echo "[FAIL] removed doctor --fix command was accepted"
  FAILED=1
else
  echo "[ok] doctor remains read-only"
fi
if "$LAC" setup 24gb > /dev/null 2>&1; then
  echo "[FAIL] removed setup command was accepted"
  FAILED=1
else
  echo "[ok] legacy setup command is absent"
fi

# 4. Client render works for all supported clients
for client in opencode openchamber claude-code codex-reference; do
  run "$LAC" client render "$client" --json > "$TMP_DIR/render-$client.json"
done

# 5. Provider list works
run "$LAC" provider list --json > "$TMP_DIR/providers.json"

# 6. Pack and scenario lists work
run "$LAC" pack list --json > "$TMP_DIR/packs.json"
run "$LAC" scenario list --json > "$TMP_DIR/scenarios.json"

# 7. DCP stays declarative in generated config; launch wrappers remain honest.
python3 - <<'PY' "$ROOT"
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "src"))
from lac.lib.jsonc import load_jsonc
from lac.config import MIN_OPENCODE_CONTEXT

template = (root / "opencode.template.jsonc").read_text(encoding="utf-8")
template_config = load_jsonc(root / "opencode.template.jsonc")
bin_lac = (root / "bin/lac").read_text(encoding="utf-8")
bin_lac_ps1 = (root / "bin/lac.ps1").read_text(encoding="utf-8")
launch_cli_ps1 = (root / "runtime-config/launch/launch-local-cli.ps1").read_text(encoding="utf-8")
bootstrap_sh = (root / "scripts/bootstrap.sh").read_text(encoding="utf-8")
dcp_config = (root / ".opencode/dcp.jsonc").read_text(encoding="utf-8")
micro_preset = (root / "runtime-config/presets/micro.ini").read_text(encoding="utf-8")

micro_limit = template_config["provider"]["local-cluster"]["models"]["qwen3.5-4b-q4"]["limit"]

assert "@tarquinen/opencode-dcp@3.1.9" in template
assert "@dietrichgebert/ponytail@4.9.0" in template
assert template_config["share"] == "disabled"
assert template_config["autoupdate"] is False
assert template_config["permission"]["edit"] == "ask"
assert micro_limit["context"] >= MIN_OPENCODE_CONTEXT
assert f"ctx-size = {MIN_OPENCODE_CONTEXT}" in micro_preset
assert f"fit-ctx = {MIN_OPENCODE_CONTEXT}" in micro_preset
assert "n-gpu-layers = 0" not in micro_preset
assert "PYTHONPATH" in bin_lac
assert "Python 3.10+" in bin_lac
assert "-m lac" in bin_lac
assert "PYTHONPATH" in bin_lac_ps1
assert "Python 3.10+" in bin_lac_ps1
assert "-m lac" in bin_lac_ps1
assert "runtime start" in launch_cli_ps1
assert "client open opencode" in launch_cli_ps1
assert not (root / "runtime-config/launch/launch-local-desktop.ps1").exists()
assert 'PNPM_HOME="$HOME/Library/pnpm"' in bootstrap_sh
assert 'export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH"' in bootstrap_sh
assert 'OPENCODE_VERSION="1.17.18"' in bootstrap_sh
assert 'OPENCHAMBER_VERSION="1.16.3"' in bootstrap_sh
assert 'npm install -g "opencode-ai@$OPENCODE_VERSION"' in bootstrap_sh
assert 'pnpm add -g "@openchamber/web@$OPENCHAMBER_VERSION"' in bootstrap_sh
assert 'LAC_COMMAND=(lac)' in bootstrap_sh
assert '"${LAC_COMMAND[@]}" demo --local --yes' in bootstrap_sh
assert "python3.14 python3.13 python3.12 python3.11 python3.10 python3" in bootstrap_sh
assert '"commands"' in dcp_config and '"enabled": true' in dcp_config
PY

# 8. Demo client selection prefers OpenChamber and falls back to OpenCode.
python3 - <<'PY' "$ROOT" "$TMP_DIR"
import sys
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(sys.argv[1]) / "src"))
from lac import cli, clients
from lac.context import Context

for available, expected in (({"openchamber", "opencode"}, "openchamber"), ({"opencode"}, "opencode")):
    ctx = object()
    with patch.object(cli, "resolve_command", side_effect=lambda name: f"/fake/{name}" if name in available else None):
        with patch.object(cli, "render_client") as render, patch.object(cli, "client_open") as client_open:
            assert cli._launch_demo_client(ctx) == expected
            render.assert_called_once_with(ctx, expected)
            client_open.assert_called_once_with(ctx, expected)

fake_home = Path(sys.argv[2]) / "command-home"
pnpm_launcher = fake_home / "Library/pnpm/bin/openchamber"
pnpm_launcher.parent.mkdir(parents=True)
pnpm_launcher.write_text("#!/bin/sh\n", encoding="utf-8")
pnpm_launcher.chmod(0o755)
with patch.object(clients.shutil, "which", return_value=None), patch.object(clients.Path, "home", return_value=fake_home):
    assert clients.resolve_command("openchamber") == str(pnpm_launcher)

ctx = Context()
coexistence = {"checked": True, "detected_config_sources": [], "warnings": []}
with patch.object(clients, "command_exists", return_value=True), \
     patch.object(clients, "_inspect_before_open", return_value=coexistence), \
     patch.object(clients.subprocess, "run") as run:
    run.return_value.returncode = 0
    assert clients.client_open(ctx, "opencode")["ok"] is True
    env = run.call_args.kwargs["env"]
    assert env["OPENCODE_CONFIG"] == str(ctx.paths["opencode_config"])
    assert env["OPENCODE_CONFIG_DIR"] == str(ctx.paths["opencode_config_dir"])
    assert env["OPENCODE_DISABLE_AUTOUPDATE"] == "1"

process = type("Process", (), {"poll": lambda self: None})()
with patch.object(clients, "resolve_command", return_value="/fake/openchamber"):
    chamber = {"service": "openchamber", "port": 3000, "bind_host": "127.0.0.1", "connect_host": "127.0.0.1", "automatic": True, "allocation_source": "automatic-default"}
    opencode = {"service": "opencode", "port": 4095, "bind_host": "127.0.0.1", "connect_host": "127.0.0.1", "automatic": True, "allocation_source": "automatic-default"}
    with patch.object(clients, "_inspect_before_open", return_value=coexistence), \
         patch.object(clients, "allocate_service", side_effect=[chamber, opencode]), \
         patch.object(clients, "persist_started_service"), \
         patch.object(clients.subprocess, "Popen", return_value=process) as popen, \
         patch.object(clients.time, "sleep"):
        assert clients.client_open(ctx, "openchamber")["ok"] is True
        env = popen.call_args.kwargs["env"]
        assert env["OPENCODE_CONFIG"] == str(ctx.paths["opencode_config"])
        assert env["OPENCODE_CONFIG_DIR"] == str(ctx.paths["opencode_config_dir"])
        assert env["OPENCODE_DISABLE_AUTOUPDATE"] == "1"

openchamber_env = ctx.state_root / "clients/openchamber/openchamber.env"
env_text = openchamber_env.read_text(encoding="utf-8")
assert f"OPENCODE_CONFIG={ctx.paths['opencode_config']}" in env_text
assert f"OPENCODE_CONFIG_DIR={ctx.paths['opencode_config_dir']}" in env_text
assert "OPENCODE_DISABLE_AUTOUPDATE=1" in env_text
assert not (ctx.paths["opencode_config_dir"] / "agents").exists()
assert not (ctx.paths["opencode_config_dir"] / "skills").exists()
assert ctx.paths["opencode_agents_dir"].is_dir()
assert ctx.paths["opencode_skills_dir"].is_dir()
PY

# 9. Every preset model advertises the active runtime context and safe output budget.
python3 - <<'PY' "$ROOT" "$TMP_DIR"
import configparser
import json
import os
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "src"))
from lac.config import _output_cap_for_context

matrix_root = Path(sys.argv[2]) / "context-matrix"
profiles = json.loads((root / "runtime-config/profiles.json").read_text(encoding="utf-8"))["profiles"]
checked = 0

for profile_id, profile in profiles.items():
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    if profile["runtime_mode"] == "local":
        preset = (root / profile["preset"]).read_text(encoding="utf-8")
        parser.read_string("[global]\n" + preset)
        local_ids = {
            section for section in parser.sections()
            if section not in {"global", "*"} and parser.has_option(section, "model")
        }
    else:
        local_ids = set()
    state_root = matrix_root / profile_id
    env = os.environ.copy()
    env["AI_LOCAL_RUNTIME"] = "llama.cpp"
    env["LAC_STATE_ROOT"] = str(state_root)
    subprocess.run(
        [str(root / "bin/lac"), "profile", "apply", profile_id, "--json"],
        cwd=root,
        env=env,
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    generated = json.loads((state_root / "clients/opencode/opencode.json").read_text(encoding="utf-8"))
    dcp = json.loads((state_root / "clients/opencode/dcp.jsonc").read_text(encoding="utf-8"))
    generated_models = generated["provider"]["local-cluster"]["models"]
    assert set(generated_models) == local_ids, (profile_id, set(generated_models), local_ids)
    for model_id in local_ids:
        runtime_context = parser.getint(model_id, "ctx-size")
        fitting_context = parser.getint(model_id, "fit-ctx")
        limit = generated_models[model_id]["limit"]
        advertised_context = limit["context"]
        assert runtime_context >= 32768, (profile_id, model_id, runtime_context)
        assert fitting_context == runtime_context, (profile_id, model_id, fitting_context, runtime_context)
        assert advertised_context == runtime_context, (
            profile_id, model_id, runtime_context, advertised_context
        )
        expected_output = _output_cap_for_context(runtime_context)
        assert limit["output"] <= expected_output, (profile_id, model_id, limit["output"], expected_output)
        selector = f"local-cluster/{model_id}"
        expected_min = runtime_context // 2
        expected_max = min((runtime_context * 3) // 4, runtime_context - limit["output"] - 1)
        assert dcp["compress"]["modelMinLimits"][selector] == expected_min
        assert dcp["compress"]["modelMaxLimits"][selector] == expected_max
        assert expected_max < runtime_context - limit["output"]
        checked += 1

    ds4_limit = generated["provider"]["ds4"]["models"]["deepseek-v4-flash"]["limit"]
    assert ds4_limit["context"] == 262144, (profile_id, ds4_limit)
    assert ds4_limit["output"] == 16384, (profile_id, ds4_limit)
    ds4_selector = "ds4/deepseek-v4-flash"
    assert dcp["compress"]["modelMinLimits"][ds4_selector] == 131072
    assert dcp["compress"]["modelMaxLimits"][ds4_selector] == 196608

assert checked >= 60, checked
print(f"[ok] profile-aware OpenCode context/output/DCP limits: {checked} preset model sections")
PY

# 10. A non-default llama.cpp port reaches the generated OpenCode provider.
PORT_STATE="$TMP_DIR/custom-port"
LAC_PORT=18080 LAC_STATE_ROOT="$PORT_STATE" run "$LAC" profile apply micro --json > "$TMP_DIR/profile-custom-port.json"
python3 - <<'PY' "$PORT_STATE/clients/opencode/opencode.json"
import json
import sys
from pathlib import Path

config = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert config["provider"]["local-cluster"]["options"]["baseURL"] == "http://127.0.0.1:18080/v1"
print("[ok] custom llama.cpp port reaches OpenCode")
PY

if [[ "$(uname -s)" == "Darwin" ]]; then
  OMLX_STATE="$TMP_DIR/omlx-context"
  AI_LOCAL_RUNTIME=omlx LAC_STATE_ROOT="$OMLX_STATE" run "$LAC" profile apply 24gb --json > "$TMP_DIR/profile-omlx.json"
  python3 - <<'PY' "$OMLX_STATE/clients/opencode/opencode.json" "$ROOT/runtime-config/presets/24gb.ini"
import configparser
import json
import sys
from pathlib import Path

config = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert config["model"] == config["small_model"] == "local-cluster/Qwen3.6-27B-UD-MLX-6bit"
model_id = config["model"].split("/", 1)[1]
# The unmapped 4B small model is substituted with the mapped default, so the
# shared MLX alias advertises the default model's preset context.
parser = configparser.ConfigParser(interpolation=None, strict=False)
parser.read_string("[global]\n" + Path(sys.argv[2]).read_text(encoding="utf-8"))
expected = parser.getint("qwen3.6-27b-q4", "ctx-size")
assert config["provider"]["local-cluster"]["models"][model_id]["limit"]["context"] == expected
print("[ok] oMLX shared alias advertises the default model's preset context")
print("[ok] oMLX shared alias uses the smallest selected profile context")
PY
fi

# 11. Known checksum mismatches are blocking and quarantined.
python3 - <<'PY' "$ROOT" "$TMP_DIR"
import sys
from pathlib import Path

sys.path.insert(0, str(Path(sys.argv[1]) / "src"))
from lac.models import _quarantine_checksum_mismatch, _verify_checksum

models = Path(sys.argv[2]) / "checksum-models"
model = models / "demo" / "model.gguf"
model.parent.mkdir(parents=True)
model.write_bytes(b"corrupt")
known = {"demo/model.gguf": "0" * 64}
assert _verify_checksum(model, models, known) is False
_quarantine_checksum_mismatch(model)
assert not model.exists()
assert (model.parent / "model.gguf.checksum-mismatch").is_file()
PY

# 10. Optional msgraph skill lifecycle works against a temp skill root
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
if ! env LAC_OPENCODE_SKILLS_DIR="$SKILL_ROOT" "$LAC" skill status msgraph --json > "$TMP_DIR/skill-status-before.json"; then
  echo "[FAIL] skill status msgraph"
  FAILED=1
fi
python3 -c "import json; data=json.load(open('$TMP_DIR/skill-status-before.json')); assert data['installed'] is False"
echo "[test] skill install msgraph"
if ! env LAC_OPENCODE_SKILLS_DIR="$SKILL_ROOT" "$LAC" skill install msgraph --source "$FAKE_MSGRAPH" --json > "$TMP_DIR/skill-install.json"; then
  echo "[FAIL] skill install msgraph"
  FAILED=1
fi
test -f "$SKILL_ROOT/msgraph/SKILL.md" || { echo "[FAIL] msgraph SKILL.md was not installed"; FAILED=1; }
echo "[test] skill verify msgraph"
if ! env LAC_OPENCODE_SKILLS_DIR="$SKILL_ROOT" "$LAC" skill verify msgraph --json > "$TMP_DIR/skill-verify.json"; then
  echo "[FAIL] skill verify msgraph"
  FAILED=1
fi
python3 -c "import json; data=json.load(open('$TMP_DIR/skill-verify.json')); assert data['ok'] is True; assert 'MSGRAPH_CLIENT_SECRET' not in json.dumps(data)"
echo "[test] client render opencode with msgraph"
if ! env LAC_OPENCODE_SKILLS_DIR="$SKILL_ROOT" "$LAC" client render opencode --json > "$TMP_DIR/render-opencode-msgraph.json"; then
  echo "[FAIL] client render opencode with msgraph"
  FAILED=1
fi
python3 -c "import json; data=json.load(open('$TMP_DIR/render-opencode-msgraph.json')); graph=[p for p in data['packs'] if p['id']=='microsoft-graph'][0]; assert graph['installed'] is True"
echo "[test] skill remove msgraph"
if ! env LAC_OPENCODE_SKILLS_DIR="$SKILL_ROOT" "$LAC" skill remove msgraph --json > "$TMP_DIR/skill-remove.json"; then
  echo "[FAIL] skill remove msgraph"
  FAILED=1
fi
test ! -e "$SKILL_ROOT/msgraph" || { echo "[FAIL] msgraph skill directory was not removed"; FAILED=1; }

# 9. Init wizard works with --yes
INIT_STATE="$TMP_DIR/init-state"
LAC_STATE_ROOT="$INIT_STATE" run "$LAC" init --yes --profile 24gb --no-cloud --json > "$TMP_DIR/init.json"

# 10. Validate generated preset
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
