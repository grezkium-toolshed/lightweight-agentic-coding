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
  docs/providers/AUTHENTICATION.md
  docs/providers/NVIDIA_NIM.md
  docs/security/THIRD_PARTY_AGENT_INTAKE.md
  docs/security/AGENCY_AGENTS_REVIEW.md
  docs/security/TRUST_MODEL.md
  docs/use-cases/STARTUP_HOME_TEAM.md
  docs/use-cases/ONBOARDING_16GB_24GB.md
  docs/use-cases/ONBOARDING_32GB_PLUS.md
  docs/use-cases/ONBOARDING_CLAUDE_CODE.md
  docs/release/PRIVATE_UNTIL_RELEASE.md
  docs/release/BETA_RELEASE_CRITERIA.md
  RELEASE_CHECKLIST.md
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
