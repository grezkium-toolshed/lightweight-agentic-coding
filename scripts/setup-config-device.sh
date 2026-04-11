#!/bin/bash
set -euo pipefail

PROFILE=""
AI_CLUSTER_ROOT="${AI_CLUSTER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
AI_MODELS_DIR="${AI_MODELS_DIR:-$AI_CLUSTER_ROOT/models}"
OPENCODE_CONFIG_PATH="${OPENCODE_CONFIG_PATH:-$AI_CLUSTER_ROOT/opencode.jsonc}"

usage() {
  echo "Usage: $0 --profile <16gb|24gb|32gb|64gb|128gb-multi|128gb-qwen122b|128gb-minimax|gemma-16gb|gemma-24gb|gemma-32gb|gemma-64gb>"
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

TEMPLATE="$AI_CLUSTER_ROOT/runtime-config/presets/$PROFILE.ini"
ACTIVE="$AI_CLUSTER_ROOT/runtime-config/presets.active.ini"
if [[ ! -f "$TEMPLATE" ]]; then
  echo "Preset template missing: $TEMPLATE" >&2
  exit 1
fi

sed "s|__MODELS_DIR__|$AI_MODELS_DIR|g; s|__CLUSTER_ROOT__|$AI_CLUSTER_ROOT|g" "$TEMPLATE" > "$ACTIVE"
printf "%s\n" "$PROFILE" > "$AI_CLUSTER_ROOT/runtime-config/active-profile.txt"

case "$PROFILE" in
  16gb) default_model="qwen3.5-9b-q4" ;;
  24gb) default_model="qwen3.5-27b-q4" ;;
  32gb|64gb) default_model="qwen3.5-35b-a3b-q4" ;;
  128gb-multi) default_model="qwen3.5-35b-a3b-q4" ;;
  128gb-qwen122b) default_model="qwen3.5-122b-a10b" ;;
  128gb-minimax) default_model="minimax-m2.5" ;;
  gemma-16gb) default_model="gemma-4-26b-a4b-q4" ;;
  gemma-24gb) default_model="gemma-4-31b-q4" ;;
  gemma-32gb) default_model="gemma-4-31b-q8" ;;
  gemma-64gb) default_model="gemma-4-31b-bf16" ;;
  *)
    echo "Unsupported profile: $PROFILE" >&2
    exit 1
    ;;
esac

python3 - << PY
import json
from pathlib import Path
p=Path(r"$OPENCODE_CONFIG_PATH")
text=p.read_text()
clean='\n'.join([line for line in text.splitlines() if not line.strip().startswith('//')])
obj=json.loads(clean)
obj['model']=f"local-cluster/$default_model"
obj['provider']['local-cluster']['options']['baseURL']="http://127.0.0.1:8080/v1"
p.write_text(json.dumps(obj, indent=2)+"\n")
PY

echo "Wrote: $ACTIVE"
echo "Set active profile: $PROFILE"
echo "Updated model in: $OPENCODE_CONFIG_PATH"
