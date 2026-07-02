#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAC="$ROOT/bin/lac"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$ROOT/state/release-evidence/provider-live-freshness-$STAMP"
TIMEOUT="${LAC_PROVIDER_TIMEOUT:-5}"
REFRESH_CATALOG=0
SKIP_REASONS_FILE=""
SKIP_REASON_ARGS=()

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
  --skip-reason <id=reason>
                       Record an intentional release skip reason for a
                       provider. Repeat for each skipped provider.
  --skip-reasons-file <path>
                       Read release skip reasons from JSON object or
                       line-oriented id=reason file
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
    --skip-reason)
      reason="${2:-}"
      [[ -n "$reason" ]] || { echo "--skip-reason requires id=reason" >&2; exit 2; }
      [[ "$reason" == *=* ]] || { echo "--skip-reason requires id=reason" >&2; exit 2; }
      SKIP_REASON_ARGS+=("$reason")
      shift 2
      ;;
    --skip-reasons-file)
      SKIP_REASONS_FILE="${2:-}"
      [[ -n "$SKIP_REASONS_FILE" ]] || { echo "--skip-reasons-file requires a path" >&2; exit 2; }
      shift 2
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
if [[ -n "$SKIP_REASONS_FILE" || "${#SKIP_REASON_ARGS[@]}" -gt 0 ]]; then
  echo "- Release skip reasons: provided"
else
  echo "- Release skip reasons: none provided"
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

PYTHON_ARGS=(
  "$EVIDENCE_DIR"
  "$provider_list_status"
  "$provider_verify_status"
  "$openrouter_status"
  "$REFRESH_CATALOG"
  "$SKIP_REASONS_FILE"
)
if [[ "${#SKIP_REASON_ARGS[@]}" -gt 0 ]]; then
  PYTHON_ARGS+=("${SKIP_REASON_ARGS[@]}")
fi

python3 - "${PYTHON_ARGS[@]}" <<'PY'
import json
import sys
from pathlib import Path

evidence_dir = Path(sys.argv[1])
provider_list_status = int(sys.argv[2])
provider_verify_status = int(sys.argv[3])
openrouter_status = int(sys.argv[4])
refresh_catalog = sys.argv[5] == "1"
skip_reasons_file = sys.argv[6]
skip_reason_args = sys.argv[7:]


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return {"_parse_error": str(exc), "_path": path.name}


provider_list = load_json(evidence_dir / "provider-list.json")
provider_verify = load_json(evidence_dir / "provider-verify.json")
openrouter_file = evidence_dir / ("openrouter-refresh.json" if refresh_catalog else "openrouter-check.json")
openrouter = load_json(openrouter_file)


def parse_skip_reason_pair(raw: str) -> tuple[str, str]:
    provider_id, reason = raw.split("=", 1)
    provider_id = provider_id.strip()
    reason = reason.strip()
    if not provider_id or not reason:
        raise ValueError(f"invalid skip reason {raw!r}; expected id=reason")
    return provider_id, reason


def load_skip_reasons(path_text: str, pairs: list[str]) -> dict[str, str]:
    reasons: dict[str, str] = {}
    if path_text:
        path = Path(path_text)
        text = path.read_text(encoding="utf-8")
        if path.suffix.lower() == ".json":
            payload = json.loads(text)
            if not isinstance(payload, dict):
                raise ValueError("--skip-reasons-file JSON must be an object mapping provider ids to reasons")
            for provider_id, reason in payload.items():
                provider_id = str(provider_id).strip()
                reason = str(reason).strip()
                if not provider_id or not reason:
                    raise ValueError(f"invalid skip reason in {path}: {provider_id!r}={reason!r}")
                reasons[provider_id] = reason
        else:
            for line in text.splitlines():
                stripped = line.strip()
                if not stripped or stripped.startswith("#"):
                    continue
                provider_id, reason = parse_skip_reason_pair(stripped)
                reasons[provider_id] = reason
    for raw in pairs:
        provider_id, reason = parse_skip_reason_pair(raw)
        reasons[provider_id] = reason
    return reasons


skip_reasons = load_skip_reasons(skip_reasons_file, skip_reason_args)
(evidence_dir / "provider-skip-reasons.json").write_text(
    json.dumps(skip_reasons, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

summary = provider_verify.get("summary", {})
results = provider_verify.get("results", [])
skipped = [record for record in results if record.get("status") == "skipped"]
errors = [record for record in results if record.get("status") == "error"]
ok = [record for record in results if record.get("status") == "ok"]
non_ok_ids = [
    str(record.get("id", ""))
    for record in results
    if record.get("status") != "ok" and record.get("id")
]
missing_skip_reasons = [provider_id for provider_id in non_ok_ids if provider_id not in skip_reasons]
extra_skip_reasons = [provider_id for provider_id in skip_reasons if provider_id not in non_ok_ids]

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
    "- provider-skip-reasons.json",
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

lines.extend(["", "## Documented Release Skip Reasons", ""])
if skip_reasons:
    for provider_id, reason in sorted(skip_reasons.items()):
        lines.append(f"- `{provider_id}`: {reason}")
else:
    lines.append("- None provided.")

lines.extend(["", "## Providers Missing Live Proof Or Release Skip Reasons", ""])
if missing_skip_reasons:
    for provider_id in missing_skip_reasons:
        lines.append(f"- `{provider_id}`")
else:
    lines.append("- None.")

if extra_skip_reasons:
    lines.extend(["", "## Skip Reasons For Already-Verified Providers", ""])
    for provider_id in extra_skip_reasons:
        lines.append(f"- `{provider_id}`")

lines.extend(["", "## Error Providers", ""])
if errors:
    for record in errors:
        lines.append(f"- `{record.get('id')}`: {record.get('reason', 'no reason recorded')}")
else:
    lines.append("- None recorded.")

lines.extend([
    "",
    "Keep the `provider-live-freshness` manual gate open until release",
    "credentials were used for live probes, or each non-OK provider above has",
    "a documented release skip reason in provider-skip-reasons.json.",
    "",
])

(evidence_dir / "summary.md").write_text("\n".join(lines), encoding="utf-8")
PY

echo
echo "Provider freshness evidence captured."
echo "Evidence summary: $EVIDENCE_DIR/summary.md"
echo "Keep provider-live-freshness open until live probes or documented release skips are complete."
