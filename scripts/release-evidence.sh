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
args = [arg for arg in args if arg != "--json"]

gates_manifest_path = root / "docs/release/gates.json"
gates_manifest = json.loads(gates_manifest_path.read_text(encoding="utf-8"))
GATES = {gate["id"]: gate for gate in gates_manifest["gates"]}


def usage() -> None:
    print("Usage: scripts/release-evidence.sh [--json] <gate-id|list>")
    print()
    print("Known gates:")
    for gate_id in sorted(GATES):
        print(f"  - {gate_id}")


def payload_for(gate_id: str) -> dict:
    gate = GATES[gate_id]
    gate_payload = {key: value for key, value in gate.items() if key != "id"}
    return {
        "gate_id": gate_id,
        "manual_validation": gates_manifest["manual_validation"],
        "release_checklist": gates_manifest["release_checklist"],
        **gate_payload,
    }


def print_gate(gate_id: str) -> None:
    gate = payload_for(gate_id)
    print(f"Release evidence: {gate_id}")
    print(f"- Owner: {gate['owner']}")
    print(f"- Summary: {gate['summary']}")
    print()
    print("Environment:")
    for item in gate["environment"]:
        print(f"- {item}")
    print()
    print("Commands:")
    for command in gate["commands"]:
        print(f"- `{command}`")
    print()
    print("Evidence to paste into docs/release/MANUAL_VALIDATION.md:")
    for item in gate["evidence"]:
        print(f"- {item}")
    print()
    print("Paste-ready evidence stub:")
    print("```markdown")
    print(f"### Gate: {gate_id}")
    print()
    print("- Status: open")
    print("- Date:")
    print("- Tester:")
    print("- Environment:")
    print("- Commands:")
    for command in gate["commands"]:
        print(f"  - `{command}`")
    print("- Result:")
    print("- Evidence:")
    for item in gate["evidence"]:
        print(f"  - {item}")
    print("- Notes:")
    print("```")
    print()
    print("Keep this stub at Status: open while evidence is incomplete. After evidence is complete, mark the gate closed in docs/release/MANUAL_VALIDATION.md, check the matching RELEASE_CHECKLIST.md item, then run ./scripts/release-gate-report.sh.")


if not args or args[0] in ("-h", "--help"):
    usage()
    raise SystemExit(0 if args else 2)

target = args[0]
if target == "list":
    if json_mode:
        print(json.dumps({"gates": sorted(GATES)}, indent=2))
    else:
        usage()
    raise SystemExit(0)

if target not in GATES:
    print(f"Unknown release gate: {target}", file=sys.stderr)
    usage()
    raise SystemExit(2)

if json_mode:
    print(json.dumps(payload_for(target), indent=2))
else:
    print_gate(target)
PY
