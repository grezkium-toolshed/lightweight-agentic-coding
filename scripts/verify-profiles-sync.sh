#!/bin/bash
# Verifies that profile lists are in sync between setup-models-device.sh and setup-models-device.ps1
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SH_FILE="$SCRIPT_DIR/setup-models-device.sh"
PS1_FILE="$SCRIPT_DIR/setup-models-device.ps1"

if [[ ! -f "$SH_FILE" ]]; then
  echo "Missing: $SH_FILE" >&2
  exit 1
fi
if [[ ! -f "$PS1_FILE" ]]; then
  echo "Missing: $PS1_FILE" >&2
  exit 1
fi

# Extract profiles from bash: case statement entries like "  16gb)" (skip --profile and *)
sh_profiles="$(grep -E '^[[:space:]]+[a-z0-9-]+\)' "$SH_FILE" | tr -d ' \t)' | grep -vE '^--|^\*$' | sort -u)"

# Extract profiles from PowerShell: switch entries like "  '16gb' {"
ps1_profiles="$(grep -E "^[[:space:]]+'[a-z0-9-]+'" "$PS1_FILE" | sed "s/^[[:space:]]*'//" | sed "s/'.*//" | sort -u)"

# Compare
sh_only="$(comm -23 <(echo "$sh_profiles") <(echo "$ps1_profiles"))"
ps1_only="$(comm -13 <(echo "$sh_profiles") <(echo "$ps1_profiles"))"

err=0

if [[ -n "$sh_only" ]]; then
  echo "Profiles in .sh but not in .ps1:"
  echo "$sh_only" | while read -r p; do echo "  - $p"; done
  err=1
fi

if [[ -n "$ps1_only" ]]; then
  echo "Profiles in .ps1 but not in .sh:"
  echo "$ps1_only" | while read -r p; do echo "  - $p"; done
  err=1
fi

if [[ "$err" -eq 0 ]]; then
  echo "[ok] Profile lists in sync ($(echo "$sh_profiles" | wc -l | tr -d ' ') profiles)"
else
  echo ""
  echo "[fail] Profile lists out of sync" >&2
  exit 1
fi
