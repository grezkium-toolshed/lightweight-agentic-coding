#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAC="$ROOT/bin/lac"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$ROOT/state/release-evidence/llama-smoke-$STAMP"
BASE_URL="${LLAMA_SMOKE_URL:-http://127.0.0.1:8080}"
TIMEOUT="${LLAMA_SMOKE_TIMEOUT:-10}"
ALLOW_UNAVAILABLE=0

usage() {
  cat <<'EOF'
Usage: scripts/release-llama-smoke.sh [options]

Capture llama.cpp runtime smoke evidence for the public-beta release gate.
Release mode expects a running llama.cpp-compatible endpoint and fails if
/health, /v1/models, or `lac smoke --json` fail.

Options:
  --url <base-url>     Runtime base URL (default: http://127.0.0.1:8080)
  --timeout <seconds>  curl/lac smoke timeout (default: 10)
  --evidence-dir <dir> Directory for summary and JSON evidence files
  --allow-unavailable Allow local rehearsal to pass when runtime is down
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      BASE_URL="${2:-}"
      [[ -n "$BASE_URL" ]] || { echo "--url requires a value" >&2; exit 2; }
      shift 2
      ;;
    --timeout)
      TIMEOUT="${2:-}"
      [[ -n "$TIMEOUT" ]] || { echo "--timeout requires a value" >&2; exit 2; }
      shift 2
      ;;
    --evidence-dir)
      EVIDENCE_DIR="${2:-}"
      [[ -n "$EVIDENCE_DIR" ]] || { echo "--evidence-dir requires a value" >&2; exit 2; }
      shift 2
      ;;
    --allow-unavailable)
      ALLOW_UNAVAILABLE=1
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
if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required for llama smoke evidence." >&2
  exit 2
fi

mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/commands.log"
HEALTH_HEADERS="$EVIDENCE_DIR/health.headers.txt"
HEALTH_BODY="$EVIDENCE_DIR/health.body"
MODELS_BODY="$EVIDENCE_DIR/models.json"
RUNTIME_STATUS="$EVIDENCE_DIR/runtime-status.json"
SMOKE_JSON="$EVIDENCE_DIR/lac-smoke.json"

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

curl_allow_failure() {
  local output="$1"
  shift
  log_cmd "$@" >/dev/null
  set +e
  "$@" >"$output" 2>>"$LOG"
  local status=$?
  set -e
  echo "$status"
}

echo "llama.cpp runtime smoke evidence"
echo "- Evidence directory: $EVIDENCE_DIR"
echo "- Runtime URL: $BASE_URL"
echo "- Timeout: $TIMEOUT seconds"
if [[ "$ALLOW_UNAVAILABLE" -eq 1 ]]; then
  echo "- Mode: local rehearsal; unavailable runtime is allowed"
else
  echo "- Mode: release evidence; runtime must be reachable"
fi

run_text date -u
run_text uname -a
run_text "$LAC" --version
run_text git -C "$ROOT" rev-parse HEAD

runtime_status_code="$(run_json_allow_failure "$RUNTIME_STATUS" "$LAC" runtime status --json)"
health_status_code="$(curl_allow_failure "$HEALTH_BODY" curl -sS -L --max-time "$TIMEOUT" -D "$HEALTH_HEADERS" "$BASE_URL/health")"
models_status_code="$(curl_allow_failure "$MODELS_BODY" curl -sS -L --max-time "$TIMEOUT" "$BASE_URL/v1/models")"
smoke_status_code="$(run_json_allow_failure "$SMOKE_JSON" "$LAC" smoke --timeout "$TIMEOUT" --json)"

set +e
python3 - "$EVIDENCE_DIR" "$BASE_URL" "$runtime_status_code" "$health_status_code" "$models_status_code" "$smoke_status_code" "$ALLOW_UNAVAILABLE" <<'PY'
import json
import re
import sys
from pathlib import Path

evidence_dir = Path(sys.argv[1])
base_url = sys.argv[2]
runtime_status_code = int(sys.argv[3])
health_status_code = int(sys.argv[4])
models_status_code = int(sys.argv[5])
smoke_status_code = int(sys.argv[6])
allow_unavailable = sys.argv[7] == "1"


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return {"_parse_error": str(exc), "_path": path.name}


def first_http_status(headers_path: Path):
    try:
        for line in headers_path.read_text(encoding="utf-8", errors="replace").splitlines():
            match = re.match(r"HTTP/\S+\s+(\d+)", line)
            if match:
                return int(match.group(1))
    except FileNotFoundError:
        return None
    return None


runtime = load_json(evidence_dir / "runtime-status.json")
models = load_json(evidence_dir / "models.json")
smoke = load_json(evidence_dir / "lac-smoke.json")
health_http = first_http_status(evidence_dir / "health.headers.txt")

model_count = None
if isinstance(models.get("data"), list):
    model_count = len(models["data"])

runtime_reachable = bool(runtime.get("health_reachable") or runtime.get("running"))
release_ready = (
    runtime_status_code == 0
    and health_status_code == 0
    and (health_http is None or 200 <= health_http < 300)
    and models_status_code == 0
    and smoke_status_code == 0
    and smoke.get("ok") is True
)

lines = [
    "# llama.cpp Smoke Evidence Summary",
    "",
    "- Status: open",
    f"- Runtime URL: {base_url}",
    f"- Runtime status exit code: {runtime_status_code}",
    f"- Health curl exit code: {health_status_code}",
    f"- Health HTTP status: {health_http if health_http is not None else 'unknown'}",
    f"- Models curl exit code: {models_status_code}",
    f"- lac smoke exit code: {smoke_status_code}",
    f"- lac smoke ok: {smoke.get('ok', False)}",
    f"- Model count: {model_count if model_count is not None else 'unknown'}",
    f"- Runtime reachable/running: {runtime_reachable}",
    f"- Release-ready smoke: {release_ready}",
    "",
    "## Files",
    "",
    "- commands.log",
    "- runtime-status.json",
    "- health.headers.txt",
    "- health.body",
    "- models.json",
    "- lac-smoke.json",
    "",
]

if not release_ready:
    if allow_unavailable:
        lines.extend([
            "This was a local rehearsal with `--allow-unavailable`; the manual",
            "`llama-smoke` gate remains open until the release tester reruns the",
            "helper without that flag against a running llama.cpp endpoint.",
            "",
        ])
    else:
        lines.extend([
            "Release smoke did not pass. Keep the manual `llama-smoke` gate open",
            "and inspect the captured files above.",
            "",
        ])
else:
    lines.extend([
        "Release smoke passed. Paste this summary into",
        "`docs/release/MANUAL_VALIDATION.md` before closing the `llama-smoke` gate.",
        "",
    ])

(evidence_dir / "summary.md").write_text("\n".join(lines), encoding="utf-8")

if not release_ready and not allow_unavailable:
    raise SystemExit(1)
PY
summary_status=$?
set -e

echo
echo "llama smoke evidence captured."
echo "Evidence summary: $EVIDENCE_DIR/summary.md"
if [[ "$summary_status" -ne 0 ]]; then
  exit "$summary_status"
fi
if [[ "$ALLOW_UNAVAILABLE" -eq 1 ]]; then
  echo "Runtime availability was allowed for rehearsal. Use release mode for gate evidence."
fi
