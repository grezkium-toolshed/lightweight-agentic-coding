#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANON_OPENROUTER_MODEL="qwen/qwen3-coder:480b-free"
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
  docs/release/README.md
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

python3 - <<'PY' "$ROOT" "$CANON_OPENROUTER_MODEL"
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
canonical_model = sys.argv[2]


def load_jsonc(path: Path):
    raw = path.read_text(encoding="utf-8")
    cleaned = "\n".join(
        line for line in raw.splitlines() if not line.lstrip().startswith("//")
    )
    return json.loads(cleaned)


def require(cond: bool, msg: str):
    if not cond:
        raise AssertionError(msg)


opencode = load_jsonc(root / "opencode.jsonc")
openrouter_models = opencode["provider"]["openrouter"]["models"]
require(canonical_model in openrouter_models, f"opencode.jsonc openrouter models must include '{canonical_model}'")

openrouter_doc = (root / "docs/providers/OPENROUTER_FREE.md").read_text(encoding="utf-8")
require(canonical_model in openrouter_doc, f"docs/providers/OPENROUTER_FREE.md must reference '{canonical_model}'")
require("Last verified:" in openrouter_doc, "docs/providers/OPENROUTER_FREE.md must include a 'Last verified:' line")

free_models_doc = (root / "docs/FREE_CLOUD_MODELS.md").read_text(encoding="utf-8")
require("qwen/qwen3-coder:free" not in free_models_doc, "docs/FREE_CLOUD_MODELS.md still contains stale model id 'qwen/qwen3-coder:free'")
require(canonical_model in free_models_doc, f"docs/FREE_CLOUD_MODELS.md must include canonical model '{canonical_model}'")

release_state = (root / "docs/release/STATE.md").read_text(encoding="utf-8")
require(
    "- CI pipeline" not in release_state,
    "docs/release/STATE.md still marks CI pipeline as deferred, but CI exists",
)

gitignore = (root / ".gitignore").read_text(encoding="utf-8")
for expected in (
    "runtime-config/active-profile.txt",
    "runtime-config/opencode.active.json",
    ".claude/",
    ".qwen/",
):
    require(expected in gitignore, f".gitignore must ignore '{expected}'")

skills_index = (root / "skills/README.md").read_text(encoding="utf-8")
agents_index = (root / "agents/README.md").read_text(encoding="utf-8")
require(".opencode/skills" in skills_index, "skills/README.md must point to .opencode/skills runtime assets")
require(".opencode/agents" in agents_index, "agents/README.md must point to .opencode/agents runtime assets")
require("index" in skills_index.lower(), "skills/README.md should describe skills/ as an index")
require("index" in agents_index.lower(), "agents/README.md should describe agents/ as an index")

print("[ok] Documentation consistency checks")
PY

echo "Documentation checks passed."
