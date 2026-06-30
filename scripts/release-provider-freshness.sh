#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAC="$ROOT/bin/lac"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$ROOT/state/release-evidence/provider-live-freshness-$STAMP"
TIMEOUT="${LAC_PROVIDER_TIMEOUT:-5}"
REFRESH_CATALOG=0

usage() {
  cat <<'EOF'
Usage: scripts/release-provider-freshness.sh [options]

Capture provider freshness evidence for the public-beta release gate. This
script records JSON outputs and skip reasons without printing secret values.
Keep the manual gate open until live provider probes are complete with release
credentials, or every skipped provider has a documented release skip reason.

Options:
  --evidence-dir <dir> Directory for summary and JSON evidence files
  --timeout <seconds>  Per-provider request timeout (default: 5)
  --refresh-catalog    Run OpenRouter with --refresh-catalog; may update
                       catalog/providers.json on a successful live probe
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --evidence-dir)
      EVIDENCE_DIR="${2:-}"
      [[ -n "$EVIDENCE_DIR" ]] || { echo "--evidence-dir requires a value" >&2; exit 2; }
      shift 2
      ;;
    --timeout)
      TIMEOUT="${2:-}"
      [[ -n "$TIMEOUT" ]] || { echo "--timeout requires a value" >&2; exit 2; }
      shift 2
      ;;
    --refresh-catalog)
      REFRESH_CATALOG=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -x "$LAC" ]]; then
  echo "Missing lac wrapper: $LAC" >&2
  exit 2
fi

mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/commands.log"

log_cmd() {
  {
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  } | tee -a "$LOG"
}

run_text() {
  log_cmd "$@"
  "$@" 2>&1 | tee -a "$LOG"
}

run_json_allow_failure() {
  local output="$1"
  shift
  log_cmd "$@" >/dev/null
  set +e
  "$@" >"$output" 2>>"$LOG"
  local status=$?
  set -e
  echo "$status"
}

echo "Provider freshness release evidence"
echo "- Evidence directory: $EVIDENCE_DIR"
echo "- Timeout: $TIMEOUT seconds"
if [[ "$REFRESH_CATALOG" -eq 1 ]]; then
  echo "- OpenRouter catalog refresh: enabled"
else
  echo "- OpenRouter catalog refresh: skipped (pass --refresh-catalog for release credentials)"
fi

run_text date -u
run_text uname -a
run_text "$LAC" --version
run_text git -C "$ROOT" rev-parse HEAD

provider_list_status="$(run_json_allow_failure "$EVIDENCE_DIR/provider-list.json" "$LAC" provider list --json)"
provider_verify_status="$(run_json_allow_failure "$EVIDENCE_DIR/provider-verify.json" "$LAC" provider verify --all --timeout "$TIMEOUT" --json)"

if [[ "$REFRESH_CATALOG" -eq 1 ]]; then
  openrouter_status="$(run_json_allow_failure "$EVIDENCE_DIR/openrouter-refresh.json" "$LAC" provider verify openrouter --refresh-catalog --timeout "$TIMEOUT" --json)"
else
  openrouter_status="$(run_json_allow_failure "$EVIDENCE_DIR/openrouter-check.json" "$LAC" provider verify openrouter --timeout "$TIMEOUT" --json)"
  cat >"$EVIDENCE_DIR/openrouter-refresh-skipped.txt" <<'EOF'
OpenRouter catalog refresh was skipped.

Re-run with release credentials and:

  ./scripts/release-provider-freshness.sh --refresh-catalog

Only use --refresh-catalog when updating catalog/providers.json is intended.
EOF
fi

python3 - "$EVIDENCE_DIR" "$provider_list_status" "$provider_verify_status" "$openrouter_status" "$REFRESH_CATALOG" <<'PY'
import json
import sys
from pathlib import Path

evidence_dir = Path(sys.argv[1])
provider_list_status = int(sys.argv[2])
provider_verify_status = int(sys.argv[3])
openrouter_status = int(sys.argv[4])
refresh_catalog = sys.argv[5] == "1"


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return {"_parse_error": str(exc), "_path": path.name}


provider_list = load_json(evidence_dir / "provider-list.json")
provider_verify = load_json(evidence_dir / "provider-verify.json")
openrouter_file = evidence_dir / ("openrouter-refresh.json" if refresh_catalog else "openrouter-check.json")
openrouter = load_json(openrouter_file)

summary = provider_verify.get("summary", {})
results = provider_verify.get("results", [])
skipped = [record for record in results if record.get("status") == "skipped"]
errors = [record for record in results if record.get("status") == "error"]
ok = [record for record in results if record.get("status") == "ok"]

lines = [
    "# Provider Freshness Evidence Summary",
    "",
    "- Status: open",
    f"- Provider list exit code: {provider_list_status}",
    f"- Provider verify exit code: {provider_verify_status}",
    f"- OpenRouter {'refresh' if refresh_catalog else 'check'} exit code: {openrouter_status}",
    f"- Providers listed: {len(provider_list) if isinstance(provider_list, list) else 'unknown'}",
    f"- Verify summary: ok={summary.get('ok', 0)} skipped={summary.get('skipped', 0)} error={summary.get('error', 0)} total={summary.get('total', 0)}",
    f"- OpenRouter status: {openrouter.get('status', 'unknown')}",
    "",
    "## Files",
    "",
    "- commands.log",
    "- provider-list.json",
    "- provider-verify.json",
    f"- {openrouter_file.name}",
]
if not refresh_catalog:
    lines.append("- openrouter-refresh-skipped.txt")

lines.extend(["", "## OK Providers", ""])
if ok:
    for record in ok:
        lines.append(f"- `{record.get('id')}` verified at {record.get('verified_at', 'unknown')}")
else:
    lines.append("- None recorded.")

lines.extend(["", "## Skipped Providers", ""])
if skipped:
    for record in skipped:
        lines.append(f"- `{record.get('id')}`: {record.get('reason', 'no reason recorded')}")
else:
    lines.append("- None recorded.")

lines.extend(["", "## Error Providers", ""])
if errors:
    for record in errors:
        lines.append(f"- `{record.get('id')}`: {record.get('reason', 'no reason recorded')}")
else:
    lines.append("- None recorded.")

lines.extend([
    "",
    "Keep the `provider-live-freshness` manual gate open until release",
    "credentials were used for live probes, or each skipped provider above has",
    "a documented release skip reason.",
    "",
])

(evidence_dir / "summary.md").write_text("\n".join(lines), encoding="utf-8")
PY

echo
echo "Provider freshness evidence captured."
echo "Evidence summary: $EVIDENCE_DIR/summary.md"
echo "Keep provider-live-freshness open until live probes or documented release skips are complete."
