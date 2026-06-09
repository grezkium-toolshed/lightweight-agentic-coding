#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
required=(
  README.md
  docs/architecture.md
  docs/model-recommendations.md
  docs/config-summary.md
  state/README.md
  catalog/assets.json
  catalog/workflow-packs.json
  catalog/providers.json
  catalog/scenarios.json
  docs/CONFLUENCE_QWEN35_MIGRATION_GUIDE.md
  docs/FREE_CLOUD_MODELS.md
  docs/providers/README.md
  docs/providers/AUTHENTICATION.md
  docs/providers/NVIDIA_NIM.md
  docs/providers/OPENCODE_ZEN_GO.md
  docs/providers/CODEX_AUTH.md
  docs/providers/ANTHROPIC_API.md
  docs/providers/FREE_CLOUD_FALLBACKS.md
  docs/providers/GPU_BURSTING.md
  docs/security/THIRD_PARTY_AGENT_INTAKE.md
  docs/security/AGENCY_AGENTS_REVIEW.md
  docs/security/TRUST_MODEL.md
  docs/use-cases/BENCHMARKING.md
  docs/use-cases/SCENARIO_GUIDE.md
  docs/use-cases/STARTUP_HOME_TEAM.md
  docs/use-cases/HYBRID_WORKSPACES.md
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

export PYTHONPATH="${ROOT}/scripts:${PYTHONPATH:-}"

python3 - <<'PY' "$ROOT"
import json
import sys
from pathlib import Path

from lib.jsonc import load_jsonc

root = Path(sys.argv[1])


def require(cond: bool, msg: str):
    if not cond:
        raise AssertionError(msg)


opencode = load_jsonc(root / "opencode.template.jsonc")
openrouter_models = opencode["provider"]["openrouter"]["models"]
require(isinstance(openrouter_models, dict) and openrouter_models, "opencode.template.jsonc openrouter models must keep starter defaults")

openrouter_doc = (root / "docs/providers/OPENROUTER_FREE.md").read_text(encoding="utf-8")
require("./bin/lac provider models openrouter" in openrouter_doc, "docs/providers/OPENROUTER_FREE.md must point to the provider models command")
require("./bin/lac provider verify openrouter --refresh-catalog" in openrouter_doc, "docs/providers/OPENROUTER_FREE.md must document the refresh command")
require("Last verified:" in openrouter_doc, "docs/providers/OPENROUTER_FREE.md must include a 'Last verified:' line")

free_models_doc = (root / "docs/FREE_CLOUD_MODELS.md").read_text(encoding="utf-8")
require("qwen/qwen3-coder:free" not in free_models_doc, "docs/FREE_CLOUD_MODELS.md still contains stale model id 'qwen/qwen3-coder:free'")
require("./bin/lac provider models openrouter" in free_models_doc, "docs/FREE_CLOUD_MODELS.md must point to the provider models command")

free_models_json = json.loads((root / "docs/free-coding-models.json").read_text(encoding="utf-8"))
openrouter_entry = free_models_json["openrouter"]
require(isinstance(openrouter_entry, dict), "docs/free-coding-models.json openrouter entry must be metadata, not a frozen array")
require(openrouter_entry.get("live") is True, "docs/free-coding-models.json openrouter entry must mark live catalog usage")
require(openrouter_entry.get("list_command") == "./bin/lac provider models openrouter", "docs/free-coding-models.json must point to the provider models command")

release_state = (root / "docs/release/STATE.md").read_text(encoding="utf-8")
require(
    "- CI pipeline" not in release_state,
    "docs/release/STATE.md still marks CI pipeline as deferred, but CI exists",
)
require(
    "Free model availability on OpenRouter" not in release_state.split("### Open Questions", 1)[1].split("### Completed", 1)[0],
    "docs/release/STATE.md must not keep OpenRouter free-model availability under Open Questions",
)

gitignore = (root / ".gitignore").read_text(encoding="utf-8")
for expected in (
    "state/**",
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
