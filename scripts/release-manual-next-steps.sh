#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT" "$@" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
args = sys.argv[2:]
json_mode = "--json" in args

gates_path = root / "docs/release/gates.json"
manual_path = root / "docs/release/MANUAL_VALIDATION.md"
if not gates_path.is_file():
    raise SystemExit(f"missing release gate manifest: {gates_path.relative_to(root)}")
if not manual_path.is_file():
    raise SystemExit(f"missing manual validation file: {manual_path.relative_to(root)}")

gates_manifest = json.loads(gates_path.read_text(encoding="utf-8"))
gate_metadata = {gate["id"]: gate for gate in gates_manifest.get("gates", [])}
open_gates = []
for line in manual_path.read_text(encoding="utf-8").splitlines():
    if not line.startswith("| `"):
        continue
    columns = [cell.strip() for cell in line.strip().split("|")[1:-1]]
    if len(columns) != 4:
        continue
    gate_id = columns[0].strip("`")
    status = columns[1].lower()
    owner = columns[2]
    evidence = columns[3]
    if gate_id == "Gate ID" or status == "status":
        continue
    if status != "closed":
        metadata = gate_metadata.get(gate_id, {})
        open_gates.append({
            "gate_id": gate_id,
            "status": status,
            "owner": metadata.get("owner", owner),
            "summary": metadata.get("summary", ""),
            "evidence_required": metadata.get("evidence_required", evidence),
        })

payload = {
    "gate_manifest": str(gates_path.relative_to(root)),
    "manual_validation": str(manual_path.relative_to(root)),
    "open_gate_count": len(open_gates),
    "open_gates": open_gates,
}

if json_mode:
    print(json.dumps(payload, indent=2))
else:
    print("Public beta manual validation next steps")
    print(f"- Open manual gates: {len(open_gates)}")
    for gate in open_gates:
        print(f"  - {gate['gate_id']} ({gate['owner']}): {gate['evidence_required']}")
    print("Use ./scripts/release-evidence.sh <gate-id> for command bundles, update docs/release/MANUAL_VALIDATION.md, then rerun ./scripts/release-gate-report.sh.")
PY
