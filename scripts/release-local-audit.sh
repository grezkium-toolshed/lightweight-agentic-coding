#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT" "$@" <<'PY'
import json
import subprocess
import sys
from collections import Counter
from pathlib import Path

root = Path(sys.argv[1])
args = sys.argv[2:]
json_mode = "--json" in args

errors = []
warnings = []


def rel(path: Path) -> str:
    return path.relative_to(root).as_posix()


def require(condition: bool, message: str):
    if not condition:
        errors.append(message)


def read_text(path: str) -> str:
    file_path = root / path
    require(file_path.is_file(), f"missing required file: {path}")
    return file_path.read_text(encoding="utf-8") if file_path.is_file() else ""


asset_catalog = json.loads(read_text("catalog/assets.json") or '{"assets":[]}')
provider_catalog = json.loads(read_text("catalog/providers.json") or '{"providers":[]}')
readme = read_text("README.md")
pyproject = read_text("pyproject.toml")
gitignore = read_text(".gitignore")
trust_model = read_text("docs/security/TRUST_MODEL.md")
third_party_intake = read_text("docs/security/THIRD_PARTY_AGENT_INTAKE.md")
third_party_notices = read_text("THIRD_PARTY_NOTICES.md")
agency_review = read_text("docs/security/AGENCY_AGENTS_REVIEW.md")
provider_auth = read_text("docs/providers/AUTHENTICATION.md")
providers_readme = read_text("docs/providers/README.md")
openrouter_doc = read_text("docs/providers/OPENROUTER_FREE.md")
free_cloud_fallbacks = read_text("docs/providers/FREE_CLOUD_FALLBACKS.md")
free_cloud_models = read_text("docs/FREE_CLOUD_MODELS.md")
scenario_guide = read_text("docs/use-cases/SCENARIO_GUIDE.md")
claude_onboarding = read_text("docs/use-cases/ONBOARDING_CLAUDE_CODE.md")
claude_template_readme = read_text("templates/claude-code/README.md")
claude_template_guidance = read_text("templates/claude-code/CLAUDE.md")
release_readme = read_text("docs/release/README.md")
release_criteria = read_text("docs/release/BETA_RELEASE_CRITERIA.md")
release_state = read_text("docs/release/STATE.md")
profiles_manifest = json.loads(read_text("runtime-config/profiles.json") or '{"profiles":{}}')
workflow_catalog = json.loads(read_text("catalog/workflow-packs.json") or '{"packs":[]}')
scenario_catalog = json.loads(read_text("catalog/scenarios.json") or '{"scenarios":[]}')

assets = asset_catalog.get("assets", [])
asset_ids = {asset.get("id") for asset in assets}

# Repo hygiene: tracked model binaries and local-machine state.
tracked = subprocess.check_output(["git", "ls-files"], cwd=root, text=True).splitlines()
allowed_generated_docs = {"models/.gitkeep", "models/README.md", "state/README.md"}
model_suffixes = (".gguf", ".safetensors", ".onnx", ".pt", ".pth", ".ckpt")
tracked_model_artifacts = [
    path for path in tracked
    if path.endswith(model_suffixes)
    or (path.startswith("models/") and path not in allowed_generated_docs)
    or (path.startswith("state/") and path not in allowed_generated_docs)
    or path.startswith(".qwen/")
    or path.startswith(".claude/")
    or path.endswith(".DS_Store")
]
require(not tracked_model_artifacts, "tracked model/local-machine artifacts found: " + ", ".join(tracked_model_artifacts))
for expected in ("models/**", "state/**", ".qwen/", ".claude/"):
    require(expected in gitignore, f".gitignore must contain {expected}")

# Public identity and release positioning. These checks keep the package slug,
# docs name, and beta promise aligned before public release.
require(readme.startswith("# lac — Lightweight Agentic Coding"), "README must use lac — Lightweight Agentic Coding as the title")
require('name = "lightweight-agentic-coding"' in pyproject, "pyproject package name must remain lightweight-agentic-coding")
require("lac — Lightweight Agentic Coding CLI" in pyproject, "pyproject description must expose the lac product identity")
for text, path in (
    (release_readme, "docs/release/README.md"),
    (release_criteria, "docs/release/BETA_RELEASE_CRITERIA.md"),
    (release_state, "docs/release/STATE.md"),
):
    require("public beta" in text.lower(), f"{path} must explicitly frame the release as public beta")
    require("stable v1" in text.lower(), f"{path} must explicitly avoid stable v1 positioning")
    require("lac" in text and "Lightweight Agentic Coding" in text, f"{path} must carry the lac — Lightweight Agentic Coding identity")
