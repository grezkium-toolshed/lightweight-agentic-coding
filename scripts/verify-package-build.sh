#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

WHEEL_DIR="$TMP_DIR/wheel"
INSTALL_DIR="$TMP_DIR/install"
mkdir -p "$WHEEL_DIR"

PYTHON_BIN=""
COMPATIBLE_WITHOUT_BACKEND=""
FALLBACK_PYTHON=""
IGNORE_REQUIRES=0
NO_BUILD_ISOLATION=1
USE_UV_BUILD=0
for candidate in "${PYTHON:-}" python3.14 python3.13 python3.12 python3.11 python3.10 python3; do
  [[ -n "$candidate" ]] || continue
  command -v "$candidate" >/dev/null 2>&1 || continue
  has_backend=0
  if "$candidate" -c 'import setuptools.build_meta' >/dev/null 2>&1; then
    has_backend=1
  fi
  if "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' >/dev/null 2>&1; then
    if [[ "$has_backend" -eq 1 ]]; then
      PYTHON_BIN="$candidate"
      break
    fi
    if [[ -z "$COMPATIBLE_WITHOUT_BACKEND" ]]; then
      COMPATIBLE_WITHOUT_BACKEND="$candidate"
    fi
  elif [[ "$has_backend" -eq 1 && -z "$FALLBACK_PYTHON" ]]; then
    FALLBACK_PYTHON="$candidate"
  fi
done

if [[ -z "$PYTHON_BIN" && -n "$FALLBACK_PYTHON" ]]; then
  PYTHON_BIN="$FALLBACK_PYTHON"
  IGNORE_REQUIRES=1
  echo "[warn] Using $PYTHON_BIN with --ignore-requires-python for wheel-content inspection; install/runtime still requires Python 3.10+." >&2
fi

if [[ -z "$PYTHON_BIN" && -n "$COMPATIBLE_WITHOUT_BACKEND" ]]; then
  PYTHON_BIN="$COMPATIBLE_WITHOUT_BACKEND"
  if command -v uv >/dev/null 2>&1; then
    USE_UV_BUILD=1
  else
    NO_BUILD_ISOLATION=0
  fi
fi

if [[ -z "$PYTHON_BIN" ]]; then
  echo "Python 3.10+ with pip is required for package build verification." >&2
  exit 1
fi

if [[ "$USE_UV_BUILD" -eq 1 ]]; then
  uv build --wheel --cache-dir "${UV_CACHE_DIR:-$TMP_DIR/uv-cache}" --out-dir "$WHEEL_DIR" --no-create-gitignore "$ROOT" >/dev/null
else
  build_cmd=("$PYTHON_BIN" -m pip wheel "$ROOT" --no-deps -w "$WHEEL_DIR")
  if [[ "$NO_BUILD_ISOLATION" -eq 1 ]]; then
    build_cmd+=(--no-build-isolation)
  fi
  if [[ "$IGNORE_REQUIRES" -eq 1 ]]; then
    build_cmd+=(--ignore-requires-python)
  fi

  if ! "${build_cmd[@]}" >/dev/null; then
    if [[ "$NO_BUILD_ISOLATION" -eq 1 ]]; then
      echo "[warn] No-isolation wheel build failed; retrying with standard build isolation." >&2
      retry_cmd=("$PYTHON_BIN" -m pip wheel "$ROOT" --no-deps -w "$WHEEL_DIR")
      if [[ "$IGNORE_REQUIRES" -eq 1 ]]; then
        retry_cmd+=(--ignore-requires-python)
      fi
      "${retry_cmd[@]}" >/dev/null
    else
      exit 1
    fi
  fi
fi

"$PYTHON_BIN" - "$WHEEL_DIR" <<'PY'
import sys
import zipfile
from pathlib import Path

wheel_dir = Path(sys.argv[1])
wheels = sorted(wheel_dir.glob("lightweight_agentic_coding-*.whl"))
if len(wheels) != 1:
    raise SystemExit(f"Expected one lightweight_agentic_coding wheel, found: {[p.name for p in wheel_dir.glob('*.whl')]}")

wheel = wheels[0]
with zipfile.ZipFile(wheel) as archive:
    names = set(archive.namelist())
    metadata_files = [name for name in names if name.endswith(".dist-info/METADATA")]
    if not metadata_files:
        raise SystemExit("Wheel is missing METADATA")
    metadata = archive.read(metadata_files[0]).decode("utf-8")

