#!/bin/bash
set -euo pipefail

CONFIG_DIR="${HOME}/.config/opencode"
BACKUP_DIR="$CONFIG_DIR/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

for f in opencode.json opencode.jsonc; do
  if [[ -f "$CONFIG_DIR/$f" ]]; then
    cp "$CONFIG_DIR/$f" "$BACKUP_DIR/$f"
    echo "[ok] backed up $CONFIG_DIR/$f"
  fi
done

echo "Backup created at: $BACKUP_DIR"
