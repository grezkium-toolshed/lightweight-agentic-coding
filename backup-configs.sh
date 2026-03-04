#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backup-configs/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

FILES=(
  "opencode.jsonc"
  "runtime-config/presets.active.ini"
  "runtime-config/active-profile.txt"
)

for f in "${FILES[@]}"; do
  if [[ -f "$SCRIPT_DIR/$f" ]]; then
    cp "$SCRIPT_DIR/$f" "$BACKUP_DIR/$(basename "$f")"
    echo "[ok] backed up $f"
  else
    echo "[skip] missing $f"
  fi
done

echo "Backup created at: $BACKUP_DIR"