required = {
    "lac/cli.py",
    "lac/runtime.py",
    "lac/data/catalog/assets.json",
    "lac/data/catalog/workflow-packs.json",
    "lac/data/opencode/opencode.template.jsonc",
    "lac/data/opencode/dcp.jsonc",
    "lac/data/opencode/agents/architecture-reviewer.md",
    "lac/data/opencode/skills/agent-browser/SKILL.md",
    "lac/data/opencode/skills/gsd/SKILL.md",
    "lac/data/opencode/craft/anti-ai-slop.md",
    "lac/data/opencode/design-systems/apple/DESIGN.md",
    "lac/data/runtime-config/profiles.json",
    "lac/data/runtime-config/chat-templates/gemma-4.jinja",
    "lac/data/runtime-config/chat-templates/qwen-coder-next.jinja",
    "lac/data/runtime-config/chat-templates/qwen3.5.jinja",
    "lac/data/runtime-config/presets/128gb-ds4-flash.ini",
}

missing = sorted(required - names)
if missing:
    raise SystemExit("Wheel is missing required package files:\n  - " + "\n  - ".join(missing))

if "Name: lightweight-agentic-coding" not in metadata:
    raise SystemExit("Wheel metadata has the wrong package name")
if "Version: 0.1.0" not in metadata:
    raise SystemExit("Wheel metadata has the wrong package version")

skill_count = sum(1 for name in names if name.startswith("lac/data/opencode/skills/") and name.endswith("/SKILL.md"))
agent_count = sum(1 for name in names if name.startswith("lac/data/opencode/agents/") and name.endswith(".md"))
if skill_count < 35 or agent_count < 6:
    raise SystemExit(f"Unexpected asset counts in wheel: {skill_count} skills, {agent_count} agents")

print(f"[ok] wheel: {wheel.name}")
print(f"[ok] packaged assets: {skill_count} skills, {agent_count} agents")
PY

wheel_path=("$WHEEL_DIR"/lightweight_agentic_coding-*.whl)
install_cmd=("$PYTHON_BIN" -m pip install "${wheel_path[0]}" --no-deps --target "$INSTALL_DIR")
if [[ "$IGNORE_REQUIRES" -eq 1 ]]; then
  install_cmd+=(--ignore-requires-python)
fi
"${install_cmd[@]}" >/dev/null

PYTHONPATH="$INSTALL_DIR" LAC_STATE_ROOT="$TMP_DIR/state" "$PYTHON_BIN" -m lac doctor --json > "$TMP_DIR/doctor.json"
"$PYTHON_BIN" - "$TMP_DIR/doctor.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assets = payload["assets"]
assert assets["catalog_asset_count"] == 41, assets
assert assets["pack_count"] == 7, assets
assert assets["opencode_agents"] == 6, assets
assert assets["opencode_skills"] == 35, assets
assert payload["ok"] is True, payload.get("failures")
print("[ok] installed wheel doctor reports expected package assets")
PY

PYTHONPATH="$INSTALL_DIR" LAC_STATE_ROOT="$TMP_DIR/state" "$PYTHON_BIN" -m lac pack list --json > "$TMP_DIR/pack-list.json"
"$PYTHON_BIN" - "$TMP_DIR/pack-list.json" <<'PY'
import json
import sys
from pathlib import Path

packs = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
ids = {pack["id"] for pack in packs}
expected = {
    "coding",
    "design",
    "devops",
    "microsoft-graph",
    "office",
    "research",
    "team-rollout",
}
if ids != expected:
    raise SystemExit(f"Installed wheel pack list mismatch: expected {sorted(expected)}, got {sorted(ids)}")
if len(packs) != 7:
    raise SystemExit(f"Installed wheel expected 7 workflow packs, got {len(packs)}")
print("[ok] installed wheel pack list reports expected workflow packs")
PY

PYTHONPATH="$INSTALL_DIR" LAC_STATE_ROOT="$TMP_DIR/state" "$PYTHON_BIN" -m lac profile apply 24gb >/dev/null
"$PYTHON_BIN" - "$TMP_DIR/state/runtime/presets.active.ini" <<'PY'
import sys
from pathlib import Path

preset = Path(sys.argv[1])
missing = []
for line in preset.read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("chat-template-file"):
        path = Path(line.split("=", 1)[1].strip())
        if not path.is_file():
            missing.append(path)
if missing:
    raise SystemExit("Generated preset references missing chat templates:\n  - " + "\n  - ".join(str(path) for path in missing))
print("[ok] installed wheel profile apply references packaged chat templates")
PY

echo "Package build checks passed."
