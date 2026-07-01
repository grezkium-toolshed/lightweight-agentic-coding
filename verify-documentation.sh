#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
required=(
  README.md
  CHANGELOG.md
  CONTRIBUTING.md
  CODE_OF_CONDUCT.md
  LICENSE
  SUPPORT.md
  THIRD_PARTY_NOTICES.md
  models/README.md
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
  docs/release/BETA_RELEASE_CRITERIA.md
  docs/release/gates.json
  docs/release/MANUAL_VALIDATION.md
  scripts/release-evidence.sh
  scripts/release-ds4-128gb.sh
  scripts/release-fresh-clone-unix.sh
  scripts/release-llama-smoke.sh
  scripts/release-opencode-discovery.sh
  scripts/release-provider-freshness.sh
  scripts/release-gate-report.sh
  scripts/release-manual-next-steps.sh
  scripts/test-release-gate-report.sh
  scripts/verify-public-beta-local.sh
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
import re
import subprocess
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
require("./bin/lac doctor" in json.dumps(opencode.get("command", {})), "opencode.template.jsonc doctor command must use ./bin/lac doctor")

packaged_opencode = load_jsonc(root / "src/lac/data/opencode/opencode.template.jsonc")
require(opencode == packaged_opencode, "packaged opencode.template.jsonc must match repo template")

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

changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")
third_party_notices = (root / "THIRD_PARTY_NOTICES.md").read_text(encoding="utf-8")
packaged_third_party_notices = (root / "src/lac/data/THIRD_PARTY_NOTICES.md").read_text(encoding="utf-8")
contributing = (root / "CONTRIBUTING.md").read_text(encoding="utf-8")
support = (root / "SUPPORT.md").read_text(encoding="utf-8")
pyproject = (root / "pyproject.toml").read_text(encoding="utf-8")
model_recommendations = (root / "docs/model-recommendations.md").read_text(encoding="utf-8")
audit_findings = (root / "docs/audit-findings.md").read_text(encoding="utf-8")
review_backlog = (root / "docs/review-backlog.md").read_text(encoding="utf-8")
confluence_migration = (root / "docs/CONFLUENCE_QWEN35_MIGRATION_GUIDE.md").read_text(encoding="utf-8")
require("128gb-ds4-flash" in changelog and "DwarfStar" in changelog, "CHANGELOG.md must mention ds4/DwarfStar public beta work")
require("THIRD_PARTY_NOTICES.md" in changelog, "CHANGELOG.md must mention third-party notices")
require("antirez/ds4" in third_party_notices and "antirez/deepseek-v4-gguf" in third_party_notices, "THIRD_PARTY_NOTICES.md must include ds4 runtime and model sources")
require("open-design" in third_party_notices and "merill/msgraph" in third_party_notices and "gsd-build/get-shit-done" in third_party_notices, "THIRD_PARTY_NOTICES.md must include cataloged external source refs")
require(packaged_third_party_notices == third_party_notices, "src/lac/data/THIRD_PARTY_NOTICES.md must match root THIRD_PARTY_NOTICES.md")
require("verify-public-beta-local.sh" in changelog, "CHANGELOG.md must mention the public beta local gate wrapper")
require("First public release" not in changelog, "CHANGELOG.md must not claim a first public release while public beta gates remain open")
require("public beta remains gated" in changelog, "CHANGELOG.md must keep historical version notes honest about gated public beta")
require("verify-public-beta-local.sh" in contributing, "CONTRIBUTING.md must point contributors at the public beta local gate wrapper")
require("Development Status :: 4 - Beta" in pyproject, "pyproject.toml must include beta classifier")
require("https://github.com/TuukkaTanner/lightweight-agentic-coding/issues" in pyproject, "pyproject.toml must include public issue URL")
require("SECURITY.md" in support and "verify-public-beta-local.sh" in support, "SUPPORT.md must route security and public-beta validation")
require("./scripts/doctor.sh" not in model_recommendations, "docs/model-recommendations.md must not point users at retired doctor.sh")
require("./bin/lac doctor" in confluence_migration, "docs/CONFLUENCE_QWEN35_MIGRATION_GUIDE.md must point to ./bin/lac doctor")
require("Use `./bin/lac` on macOS/Linux" in confluence_migration, "docs/CONFLUENCE_QWEN35_MIGRATION_GUIDE.md must prefer bin/lac over legacy scripts")
for text, path in (
    (audit_findings, "docs/audit-findings.md"),
    (review_backlog, "docs/review-backlog.md"),
):
    require("Historical note" in text, f"{path} must be labelled as historical before public beta")
    require("docs/release/gates.json" in text and "./scripts/release-gate-report.sh" in text, f"{path} must point readers at current release gates")
for stale_path in (
    "runtime-config/presets.active.ini",
    "runtime-config/active-profile.txt",
    "runtime-config/opencode.active.json",
):
    require(stale_path not in contributing, f"CONTRIBUTING.md still references stale generated path {stale_path}")

current_guidance_files = [
    "README.md",
    "CHANGELOG.md",
    "CONTRIBUTING.md",
    "SUPPORT.md",
    "RELEASE_CHECKLIST.md",
    "SECURITY.md",
    "AGENTS.md",
    "models/README.md",
    "opencode.template.jsonc",
    "docs/architecture.md",
    "docs/config-summary.md",
    "docs/model-recommendations.md",
    "docs/release/README.md",
    "docs/release/BETA_RELEASE_CRITERIA.md",
    "docs/release/STATE.md",
    "docs/release/MANUAL_VALIDATION.md",
    "docs/security/TRUST_MODEL.md",
    "docs/security/THIRD_PARTY_AGENT_INTAKE.md",
    "docs/use-cases/BENCHMARKING.md",
    "docs/use-cases/SCENARIO_GUIDE.md",
    "docs/use-cases/STARTUP_HOME_TEAM.md",
    "docs/use-cases/HYBRID_WORKSPACES.md",
    "docs/use-cases/ONBOARDING_16GB_24GB.md",
    "docs/use-cases/ONBOARDING_32GB_PLUS.md",
    "docs/use-cases/ONBOARDING_CLAUDE_CODE.md",
    "src/lac/data/opencode/opencode.template.jsonc",
]
retired_command_patterns = (
    "./scripts/doctor.sh",
    "./scripts/smoke-test.sh",
    "scripts/setup-config-device.sh",
    "scripts/setup-models-device.sh",
    "runtime-config/presets.active.ini",
    "runtime-config/active-profile.txt",
    "runtime-config/opencode.active.json",
)
for rel_path in current_guidance_files:
    text = (root / rel_path).read_text(encoding="utf-8")
    for pattern in retired_command_patterns:
        require(pattern not in text, f"{rel_path} must not reference retired path `{pattern}`")

release_state = (root / "docs/release/STATE.md").read_text(encoding="utf-8")
release_index = (root / "docs/release/README.md").read_text(encoding="utf-8")
release_gates = json.loads((root / "docs/release/gates.json").read_text(encoding="utf-8"))
manual_validation = (root / "docs/release/MANUAL_VALIDATION.md").read_text(encoding="utf-8")
release_checklist = (root / "RELEASE_CHECKLIST.md").read_text(encoding="utf-8")
require(
    "- CI pipeline" not in release_state,
    "docs/release/STATE.md still marks CI pipeline as deferred, but CI exists",
)
require(
    "Free model availability on OpenRouter" not in release_state.split("### Open Questions", 1)[1].split("### Completed", 1)[0],
    "docs/release/STATE.md must not keep OpenRouter free-model availability under Open Questions",
)
for text, path in (
    (release_index, "docs/release/README.md"),
    (manual_validation, "docs/release/MANUAL_VALIDATION.md"),
    (release_state, "docs/release/STATE.md"),
    (release_checklist, "RELEASE_CHECKLIST.md"),
):
    require("./scripts/release-gate-report.sh" in text, f"{path} must point to the release gate report command")
for text, path in (
    (release_index, "docs/release/README.md"),
    (manual_validation, "docs/release/MANUAL_VALIDATION.md"),
    (release_checklist, "RELEASE_CHECKLIST.md"),
):
    require("./scripts/release-evidence.sh" in text, f"{path} must point to the release evidence helper")
release_evidence = (root / "scripts/release-evidence.sh").read_text(encoding="utf-8")
ds4_128gb = (root / "scripts/release-ds4-128gb.sh").read_text(encoding="utf-8")
fresh_clone_unix = (root / "scripts/release-fresh-clone-unix.sh").read_text(encoding="utf-8")
llama_smoke = (root / "scripts/release-llama-smoke.sh").read_text(encoding="utf-8")
opencode_discovery = (root / "scripts/release-opencode-discovery.sh").read_text(encoding="utf-8")
provider_freshness = (root / "scripts/release-provider-freshness.sh").read_text(encoding="utf-8")
require("Status: open" in release_evidence, "scripts/release-evidence.sh must generate open evidence stubs")
require("Keep this stub at Status: open" in release_evidence, "scripts/release-evidence.sh must tell testers not to close gates early")
require("Transcript capture helper" in release_evidence, "scripts/release-evidence.sh must print transcript capture guidance")
require("state/release-evidence" in release_evidence, "scripts/release-evidence.sh must write transcript guidance under ignored state/release-evidence")
require("--dry-run" in ds4_128gb, "scripts/release-ds4-128gb.sh must expose dry-run rehearsal mode")
require("--full-runtime" in ds4_128gb, "scripts/release-ds4-128gb.sh must expose full runtime mode")
require("--allow-missing-ds4" in ds4_128gb, "scripts/release-ds4-128gb.sh must make missing ds4 opt-in")
require("state/release-evidence" in ds4_128gb, "scripts/release-ds4-128gb.sh must write evidence under ignored state/release-evidence")
ds4_128gb_gate = next(gate for gate in release_gates.get("gates", []) if gate.get("id") == "ds4-128gb")
require("./scripts/release-ds4-128gb.sh --dry-run --allow-missing-ds4" in json.dumps(ds4_128gb_gate), "ds4-128gb gate must document dry-run rehearsal mode")
require("./scripts/release-ds4-128gb.sh --full-runtime" in json.dumps(ds4_128gb_gate), "ds4-128gb gate must point to the ds4 full-runtime helper")
require("./scripts/release-ds4-128gb.sh --full-runtime" in release_checklist, "release checklist must point to the ds4 full-runtime helper")
require("--full-runtime" in fresh_clone_unix, "scripts/release-fresh-clone-unix.sh must expose full runtime mode")
require("--allow-unsupported-python" in fresh_clone_unix, "scripts/release-fresh-clone-unix.sh must make unsupported Python opt-in")
require("state/release-evidence" in fresh_clone_unix, "scripts/release-fresh-clone-unix.sh must write evidence under ignored state/release-evidence")
fresh_clone_gate = next(gate for gate in release_gates.get("gates", []) if gate.get("id") == "fresh-clone-unix")
require("./scripts/release-fresh-clone-unix.sh --full-runtime" in json.dumps(fresh_clone_gate), "fresh-clone-unix gate must point to the Unix smoke helper")
require("./scripts/release-fresh-clone-unix.sh --full-runtime" in release_checklist, "release checklist must point to the Unix smoke helper")
require("--allow-unavailable" in llama_smoke, "scripts/release-llama-smoke.sh must expose local rehearsal mode")
require("state/release-evidence" in llama_smoke, "scripts/release-llama-smoke.sh must write evidence under ignored state/release-evidence")
llama_smoke_gate = next(gate for gate in release_gates.get("gates", []) if gate.get("id") == "llama-smoke")
require("./scripts/release-llama-smoke.sh" in json.dumps(llama_smoke_gate), "llama-smoke gate must point to the llama smoke helper")
require("./scripts/release-llama-smoke.sh" in release_checklist, "release checklist must point to the llama smoke helper")
require("--open" in opencode_discovery, "scripts/release-opencode-discovery.sh must expose real-session launch mode")
require("--skip-open" in opencode_discovery, "scripts/release-opencode-discovery.sh must expose automated rehearsal mode")
require("--allow-missing-opencode" in opencode_discovery, "scripts/release-opencode-discovery.sh must make missing OpenCode opt-in")
require("state/release-evidence" in opencode_discovery, "scripts/release-opencode-discovery.sh must write evidence under ignored state/release-evidence")
opencode_discovery_gate = next(gate for gate in release_gates.get("gates", []) if gate.get("id") == "opencode-discovery")
require("./scripts/release-opencode-discovery.sh --open" in json.dumps(opencode_discovery_gate), "opencode-discovery gate must point to the OpenCode discovery helper")
require("./scripts/release-opencode-discovery.sh --skip-open --allow-missing-opencode" in json.dumps(opencode_discovery_gate), "opencode-discovery gate must document rehearsal mode")
require("./scripts/release-opencode-discovery.sh --open" in release_checklist, "release checklist must point to the OpenCode discovery helper")
require("--refresh-catalog" in provider_freshness, "scripts/release-provider-freshness.sh must expose catalog refresh mode")
require("state/release-evidence" in provider_freshness, "scripts/release-provider-freshness.sh must write evidence under ignored state/release-evidence")
provider_freshness_gate = next(gate for gate in release_gates.get("gates", []) if gate.get("id") == "provider-live-freshness")
require("./scripts/release-provider-freshness.sh --refresh-catalog" in json.dumps(provider_freshness_gate), "provider-live-freshness gate must point to the provider freshness helper")
require("./scripts/release-provider-freshness.sh --refresh-catalog" in release_checklist, "release checklist must point to the provider freshness helper")
require(
    "./scripts/release-manual-next-steps.sh" in release_index,
    "docs/release/README.md must point to the manual next-steps helper",
)
for text, path in (
    (release_index, "docs/release/README.md"),
    (release_checklist, "RELEASE_CHECKLIST.md"),
):
    require("./scripts/verify-public-beta-local.sh" in text, f"{path} must point to the public beta local verifier")
require("docs/release/gates.json" in release_index, "docs/release/README.md must document the release gate manifest")
required_gate_fields = {"id", "owner", "summary", "evidence_required", "environment", "commands", "evidence", "checklist_refs"}
gate_records = release_gates.get("gates", [])
require(release_gates.get("schema_version") == 1, "docs/release/gates.json schema_version must be 1")
require(gate_records, "docs/release/gates.json must contain gates")
gate_ids = [gate.get("id") for gate in gate_records]
require(len(gate_ids) == len(set(gate_ids)), "docs/release/gates.json gate ids must be unique")
manual_gate_rows = {}
for line in manual_validation.splitlines():
    match = re.match(r"\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*(.+?)\s*\|", line)
    if match:
        manual_gate_rows[match.group(1)] = {
            "status": match.group(2).strip().lower(),
            "owner": match.group(3).strip(),
            "evidence_required": match.group(4).strip(),
        }
checklist_items = set()
current_checklist_section = ""
for line in release_checklist.splitlines():
    heading = re.match(r"^##\s+(.+)$", line)
    if heading:
        current_checklist_section = heading.group(1).strip()
        continue
    item = re.match(r"^- \[[ xX]\]\s+(.+)$", line)
    if item:
        checklist_items.add((current_checklist_section, item.group(1).strip()))
for gate in gate_records:
    missing = sorted(required_gate_fields - set(gate))
    require(not missing, f"docs/release/gates.json gate {gate.get('id', '<unknown>')} missing fields {missing}")
    require(gate["environment"] and gate["commands"] and gate["evidence"], f"docs/release/gates.json gate {gate['id']} must include environment, commands, and evidence")
    require(isinstance(gate["checklist_refs"], list) and gate["checklist_refs"], f"docs/release/gates.json gate {gate['id']} must include checklist_refs")
    for ref in gate["checklist_refs"]:
        require(isinstance(ref, dict) and ref.get("section") and ref.get("item"), f"docs/release/gates.json gate {gate['id']} has malformed checklist_ref")
        require((ref["section"], ref["item"]) in checklist_items, f"docs/release/gates.json gate {gate['id']} references missing checklist item {ref['section']}: {ref['item']}")
    require(gate["id"] in manual_gate_rows, f"docs/release/MANUAL_VALIDATION.md must track gate {gate['id']}")
    manual_row = manual_gate_rows[gate["id"]]
    require(manual_row["owner"] == gate["owner"], f"{gate['id']}: manual owner must match docs/release/gates.json")
    require(manual_row["evidence_required"] == gate["evidence_required"], f"{gate['id']}: manual evidence text must match docs/release/gates.json")
for gate_id in manual_gate_rows:
    require(gate_id in gate_ids, f"docs/release/MANUAL_VALIDATION.md has gate {gate_id} missing from docs/release/gates.json")
for gate_id in gate_ids:
    require(f"`{gate_id}`" in manual_validation, f"docs/release/MANUAL_VALIDATION.md must track gate {gate_id}")
release_evidence = json.loads(subprocess.check_output(
    [str(root / "scripts/release-evidence.sh"), "--json", "list"],
    cwd=root,
    text=True,
))
require(
    sorted(release_evidence["gates"]) == sorted(gate_ids),
    "scripts/release-evidence.sh must cover every manual validation gate",
)
release_gate_report = subprocess.run(
    [str(root / "scripts/release-gate-report.sh"), "--json"],
    cwd=root,
    text=True,
    capture_output=True,
)
require(release_gate_report.returncode in (0, 1), "release-gate-report must exit with release status, not a script/runtime error")
release_gate_payload = json.loads(release_gate_report.stdout)
require(
    release_gate_payload["manual_validation"]["closed_gate_evidence_error_count"] == 0,
    "closed manual validation gates must have complete evidence sections",
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
