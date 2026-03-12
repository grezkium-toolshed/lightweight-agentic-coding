#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
required=(
  README.md
  ARCHITECTURE_OVERVIEW.md
  MODEL_RECOMMENDATIONS.md
  CONFIG_SUMMARY.md
  REVISION_NOTES.md
  docs/CONFLUENCE_QWEN35_MIGRATION_GUIDE.md
  docs/FREE_CLOUD_MODELS.md
  docs/providers/README.md
  docs/providers/NVIDIA_NIM.md
  docs/security/THIRD_PARTY_AGENT_INTAKE.md
  docs/security/AGENCY_AGENTS_REVIEW.md
  docs/use-cases/STARTUP_HOME_TEAM.md
  docs/release/PRIVATE_UNTIL_RELEASE.md
)

for f in "${required[@]}"; do
  if [[ -f "$ROOT/$f" ]]; then
    echo "[ok] $f"
  else
    echo "[!!] missing $f"
    exit 1
  fi
done

echo "Documentation checks passed."
