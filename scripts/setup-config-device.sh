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

# --- DCP plugin install ------------------------------------------------------
DCP_PLUGIN="@tarquinen/opencode-dcp@latest"
DCP_CACHE_DIR="${HOME}/.cache/opencode/packages/@tarquinen/opencode-dcp@latest"
DCP_PACKAGE_JSON="${DCP_CACHE_DIR}/node_modules/@tarquinen/opencode-dcp/package.json"
if [[ -f "$DCP_PACKAGE_JSON" ]] && grep -q '"version"[[:space:]]*:[[:space:]]*"3.1.9"' "$DCP_PACKAGE_JSON"; then
  echo "[setup] Removing stale DCP 3.1.9 package cache before reinstall..."
  rm -rf "$DCP_CACHE_DIR"
fi
if [[ "${AI_CLUSTER_INSTALL_DCP:-1}" == "0" ]]; then
  echo "[setup] DCP plugin install skipped (AI_CLUSTER_INSTALL_DCP=0)."
elif command -v opencode >/dev/null 2>&1; then
  echo "[setup] Installing/updating Dynamic Context Pruning plugin: $DCP_PLUGIN"
  if opencode plugin "$DCP_PLUGIN" --global --force; then
    echo "[setup] DCP plugin ready. Restart OpenCode and run /dcp to verify."
  else
    echo "[setup] WARNING: DCP plugin install failed."
    echo "[setup] Retry manually with: opencode plugin $DCP_PLUGIN --global --force"
  fi
else
  echo "[setup] WARNING: opencode is not in PATH; cannot install DCP plugin."
  echo "[setup] After installing OpenCode, run: opencode plugin $DCP_PLUGIN --global --force"
fi

echo "[setup] Device configuration complete for profile: $PROFILE"