for stale_phrase in ("AI Cluster", "Qwen cluster"):
    require(stale_phrase not in readme + release_readme + release_criteria + release_state, f"public release docs must not use stale phrase: {stale_phrase}")

# Trust metadata coherence.
required_asset_fields = {
    "id", "type", "path", "pack", "trust_level", "support_tier", "source",
    "source_ref", "review_status", "permission_notes", "supported_clients",
}
for asset in assets:
    missing = sorted(required_asset_fields - set(asset))
    require(not missing, f"{asset.get('id', '<unknown>')}: missing catalog fields {missing}")
    review = asset.get("review_status")
    support = asset.get("support_tier")
    source = asset.get("source")
    trust = asset.get("trust_level")
    if review == "not-reviewed":
        require(
            support == "optional" and source == "upstream-external" and trust == "community",
            f"{asset.get('id')}: not-reviewed assets must be optional upstream community assets",
        )
    if source == "repo-curated":
        require(review == "reviewed" and trust == "core", f"{asset.get('id')}: repo-curated assets must be reviewed core assets")
    if source == "adapted-external":
        require(review == "trimmed-and-reviewed", f"{asset.get('id')}: adapted external assets must be trimmed-and-reviewed")

require("skill:msgraph" in asset_ids, "catalog must include optional skill:msgraph")
msgraph = next((asset for asset in assets if asset.get("id") == "skill:msgraph"), {})
require(msgraph.get("support_tier") == "optional", "skill:msgraph must remain optional")
require(msgraph.get("review_status") == "opt-in-reviewed", "skill:msgraph must stay opt-in-reviewed")

for text, path in (
    (trust_model, "docs/security/TRUST_MODEL.md"),
    (third_party_intake, "docs/security/THIRD_PARTY_AGENT_INTAKE.md"),
):
    for term in ("Open Design", "optional", "Microsoft Graph"):
        require(term in text, f"{path} must mention {term}")
external_source_refs = sorted({
    asset.get("source_ref")
    for asset in assets
    if asset.get("source") != "repo-curated" and asset.get("source_ref")
})
for source_ref in external_source_refs:
    require(source_ref in third_party_notices, f"THIRD_PARTY_NOTICES.md must mention catalog source_ref {source_ref}")
for runtime_ref in ("antirez/ds4", "antirez/deepseek-v4-gguf"):
    require(runtime_ref in third_party_notices, f"THIRD_PARTY_NOTICES.md must mention {runtime_ref}")
require("THIRD_PARTY_NOTICES.md" in readme, "README.md must link THIRD_PARTY_NOTICES.md")
require("THIRD_PARTY_NOTICES.md" in third_party_intake, "third-party intake docs must require notices updates")
require("agency-agents" in agency_review, "docs/security/AGENCY_AGENTS_REVIEW.md must preserve the agency-agents review")

# Provider docs structural coverage. This does not replace live provider probes.
provider_docs = {
    "antigravity": "docs/providers/AUTHENTICATION.md",
    "z-ai": "docs/providers/AUTHENTICATION.md",
    "nvidia-nim": "docs/providers/NVIDIA_NIM.md",
    "openrouter": "docs/providers/OPENROUTER_FREE.md",
    "opencode-zen": "docs/providers/OPENCODE_ZEN_GO.md",
    "opencode-go": "docs/providers/OPENCODE_ZEN_GO.md",
    "codex-auth": "docs/providers/CODEX_AUTH.md",
    "anthropic": "docs/providers/ANTHROPIC_API.md",
}
for provider_id, doc_path in provider_docs.items():
    require((root / doc_path).is_file(), f"{provider_id}: missing provider doc {doc_path}")

for provider in provider_catalog.get("providers", []):
    provider_id = provider.get("id")
    if provider_id == "local-cluster":
        continue
    env_var = provider.get("env_var")
    require(provider_id in provider_docs, f"{provider_id}: no provider doc mapping in release audit")
    require(env_var and env_var in provider_auth + providers_readme + openrouter_doc + free_cloud_fallbacks, f"{provider_id}: env var {env_var} missing from provider docs")

