#!/bin/bash
set -euo pipefail

PROFILE=""
AI_CLUSTER_ROOT="${AI_CLUSTER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
AI_MODELS_DIR="${AI_MODELS_DIR:-$AI_CLUSTER_ROOT/models}"
OPENCODE_TEMPLATE_PATH="${OPENCODE_TEMPLATE_PATH:-$AI_CLUSTER_ROOT/opencode.jsonc}"
PROFILE_MANIFEST_PATH="${PROFILE_MANIFEST_PATH:-$AI_CLUSTER_ROOT/runtime-config/profiles.json}"
ACTIVE_PRESET_PATH="${ACTIVE_PRESET_PATH:-$AI_CLUSTER_ROOT/runtime-config/presets.active.ini}"
ACTIVE_PROFILE_PATH="${ACTIVE_PROFILE_PATH:-$AI_CLUSTER_ROOT/runtime-config/active-profile.txt}"
ACTIVE_OPENCODE_CONFIG_PATH="${ACTIVE_OPENCODE_CONFIG_PATH:-$AI_CLUSTER_ROOT/runtime-config/opencode.active.json}"

usage() {
  cat << USAGE
Usage: $0 --profile <profile>

Generated outputs:
  runtime-config/presets.active.ini
  runtime-config/active-profile.txt
  runtime-config/opencode.active.json

Source inputs:
  opencode.jsonc
  runtime-config/profiles.json
  runtime-config/presets/<profile>.ini
USAGE
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

if [[ ! -f "$PROFILE_MANIFEST_PATH" ]]; then
  echo "Profile manifest missing: $PROFILE_MANIFEST_PATH" >&2
  exit 1
fi

read_profile_field() {
  local field="$1"
  python3 - << PY
import json
from pathlib import Path

manifest = json.loads(Path(r"$PROFILE_MANIFEST_PATH").read_text(encoding="utf-8"))
profile = manifest["profiles"].get(r"$PROFILE")
if profile is None:
    raise SystemExit("Unknown profile: " + r"$PROFILE")
value = profile.get(r"$field")
if value is None:
    raise SystemExit("Missing field: " + r"$field")
print(value)
PY
}

TEMPLATE_RELATIVE_PATH="$(read_profile_field preset)"
DEFAULT_MODEL="$(read_profile_field default_model)"
SMALL_MODEL="$(read_profile_field small_model)"

TEMPLATE="$AI_CLUSTER_ROOT/$TEMPLATE_RELATIVE_PATH"
if [[ ! -f "$TEMPLATE" ]]; then
  echo "Preset template missing: $TEMPLATE" >&2
  exit 1
fi

mkdir -p "$(dirname "$ACTIVE_PRESET_PATH")"
sed "s|__MODELS_DIR__|$AI_MODELS_DIR|g; s|__CLUSTER_ROOT__|$AI_CLUSTER_ROOT|g" "$TEMPLATE" > "$ACTIVE_PRESET_PATH"
printf "%s\n" "$PROFILE" > "$ACTIVE_PROFILE_PATH"

python3 - << PY
import json
from pathlib import Path

source = Path(r"$OPENCODE_TEMPLATE_PATH")
output = Path(r"$ACTIVE_OPENCODE_CONFIG_PATH")
text = source.read_text(encoding="utf-8")
clean = "\n".join(line for line in text.splitlines() if not line.strip().startswith("//"))
obj = json.loads(clean)
obj["model"] = r"$DEFAULT_MODEL"
obj["small_model"] = r"$SMALL_MODEL"
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
PY

echo "Wrote: $ACTIVE_PRESET_PATH"
echo "Set active profile: $PROFILE"
echo "Generated OpenCode config: $ACTIVE_OPENCODE_CONFIG_PATH"
