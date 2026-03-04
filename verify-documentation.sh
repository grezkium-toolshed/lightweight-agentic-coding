#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
required=(README.md ARCHITECTURE_OVERVIEW.md MODEL_RECOMMENDATIONS.md CONFIG_SUMMARY.md REVISION_NOTES.md docs/CONFLUENCE_QWEN35_MIGRATION_GUIDE.md docs/FREE_CLOUD_MODELS.md)

for f in "${required[@]}"; do
  if [[ -f "$ROOT/$f" ]]; then
    echo "[ok] $f"
  else
    echo "[!!] missing $f"
    exit 1
  fi
done

echo "Documentation checks passed."
