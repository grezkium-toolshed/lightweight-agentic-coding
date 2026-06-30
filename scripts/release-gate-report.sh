#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT" "$@" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
args = sys.argv[2:]
json_mode = "--json" in args

checklist_path = root / "RELEASE_CHECKLIST.md"
gates_path = root / "docs/release/gates.json"
manual_path = root / "docs/release/MANUAL_VALIDATION.md"
state_path = root / "docs/release/STATE.md"

errors = []
for path in (checklist_path, gates_path, manual_path, state_path):
    if not path.is_file():
        errors.append(f"missing required release file: {path.relative_to(root)}")

checklist_text = checklist_path.read_text(encoding="utf-8") if checklist_path.is_file() else ""
gates_manifest = json.loads(gates_path.read_text(encoding="utf-8")) if gates_path.is_file() else {"gates": []}
manual_text = manual_path.read_text(encoding="utf-8") if manual_path.is_file() else ""
state_text = state_path.read_text(encoding="utf-8") if state_path.is_file() else ""

required_gate_ids = {gate.get("id") for gate in gates_manifest.get("gates", []) if gate.get("id")}
if not required_gate_ids:
    errors.append("release gate manifest has no gates")
gate_records = {gate.get("id"): gate for gate in gates_manifest.get("gates", []) if gate.get("id")}

gate_status = {}
for line in manual_text.splitlines():
    match = re.match(r"\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|", line)
    if match:
        gate_status[match.group(1)] = match.group(2).strip().lower()

missing_gate_ids = sorted(required_gate_ids - set(gate_status))
unknown_gate_ids = sorted(set(gate_status) - required_gate_ids)
for gate_id in missing_gate_ids:
    errors.append(f"manual validation file is missing gate `{gate_id}`")
for gate_id in unknown_gate_ids:
    errors.append(f"manual validation file has unknown gate `{gate_id}`")
for gate_id, status in sorted(gate_status.items()):
    if status not in {"open", "closed"}:
        errors.append(f"manual validation gate `{gate_id}` has invalid status `{status}`")

open_manual_gates = sorted(gate_id for gate_id, status in gate_status.items() if status != "closed")
closed_manual_gates = sorted(gate_id for gate_id, status in gate_status.items() if status == "closed")


def parse_evidence_sections(text):
    sections = {}
    current_gate = None
    current_lines = []
    for line in text.splitlines():
        gate_heading = re.match(r"^### Gate:\s*([A-Za-z0-9._-]+)\s*$", line)
        if gate_heading:
            if current_gate:
                sections[current_gate] = current_lines
            current_gate = gate_heading.group(1)
            current_lines = []
            continue
        if current_gate and line.startswith("### "):
            sections[current_gate] = current_lines
            current_gate = None
            current_lines = []
            continue
        if current_gate:
            current_lines.append(line)
    if current_gate:
        sections[current_gate] = current_lines
    return sections


def parse_evidence_fields(lines):
    fields = {}
    current_field = None
    for line in lines:
        field = re.match(r"^-\s+([A-Za-z][A-Za-z ]*):\s*(.*)$", line)
        if field:
            current_field = field.group(1).strip().lower()
            value = field.group(2).strip()
            fields[current_field] = [value] if value else []
            continue
        if current_field and line.strip():
            fields[current_field].append(line.strip())
    return {key: "\n".join(value).strip() for key, value in fields.items()}


evidence_sections = parse_evidence_sections(manual_text)
required_evidence_fields = ["status", "date", "tester", "environment", "commands", "result", "evidence", "notes"]
closed_gate_evidence_errors = []
for gate_id in sorted(set(evidence_sections) - required_gate_ids):
    closed_gate_evidence_errors.append(f"manual validation file has evidence section for unknown gate `{gate_id}`")
for gate_id in closed_manual_gates:
    section = evidence_sections.get(gate_id)
    if section is None:
        closed_gate_evidence_errors.append(f"closed gate `{gate_id}` is missing a `### Gate: {gate_id}` evidence section")
        continue
    fields = parse_evidence_fields(section)
    for field in required_evidence_fields:
        if field not in fields:
            closed_gate_evidence_errors.append(f"closed gate `{gate_id}` evidence section is missing `{field.title()}`")
        elif not fields[field]:
            closed_gate_evidence_errors.append(f"closed gate `{gate_id}` evidence field `{field.title()}` is empty")
    if fields.get("status", "").lower() != "closed":
        closed_gate_evidence_errors.append(f"closed gate `{gate_id}` evidence section must say `Status: closed`")
errors.extend(closed_gate_evidence_errors)

