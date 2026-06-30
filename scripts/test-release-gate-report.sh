#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lac-release-gate.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/scripts" "$TMP_DIR/docs/release"
cp "$ROOT/scripts/release-gate-report.sh" "$TMP_DIR/scripts/release-gate-report.sh"
cp "$ROOT/docs/release/gates.json" "$TMP_DIR/docs/release/gates.json"
cp "$ROOT/docs/release/MANUAL_VALIDATION.md" "$TMP_DIR/docs/release/MANUAL_VALIDATION.md"
cp "$ROOT/docs/release/STATE.md" "$TMP_DIR/docs/release/STATE.md"
cp "$ROOT/RELEASE_CHECKLIST.md" "$TMP_DIR/RELEASE_CHECKLIST.md"
chmod +x "$TMP_DIR/scripts/release-gate-report.sh"

python3 - "$TMP_DIR" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
manual_path = root / "docs/release/MANUAL_VALIDATION.md"
checklist_path = root / "RELEASE_CHECKLIST.md"
state_path = root / "docs/release/STATE.md"
gates_path = root / "docs/release/gates.json"

gates = [gate["id"] for gate in json.loads(gates_path.read_text(encoding="utf-8"))["gates"]]
manual = manual_path.read_text(encoding="utf-8")


def close_gate_row(match: re.Match) -> str:
    gate_id = match.group(1)
    if gate_id not in gates:
        return match.group(0)
    return f"| `{gate_id}` | closed | {match.group(3).strip()} | {match.group(4).strip()} |"


manual = re.sub(r"^\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*(.+?)\s*\|$", close_gate_row, manual, flags=re.MULTILINE)

existing_sections = set(re.findall(r"^### Gate:\s*([A-Za-z0-9._-]+)\s*$", manual, flags=re.MULTILINE))
for gate_id in gates:
    if gate_id in existing_sections:
        continue
    manual += f"""

### Gate: {gate_id}

- Status: closed
- Date: 2099-01-01
- Tester: release-gate self-test
- Environment: synthetic temp fixture
- Commands:
  - `true`
- Result: passed
- Evidence:
  - Synthetic evidence used only to validate release-gate-report parsing.
- Notes: This is not release evidence.
"""
manual_path.write_text(manual, encoding="utf-8")

checklist = checklist_path.read_text(encoding="utf-8").replace("- [ ]", "- [x]")
checklist_path.write_text(checklist, encoding="utf-8")

state = state_path.read_text(encoding="utf-8")
state = re.sub(r"^- \[ \] ", "- [x] ", state, flags=re.MULTILINE)
state_path.write_text(state, encoding="utf-8")
PY

"$TMP_DIR/scripts/release-gate-report.sh" --json > "$TMP_DIR/pass.json"
python3 - "$TMP_DIR/pass.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert payload["ok"] is True, payload
assert payload["manual_validation"]["open_gate_count"] == 0, payload
assert payload["manual_validation"]["closed_gate_evidence_error_count"] == 0, payload
assert payload["release_checklist"]["open_item_count"] == 0, payload
assert payload["release_state"]["open_question_count"] == 0, payload
PY

python3 - "$TMP_DIR" <<'PY'
import re
import sys
from pathlib import Path

manual_path = Path(sys.argv[1]) / "docs/release/MANUAL_VALIDATION.md"
manual = manual_path.read_text(encoding="utf-8")
manual = re.sub(
    r"\n### Gate:\s*security-pvr\n.*?(?=\n### Gate:|\Z)",
    "",
    manual,
    count=1,
    flags=re.DOTALL,
)
manual_path.write_text(manual, encoding="utf-8")
PY

if "$TMP_DIR/scripts/release-gate-report.sh" --json > "$TMP_DIR/fail.json"; then
  echo "[FAIL] release-gate-report passed despite missing closed-gate evidence" >&2
  exit 1
fi

python3 - "$TMP_DIR/fail.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
errors = payload["manual_validation"]["closed_gate_evidence_errors"]
assert any("security-pvr" in error and "missing" in error for error in errors), payload
PY

echo "Release gate report self-test passed."
