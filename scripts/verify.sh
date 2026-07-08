#!/bin/bash
set -euo pipefail

# Consolidated offline contract check for lac. Runs the fast, no-GPU, no-network checks
# that gate a change: shell syntax, config/provider schema, package-data staging, and a
# licensing guard that no un-shippable third-party skill leaks into the wheel.
#
# Pair with scripts/integration-test.sh (full CLI workflow) — CI runs both.

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

step "Provider catalog"
./scripts/verify-provider-catalog.sh || fail "provider catalog"

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