require("./bin/lac provider verify --all" in providers_readme, "provider README must point to provider verify --all")
require("Last verified:" in openrouter_doc, "OpenRouter free doc must carry a Last verified marker")
for text, path in (
    (free_cloud_fallbacks, "docs/providers/FREE_CLOUD_FALLBACKS.md"),
    (openrouter_doc, "docs/providers/OPENROUTER_FREE.md"),
    (free_cloud_models, "docs/FREE_CLOUD_MODELS.md"),
):
    require("model drift" in text.lower() or "models rotate" in text.lower() or "provider freshness" in text.lower() or "model availability" in text.lower(), f"{path} must call out model/provider drift")
require("lac catalog sync-free" in free_cloud_fallbacks, "free cloud fallback docs must document catalog sync")
require("./bin/lac provider models openrouter" in openrouter_doc, "OpenRouter docs must point to provider models command")
require("./bin/lac provider verify openrouter --refresh-catalog" in openrouter_doc, "OpenRouter docs must point to refresh command")

# Scenario/onboarding docs.
profile_ids = set(profiles_manifest.get("profiles", {}))
pack_ids = {pack.get("id") for pack in workflow_catalog.get("packs", [])}
scenario_ids = set()
for scenario in scenario_catalog.get("scenarios", []):
    scenario_id = scenario.get("id")
    scenario_ids.add(scenario_id)
    require(scenario.get("label", "") in scenario_guide, f"scenario guide must include label for {scenario_id}")
    for profile_id in scenario.get("recommended_profiles", []):
        require(profile_id in profile_ids, f"{scenario_id}: unknown recommended profile {profile_id}")
    for pack_id in scenario.get("recommended_packs", []):
        require(pack_id in pack_ids, f"{scenario_id}: unknown recommended pack {pack_id}")
require({"solo-coder", "research-operator", "office-automation", "team-pilot"}.issubset(scenario_ids), "scenario catalog missing required public onboarding scenarios")
require("catalog/scenarios.json" in scenario_guide, "scenario guide must point to canonical scenario catalog")
require("catalog/workflow-packs.json" in scenario_guide, "scenario guide must point to canonical workflow pack catalog")
for pack in workflow_catalog.get("packs", []):
    label = pack.get("label") or pack.get("name")
    require(label and label in scenario_guide, f"scenario guide must include workflow pack label {label}")

# Claude Code docs are intentionally docs/templates only, not a mirrored runtime.
for text, path in (
    (claude_onboarding, "docs/use-cases/ONBOARDING_CLAUDE_CODE.md"),
    (claude_template_readme, "templates/claude-code/README.md"),
    (claude_template_guidance, "templates/claude-code/CLAUDE.md"),
):
    require("Claude Code" in text, f"{path} must explicitly name Claude Code")
require("docs and templates only" in claude_template_readme, "Claude template README must state docs/templates-only scope")
require("does not duplicate the runtime stack" in claude_onboarding, "Claude onboarding must not imply a mirrored launcher stack")

payload = {
    "ok": not errors,
    "errors": errors,
    "warnings": warnings,
    "asset_summary": {
        "count": len(assets),
        "trust_level": dict(Counter(asset.get("trust_level") for asset in assets)),
        "support_tier": dict(Counter(asset.get("support_tier") for asset in assets)),
        "source": dict(Counter(asset.get("source") for asset in assets)),
        "review_status": dict(Counter(asset.get("review_status") for asset in assets)),
        "external_source_refs": external_source_refs,
    },
    "tracked_artifact_check": {
        "tracked_file_count": len(tracked),
        "tracked_model_artifacts": tracked_model_artifacts,
    },
    "provider_doc_count": len(provider_docs),
    "scenario_count": len(scenario_catalog.get("scenarios", [])),
    "claude_templates_checked": 2,
}

if json_mode:
    print(json.dumps(payload, indent=2))
else:
    print("Release local audit")
    print(f"- Assets checked: {len(assets)}")
    print(f"- Provider docs checked: {len(provider_docs)}")
    print(f"- Scenarios checked: {len(scenario_catalog.get('scenarios', []))}")
    print("- Claude Code templates checked: 2")
    print(f"- Tracked model/local artifacts: {len(tracked_model_artifacts)}")
    if errors:
        print("- Errors:")
        for error in errors:
            print(f"  - {error}")
    if warnings:
        print("- Warnings:")
        for warning in warnings:
            print(f"  - {warning}")
    print("Release local audit passed." if payload["ok"] else "Release local audit failed.")

raise SystemExit(0 if payload["ok"] else 1)
PY
