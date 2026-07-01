#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lac-public-beta-local.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

run_check() {
  local label="$1"
  shift
  echo
  echo "==> $label"
  "$@"
}

run_check "Coherence" ./verify-coherence.sh
run_check "Documentation consistency" ./verify-documentation.sh
run_check "Profile and preset parity" ./scripts/verify-profiles-sync.sh
run_check "Config schema" ./scripts/verify-config-schema.sh
run_check "OpenCode asset parity" ./scripts/verify-opencode-assets.sh
run_check "Provider catalog" ./scripts/verify-provider-catalog.sh
run_check "V2 CLI contract" ./scripts/verify-v2-contract.sh
run_check "Integration test" ./scripts/integration-test.sh
run_check "ds4 128GB evidence rehearsal" ./scripts/release-ds4-128gb.sh --dry-run --allow-missing-ds4
run_check "OpenCode discovery evidence rehearsal" ./scripts/release-opencode-discovery.sh --skip-open --allow-missing-opencode
run_check "Fresh-clone Unix no-download smoke" ./scripts/release-fresh-clone-unix.sh --allow-unsupported-python
run_check "Package build" ./scripts/verify-package-build.sh
run_check "Provider freshness evidence smoke" ./scripts/release-provider-freshness.sh
run_check "llama smoke evidence rehearsal" ./scripts/release-llama-smoke.sh --allow-unavailable
run_check "Release local audit" ./scripts/release-local-audit.sh
run_check "Release gate report self-test" ./scripts/test-release-gate-report.sh

echo
echo "==> Release gate report"
set +e
./scripts/release-gate-report.sh --json > "$TMP_DIR/release-gate-report.json"
gate_status=$?
set -e

python3 - "$TMP_DIR/release-gate-report.json" "$gate_status" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
status = int(sys.argv[2])
errors = payload.get("errors", [])
manual = payload.get("manual_validation", {})

if status not in (0, 1):
    raise SystemExit(f"release-gate-report exited with unexpected status {status}")
if errors:
    raise SystemExit("release-gate-report metadata errors: " + "; ".join(errors))
if manual.get("closed_gate_evidence_error_count", 0) != 0:
    details = "; ".join(manual.get("closed_gate_evidence_errors", []))
    raise SystemExit("closed manual gate evidence errors: " + details)

if payload.get("ok"):
    print("Release gates are fully closed.")
else:
    print("Automated checks passed; manual release gates remain open.")
    print(f"- Open manual gates: {manual.get('open_gate_count', 0)}")
    for gate_id in manual.get("open_gates", []):
        print(f"  - {gate_id}")
    print(f"- Open checklist items: {payload.get('release_checklist', {}).get('open_item_count', 0)}")
    print(f"- Open release-state questions: {payload.get('release_state', {}).get('open_question_count', 0)}")
PY

echo
echo "Public beta local automated checks passed."
