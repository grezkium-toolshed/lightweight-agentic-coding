#!/bin/bash
set -euo pipefail

# Consolidated offline contract check for lac. Runs the fast, no-GPU, no-network checks
# that gate a change: shell syntax, config/provider schema, package-data staging, and a
# licensing guard that no un-shippable third-party skill leaks into the wheel.
#
# Pair with scripts/integration-test.sh (full CLI workflow) for the local release gate.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
FAILED=0

step() { echo ""; echo "=== $* ==="; }
fail() { echo "[FAIL] $*" >&2; FAILED=1; }

step "Shell syntax"
for f in scripts/*.sh verify*.sh bin/lac runtime-config/launch/*.sh; do
  [ -f "$f" ] || continue
  bash -n "$f" || fail "syntax: $f"
done

step "Config schema"
./scripts/verify-config-schema.sh || fail "config schema"

step "Delivery-run contract"
python3 - <<'PY' "$ROOT" || fail "delivery-run contract"
import copy
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
schema = json.loads((root / "contracts/delivery-run.v1.schema.json").read_text())
example = json.loads((root / "contracts/fixtures/delivery-run.v1.example.json").read_text())
ref_pattern = re.compile(r"^(restricted|internal|customer-safe):sha256:([a-f0-9]{64})$")


def validate(document):
    errors = []
    refs = set()
    for artifact in document.get("artifacts", []):
        match = ref_pattern.fullmatch(str(artifact.get("ref", "")))
        if not match or match.group(1) != artifact.get("classification") or match.group(2) != artifact.get("sha256"):
            errors.append(f"bad content reference: {artifact.get('id')}")
        else:
            refs.add(artifact["ref"])

    def known(value, field):
        if value not in refs:
            errors.append(f"unknown artifact reference: {field}")

    change = document.get("changeControl", {})
    approval = document.get("approval", {})
    deployment = document.get("deployment", {})
    verification = document.get("verification", {})
    known(change.get("preflightRef"), "changeControl.preflightRef")
    known(change.get("rollbackRef"), "changeControl.rollbackRef")
    if approval.get("status") == "approved":
        known(approval.get("decisionRef"), "approval.decisionRef")
    if deployment.get("status") in {"planned", "applied", "failed", "rolled-back"}:
        if approval.get("status") != "approved" or change.get("applicability") != "applicable":
            errors.append("deployment lacks approval or applicability")
    if deployment.get("status") in {"applied", "failed", "rolled-back"}:
        known(deployment.get("outcomeRef"), "deployment.outcomeRef")
    for value in verification.get("evidenceRefs", []):
        known(value, "verification.evidenceRefs")
    if verification.get("status") == "passed" and verification.get("independentReadback") is not True:
        errors.append("passed verification lacks independent read-back")
    for export in document.get("customerExports", []):
        known(export.get("artifactRef"), "customerExports.artifactRef")
        if not str(export.get("artifactRef", "")).startswith("customer-safe:sha256:"):
            errors.append("customer export is not customer-safe")
    repeat = document.get("repeatRun", {})
    if repeat.get("status") != "not-run":
        known(repeat.get("deltaRef"), "repeatRun.deltaRef")
    boundary = document.get("privacyBoundary", {})
    if boundary.get("customerIdentifiersIncluded") is not False or boundary.get("restrictedArtifactsRemainLocal") is not True:
        errors.append("privacy boundary is unsafe")
    return errors


assert schema.get("title") == "delivery-run.v1"
assert not validate(example), validate(example)
invalid = copy.deepcopy(example)
invalid["artifacts"][0]["ref"] = "restricted:sha256:" + "0" * 64
invalid["privacyBoundary"]["customerIdentifiersIncluded"] = True
assert len(validate(invalid)) >= 2
print("[delivery-run] schema + positive/negative semantic checks PASS")
PY

step "Provider catalog"
./scripts/verify-provider-catalog.sh || fail "provider catalog"

step "Hardware/profile contracts"
python3 -m unittest discover -s tests -p 'test_*.py' || fail "hardware/profile contracts"

step "Package data staging + completeness"
python3 scripts/stage_data.py
REQUIRED=(
  "THIRD_PARTY_NOTICES.md"
  "catalog/assets.json"
  "catalog/providers.json"
  "opencode/opencode.template.jsonc"
  "opencode/agents/architecture-reviewer.md"
  "runtime-config/profiles.json"
  "runtime-config/presets/24gb.ini"
  "runtime-config/presets/micro.ini"
)
for rel in "${REQUIRED[@]}"; do
  [ -e "src/lac/data/$rel" ] || fail "missing staged data: $rel"
done

step "Licensing guard (no un-shippable third-party skills bundled)"
# These are removed as vendored/third-party (open-design, Anthropic, vercel-labs). They
# must never reappear in the tracked tree or the staged wheel data. See THIRD_PARTY_NOTICES.md.
BANNED_SKILLS=(pdf brand-guidelines algorithmic-art canvas-design color-expert agent-browser)
for skill in "${BANNED_SKILLS[@]}"; do
  for base in .opencode/skills src/lac/data/opencode/skills; do
    if [ -e "$base/$skill/SKILL.md" ]; then
      fail "un-shippable skill present: $base/$skill"
    fi
  done
done

step "Release documentation coherence"
python3 - <<'PY' "$ROOT"
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
if not (root / "RELEASE_CHECKLIST.md").is_file():
    raise SystemExit("RELEASE_CHECKLIST.md is missing")

for rel in (
    "docs/providers/README.md",
    "docs/providers/OPENCODE_GO.md",
    "docs/security/TRUST_MODEL.md",
    "docs/security/THIRD_PARTY_AGENT_INTAKE.md",
    "templates/opencode/opencode.example.jsonc",
):
    text = (root / rel).read_text(encoding="utf-8")
    stale = sorted(token for token in ("codex-auth", "opencode-zen", "antigravity") if token in text.lower())
    if stale:
        raise SystemExit(f"{rel}: stale removed-provider references: {stale}")

index = (root / "skills/README.md").read_text(encoding="utf-8")
indexed = set(re.findall(r"^\| `([^`]+)` \|", index, flags=re.MULTILINE))
staged = {path.parent.name for path in (root / "src/lac/data/opencode/skills").glob("*/SKILL.md")}
if indexed != staged:
    raise SystemExit(f"skills/README.md mismatch: indexed={sorted(indexed)}, staged={sorted(staged)}")
print("[ok] release checklist, provider docs, trust docs, and skill index are coherent")
PY
# Vendored asset trees are opt-in fetch only; they must not be bundled.
for tree in .opencode/craft .opencode/design-systems src/lac/data/opencode/craft src/lac/data/opencode/design-systems; do
  if [ -d "$tree" ]; then
    fail "vendored asset tree bundled (should be opt-in fetch): $tree"
  fi
done

echo ""
if [ "$FAILED" -ne 0 ]; then
  echo "=== verify.sh: FAILED ==="
  exit 1
fi
echo "=== verify.sh: OK ==="
