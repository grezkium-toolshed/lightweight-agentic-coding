#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - <<'PY' "$ROOT"
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
skills_dir = root / ".opencode/skills"
agents_dir = root / ".opencode/agents"
asset_catalog = json.loads((root / "catalog/assets.json").read_text(encoding="utf-8"))
workflow_catalog = json.loads((root / "catalog/workflow-packs.json").read_text(encoding="utf-8"))

errors = []
catalog_assets = {asset["id"]: asset for asset in asset_catalog["assets"]}
catalog_paths = {asset["path"]: asset for asset in asset_catalog["assets"]}
pack_ids = {pack["id"] for pack in workflow_catalog["packs"]}


def split_frontmatter(text: str, path: Path):
    if not text.startswith("---\n"):
        errors.append(f"{path}: missing frontmatter start '---'")
        return "", text
    end = text.find("\n---\n", 4)
    if end == -1:
        errors.append(f"{path}: missing frontmatter end '---'")
        return "", text
    frontmatter = text[4:end]
    body = text[end + 5 :]
    return frontmatter, body


def has_key(frontmatter: str, key: str):
    return re.search(rf"(?m)^{re.escape(key)}\s*:", frontmatter) is not None


def check_skill(path: Path):
    text = path.read_text(encoding="utf-8")
    frontmatter, body = split_frontmatter(text, path)
    if not frontmatter:
        return

    for key in ("name", "description", "license", "compatibility", "metadata"):
        if not has_key(frontmatter, key):
            errors.append(f"{path}: missing frontmatter key '{key}'")

    name_match = re.search(r"(?m)^name:\s*([a-z0-9-]+)\s*$", frontmatter)
    if not name_match:
        errors.append(f"{path}: frontmatter 'name' must be kebab-case")
    else:
        expected = path.parent.name
        if name_match.group(1) != expected:
            errors.append(f"{path}: frontmatter name '{name_match.group(1)}' must match directory '{expected}'")

    if "compatibility: opencode" not in frontmatter:
        errors.append(f"{path}: compatibility must be 'opencode'")

    if not re.search(r"(?m)^\s{2}audience:\s*", frontmatter):
        errors.append(f"{path}: metadata.audience is required")
    if not re.search(r"(?m)^\s{2}output:\s*", frontmatter):
        errors.append(f"{path}: metadata.output is required")
    if not re.search(r"(?m)^\s{2}workflow:\s*", frontmatter):
        errors.append(f"{path}: metadata.workflow is required")

    for heading in ("## What I do", "## When to use me", "## Workflow", "## Guardrails", "## Notes"):
        if heading not in body:
            errors.append(f"{path}: missing required section '{heading}'")

    asset = catalog_paths.get(str(path.relative_to(root)))
    if asset is None:
        errors.append(f"{path}: missing asset catalog entry")
    else:
        if asset["type"] != "skill":
            errors.append(f"{path}: asset catalog type must be 'skill'")
        if asset["pack"] not in pack_ids:
            errors.append(f"{path}: asset catalog pack '{asset['pack']}' is unknown")
        for key in ("trust_level", "support_tier", "source", "source_ref", "review_status", "permission_notes", "supported_clients"):
            if key not in asset:
                errors.append(f"{path}: asset catalog missing '{key}'")


def check_agent(path: Path):
    text = path.read_text(encoding="utf-8")
    frontmatter, body = split_frontmatter(text, path)
    if not frontmatter:
        return

    for key in ("description", "mode", "permission"):
        if not has_key(frontmatter, key):
            errors.append(f"{path}: missing frontmatter key '{key}'")

    if "mode: subagent" not in frontmatter:
        errors.append(f"{path}: mode must be 'subagent'")

    if not body.strip():
        errors.append(f"{path}: agent body must not be empty")

    asset = catalog_paths.get(str(path.relative_to(root)))
    if asset is None:
        errors.append(f"{path}: missing asset catalog entry")
    else:
        if asset["type"] != "agent":
            errors.append(f"{path}: asset catalog type must be 'agent'")
        if asset["pack"] not in pack_ids:
            errors.append(f"{path}: asset catalog pack '{asset['pack']}' is unknown")
        for key in ("trust_level", "support_tier", "source", "source_ref", "review_status", "permission_notes", "supported_clients"):
            if key not in asset:
                errors.append(f"{path}: asset catalog missing '{key}'")


for skill_path in sorted(skills_dir.glob("*/SKILL.md")):
    check_skill(skill_path)

for agent_path in sorted(agents_dir.glob("*.md")):
    check_agent(agent_path)

for pack in workflow_catalog["packs"]:
    for asset_id in pack["assets"]:
        if asset_id not in catalog_assets:
            errors.append(f"pack {pack['id']}: unknown asset '{asset_id}'")

if errors:
    print("OpenCode asset checks failed:")
    for err in errors:
        print(f"  - {err}")
    raise SystemExit(1)

print(f"[ok] skills checked: {len(list(skills_dir.glob('*/SKILL.md')))}")
print(f"[ok] agents checked: {len(list(agents_dir.glob('*.md')))}")
print("OpenCode asset checks passed.")
PY
