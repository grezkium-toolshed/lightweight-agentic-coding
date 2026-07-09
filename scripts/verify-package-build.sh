#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN=""
for candidate in "${PYTHON:-}" python python3 python3.14 python3.13 python3.12 python3.11 python3.10; do
  [[ -n "$candidate" ]] || continue
  command -v "$candidate" >/dev/null 2>&1 || continue
  if "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' >/dev/null 2>&1; then
    PYTHON_BIN="$candidate"
    break
  fi
done
if [[ -z "$PYTHON_BIN" ]]; then
  echo "Python 3.10+ is required for package verification." >&2
  exit 1
fi
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
DIST_DIR="$TMP_DIR/dist"
INSTALL_DIR="$TMP_DIR/install"
mkdir -p "$DIST_DIR" "$INSTALL_DIR"

if "$PYTHON_BIN" -c 'import build' >/dev/null 2>&1; then
  "$PYTHON_BIN" -m build --outdir "$DIST_DIR" "$ROOT" >/dev/null
elif command -v uv >/dev/null 2>&1; then
  UV_CACHE_DIR="$TMP_DIR/uv-cache" uv build --quiet --out-dir "$DIST_DIR" --no-create-gitignore "$ROOT" >/dev/null
else
  echo "Package verification needs the Python 'build' module or uv." >&2
  echo "Install with: $PYTHON_BIN -m pip install build" >&2
  exit 1
fi

"$PYTHON_BIN" - "$DIST_DIR" <<'PY'
import sys
import tarfile
import zipfile
from pathlib import Path

dist = Path(sys.argv[1])
wheels = list(dist.glob("lightweight_agentic_coding-*.whl"))
sdists = list(dist.glob("lightweight_agentic_coding-*.tar.gz"))
if len(wheels) != 1 or len(sdists) != 1:
    raise SystemExit(f"Expected one wheel and one sdist, got {wheels} and {sdists}")

required_wheel = {
    "lac/cli.py",
    "lac/context.py",
    "lac/data/THIRD_PARTY_NOTICES.md",
    "lac/data/catalog/providers.json",
    "lac/data/opencode/opencode.template.jsonc",
    "lac/data/opencode/agents/architecture-reviewer.md",
    "lac/data/opencode/skills/gsd/SKILL.md",
    "lac/data/runtime-config/profiles.json",
    "lac/data/runtime-config/presets/micro.ini",
    "lac/data/templates/claude-code/README.md",
}
forbidden_fragments = (
    "/craft/",
    "/design-systems/",
    "/skills/msgraph/",
    "/skills/agent-browser/",
    "/skills/brand-guidelines/",
)

with zipfile.ZipFile(wheels[0]) as archive:
    names = set(archive.namelist())
    missing = sorted(required_wheel - names)
    if missing:
        raise SystemExit("Wheel is missing required files:\n  - " + "\n  - ".join(missing))
    forbidden = sorted(name for name in names if any(fragment in name for fragment in forbidden_fragments))
    if forbidden:
        raise SystemExit("Wheel contains excluded third-party content:\n  - " + "\n  - ".join(forbidden))
    if not any(name.endswith(".dist-info/licenses/LICENSE") for name in names):
        raise SystemExit("Wheel is missing LICENSE metadata")
    if not any(name.endswith(".dist-info/licenses/THIRD_PARTY_NOTICES.md") for name in names):
        raise SystemExit("Wheel is missing THIRD_PARTY_NOTICES.md metadata")
    skill_count = sum(name.startswith("lac/data/opencode/skills/") and name.endswith("/SKILL.md") for name in names)
    agent_count = sum(name.startswith("lac/data/opencode/agents/") and name.endswith(".md") for name in names)
    if (skill_count, agent_count) != (7, 6):
        raise SystemExit(f"Unexpected packaged assets: {skill_count} skills, {agent_count} agents")

with tarfile.open(sdists[0], "r:gz") as archive:
    names = [member.name for member in archive.getmembers()]
    required_suffixes = {
        "LICENSE",
        "README.md",
        "THIRD_PARTY_NOTICES.md",
        "src/lac/data/catalog/providers.json",
        "src/lac/data/templates/claude-code/README.md",
    }
    missing = sorted(suffix for suffix in required_suffixes if not any(name.endswith(suffix) for name in names))
    if missing:
        raise SystemExit("Sdist is missing required files:\n  - " + "\n  - ".join(missing))

print(f"[ok] wheel: {wheels[0].name}")
print(f"[ok] sdist: {sdists[0].name}")
print("[ok] packaged assets: 7 skills, 6 agents")
PY

WHEEL="$(find "$DIST_DIR" -name 'lightweight_agentic_coding-*.whl' -print -quit)"
PIP_CACHE_DIR="$TMP_DIR/pip-cache" "$PYTHON_BIN" -m pip install --no-deps --target "$INSTALL_DIR" "$WHEEL" >/dev/null

(
  cd "$TMP_DIR"
  export PYTHONPATH="$INSTALL_DIR"
  export LAC_DATA_ROOT="$TMP_DIR/data"
  export LAC_STATE_ROOT="$TMP_DIR/state"
  "$PYTHON_BIN" -m lac --version >/dev/null
  "$PYTHON_BIN" -m lac pack list --json > "$TMP_DIR/packs.json"
  "$PYTHON_BIN" -m lac profile apply micro --json > "$TMP_DIR/profile.json"
  "$PYTHON_BIN" -m lac client render claude-code --json > "$TMP_DIR/claude-code.json"
  "$PYTHON_BIN" - <<'PY'
from pathlib import Path

Path("sources.js").write_text(
    "export const openrouter = [\n['demo/model:free', 'Demo', 'A', 'n/a', '8k']\n]\n",
    encoding="utf-8",
)
PY
  "$PYTHON_BIN" -m lac catalog sync-free --source-url "file://$TMP_DIR/sources.js" >/dev/null
  "$PYTHON_BIN" - <<'PY'
import json
import os
from pathlib import Path

from lac.context import Context

ctx = Context()
expected_data = Path(os.environ["LAC_DATA_ROOT"])
assert ctx.models_root == expected_data / "models", (ctx.models_root, expected_data)
assert str(ctx.root).startswith(os.environ["PYTHONPATH"]), ctx.root
assert len(json.loads(Path("packs.json").read_text())) == 6
assert (Path(os.environ["LAC_STATE_ROOT"]) / "clients/claude-code/templates/README.md").is_file()
assert (expected_data / "catalog/free-coding-models.json").is_file()
assert (expected_data / "catalog/FREE_CLOUD_MODELS.md").is_file()
print("[ok] installed wheel uses writable user paths and renders supported clients")
PY
)

echo "Package build checks passed."
