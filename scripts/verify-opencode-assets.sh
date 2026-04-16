#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - <<'PY' "$ROOT"
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
skills_dir = root / ".opencode/skills"
agents_dir = root / ".opencode/agents"

errors = []


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


for skill_path in sorted(skills_dir.glob("*/SKILL.md")):
    check_skill(skill_path)

for agent_path in sorted(agents_dir.glob("*.md")):
    check_agent(agent_path)

if errors:
    print("OpenCode asset checks failed:")
    for err in errors:
        print(f"  - {err}")
    raise SystemExit(1)

print(f"[ok] skills checked: {len(list(skills_dir.glob('*/SKILL.md')))}")
print(f"[ok] agents checked: {len(list(agents_dir.glob('*.md')))}")
print("OpenCode asset checks passed.")
PY