open_checklist = []
checklist_status = {}
current_section = ""
for line in checklist_text.splitlines():
    heading = re.match(r"^##\s+(.+)$", line)
    if heading:
        current_section = heading.group(1).strip()
    item = re.match(r"^- \[([ xX])\]\s+(.+)$", line)
    if item:
        is_checked = item.group(1).lower() == "x"
        item_text = item.group(2).strip()
        checklist_status[(current_section, item_text)] = is_checked
    item = re.match(r"^- \[ \]\s+(.+)$", line)
    if item:
        open_checklist.append({
            "section": current_section,
            "item": item.group(1).strip(),
        })

gate_checklist_errors = []
gate_checklist_mismatches = []
for gate_id, gate in sorted(gate_records.items()):
    refs = gate.get("checklist_refs")
    if not isinstance(refs, list) or not refs:
        gate_checklist_errors.append(f"release gate `{gate_id}` is missing checklist_refs")
        continue
    for ref in refs:
        section = ref.get("section") if isinstance(ref, dict) else None
        item = ref.get("item") if isinstance(ref, dict) else None
        if not section or not item:
            gate_checklist_errors.append(f"release gate `{gate_id}` has malformed checklist_ref")
            continue
        key = (section, item)
        if key not in checklist_status:
            gate_checklist_errors.append(f"release gate `{gate_id}` references missing checklist item `{section}: {item}`")
            continue
        if gate_id in closed_manual_gates and not checklist_status[key]:
            gate_checklist_mismatches.append(f"closed gate `{gate_id}` still has open checklist item `{section}: {item}`")
errors.extend(gate_checklist_errors)
errors.extend(gate_checklist_mismatches)

open_state_questions = []
in_open_questions = False
for line in state_text.splitlines():
    if line.startswith("### "):
        in_open_questions = line.strip() == "### Open Questions"
        continue
    if in_open_questions:
        item = re.match(r"^- \[ \]\s+(.+)$", line)
        if item:
            open_state_questions.append(item.group(1).strip())

payload = {
    "ok": not errors and not open_manual_gates and not open_checklist and not open_state_questions,
    "gate_manifest": {
        "path": str(gates_path.relative_to(root)),
        "gate_count": len(required_gate_ids),
    },
    "manual_validation": {
        "path": str(manual_path.relative_to(root)),
        "open_gate_count": len(open_manual_gates),
        "open_gates": open_manual_gates,
        "closed_gate_count": len(closed_manual_gates),
        "closed_gates": closed_manual_gates,
        "closed_gate_evidence_error_count": len(closed_gate_evidence_errors),
        "closed_gate_evidence_errors": closed_gate_evidence_errors,
    },
    "release_checklist": {
        "path": str(checklist_path.relative_to(root)),
        "open_item_count": len(open_checklist),
        "open_items": open_checklist,
        "gate_checklist_error_count": len(gate_checklist_errors),
        "gate_checklist_errors": gate_checklist_errors,
        "gate_checklist_mismatch_count": len(gate_checklist_mismatches),
        "gate_checklist_mismatches": gate_checklist_mismatches,
    },
    "release_state": {
        "path": str(state_path.relative_to(root)),
        "open_question_count": len(open_state_questions),
        "open_questions": open_state_questions,
    },
    "errors": errors,
}

if json_mode:
    print(json.dumps(payload, indent=2))
else:
    print("Public beta release gate report")
    print(f"- Manual validation gates open: {len(open_manual_gates)}")
    for gate_id in open_manual_gates:
        print(f"  - {gate_id}")
    print(f"- Closed gate evidence errors: {len(closed_gate_evidence_errors)}")
    for error in closed_gate_evidence_errors:
        print(f"  - {error}")
    print(f"- Release checklist items open: {len(open_checklist)}")
    for item in open_checklist:
        print(f"  - {item['section']}: {item['item']}")
    print(f"- Gate/checklist metadata errors: {len(gate_checklist_errors)}")
    for error in gate_checklist_errors:
        print(f"  - {error}")
    print(f"- Closed gate/checklist mismatches: {len(gate_checklist_mismatches)}")
    for error in gate_checklist_mismatches:
        print(f"  - {error}")
    print(f"- Release state questions open: {len(open_state_questions)}")
    for question in open_state_questions:
        print(f"  - {question}")
    if errors:
        print("- Metadata errors:")
        for error in errors:
            print(f"  - {error}")
    if payload["ok"]:
        print("Release gates are closed.")
    else:
        print("Release gates are still open; do not publish public beta yet.")

raise SystemExit(0 if payload["ok"] else 1)
PY
