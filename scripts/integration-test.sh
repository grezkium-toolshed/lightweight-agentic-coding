#!/bin/bash
set -euo pipefail

# Integration test for lac
# Validates the full CLI workflow without starting llama-server.
# This can run in CI without GPU.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAC="$ROOT/bin/lac"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export LAC_STATE_ROOT="$TMP_DIR/state"
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

# 3. Doctor runs without error
run "$LAC" doctor --bootstrap-hint --json > "$TMP_DIR/doctor.json"

# 4. Client render works for all supported clients
for client in opencode claude-code codex-reference; do
  run "$LAC" client render "$client" --json > "$TMP_DIR/render-$client.json"
done

# 5. Provider list works
run "$LAC" provider list --json > "$TMP_DIR/providers.json"

# 6. Pack and scenario lists work
run "$LAC" pack list --json > "$TMP_DIR/packs.json"
run "$LAC" scenario list --json > "$TMP_DIR/scenarios.json"

# 7. DCP plugin setup stays on the supported install path
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
launch_desktop_ps1 = (root / "runtime-config/launch/launch-local-desktop.ps1").read_text(encoding="utf-8")
bootstrap_sh = (root / "scripts/bootstrap.sh").read_text(encoding="utf-8")
dcp_config = (root / ".opencode/dcp.jsonc").read_text(encoding="utf-8")
micro_preset = (root / "runtime-config/presets/micro.ini").read_text(encoding="utf-8")

micro_limit = template_config["provider"]["local-cluster"]["models"]["qwen3.5-4b-q4"]["limit"]

assert "@tarquinen/opencode-dcp@3.1.14" in template
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
assert "runtime start" in launch_desktop_ps1
assert "client open opencode --desktop" in launch_desktop_ps1
assert 'PNPM_HOME="$HOME/Library/pnpm"' in bootstrap_sh
assert 'export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH"' in bootstrap_sh
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
PY

# 9. Every selected local model advertises the active preset's real context.
python3 - <<'PY' "$ROOT" "$TMP_DIR"
import configparser
import json
import os
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
matrix_root = Path(sys.argv[2]) / "context-matrix"
profiles = json.loads((root / "runtime-config/profiles.json").read_text(encoding="utf-8"))["profiles"]
checked = 0

for profile_id, profile in profiles.items():
    selectors = [profile[field] for field in ("default_model", "small_model")]
    local_ids = {
        selector.split("/", 1)[1]
        for selector in selectors
        if selector.startswith("local-cluster/")
    }
    if not local_ids:
        continue

    parser = configparser.ConfigParser(interpolation=None, strict=False)
    preset = (root / profile["preset"]).read_text(encoding="utf-8")
    parser.read_string("[global]\n" + preset)
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
    generated_models = generated["provider"]["local-cluster"]["models"]
    for model_id in local_ids:
        runtime_context = parser.getint(model_id, "ctx-size")
        advertised_context = generated_models[model_id]["limit"]["context"]
        assert runtime_context >= 32768, (profile_id, model_id, runtime_context)
        assert advertised_context == runtime_context, (
            profile_id, model_id, runtime_context, advertised_context
        )
        checked += 1

assert checked >= 20, checked
print(f"[ok] profile-aware OpenCode context limits: {checked} local model selections")
PY

if [[ "$(uname -s)" == "Darwin" ]]; then
  OMLX_STATE="$TMP_DIR/omlx-context"
  AI_LOCAL_RUNTIME=omlx LAC_STATE_ROOT="$OMLX_STATE" run "$LAC" profile apply 24gb --json > "$TMP_DIR/profile-omlx.json"
  python3 - <<'PY' "$OMLX_STATE/clients/opencode/opencode.json"
import json
import sys
from pathlib import Path

config = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert config["model"] == config["small_model"] == "local-cluster/Qwen3.6-27B-UD-MLX-6bit"
model_id = config["model"].split("/", 1)[1]
assert config["provider"]["local-cluster"]["models"][model_id]["limit"]["context"] == 65536
print("[ok] oMLX shared alias uses the smallest selected profile context")
PY
fi

# 10. Known checksum mismatches are blocking and quarantined.
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
