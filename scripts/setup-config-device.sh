#!/bin/bash
set -euo pipefail

PROFILE=""
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  echo "Usage: $0 --profile <profile>" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$PROFILE" ]]; then
  usage
  exit 1
fi

# Apply the profile via lac
"$ROOT/bin/lac" profile apply "$PROFILE"

# --- oMLX settings -----------------------------------------------------------
OMLX_SETTINGS="${HOME}/.omlx/settings.json"
if [[ -f "$OMLX_SETTINGS" ]]; then
  echo "[setup] oMLX detected at $OMLX_SETTINGS — updating context limits..."
  python3 - <<PY
import json
from pathlib import Path

path = Path("${OMLX_SETTINGS}")
with path.open("r", encoding="utf-8") as f:
    cfg = json.load(f)

cfg.setdefault("sampling", {})
cfg["sampling"]["max_context_window"] = 262144
cfg["sampling"]["max_tokens"] = 16384

with path.open("w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")

print("[setup] oMLX max_context_window=262144 max_tokens=16384")
PY
else
  echo "[setup] oMLX not detected (no $OMLX_SETTINGS). Skipping oMLX configuration."
fi

# --- DCP plugin check --------------------------------------------------------
DCP_PLUGIN="@tarquinen/opencode-dcp"
DCP_INSTALLED=0
if command -v opencode >/dev/null 2>&1; then
  if opencode plugin list 2>/dev/null | grep -q "$DCP_PLUGIN"; then
    DCP_INSTALLED=1
  fi
fi

if [[ "$DCP_INSTALLED" -eq 0 ]]; then
  echo "[setup] WARNING: Dynamic Context Pruning plugin '$DCP_PLUGIN' is not installed."
  echo "[setup] It is listed in opencode.template.jsonc but will fail to load until installed."
  echo "[setup] Install with: opencode plugin $DCP_PLUGIN --global"
fi

echo "[setup] Device configuration complete for profile: $PROFILE"
