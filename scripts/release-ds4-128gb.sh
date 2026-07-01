#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAC="$ROOT/bin/lac"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$ROOT/state/release-evidence/ds4-128gb-$STAMP"
BASE_URL="${DS4_SMOKE_URL:-http://127.0.0.1:8000}"
TIMEOUT="${DS4_SMOKE_TIMEOUT:-10}"
FULL_RUNTIME=0
ALLOW_MISSING_DS4=0
OPEN_OPENCODE=0

usage() {
  cat <<'EOF'
Usage: scripts/release-ds4-128gb.sh [options]

Capture ds4/DwarfStar DeepSeek V4 Flash evidence for the public-beta manual
gate. Dry-run mode validates lac's ds4 profile/config/state paths without
downloading the model or starting the runtime. Full-runtime mode is intended
only for a 128GB+ M3/M4/M5 Apple Silicon machine with antirez/ds4 built.

Options:
  --dry-run              Validate config/status only; no download or runtime
                         start. This is the default behavior.
  --full-runtime         Run model sync, start ds4, and probe /v1/models.
  --open                 Launch OpenCode after full-runtime evidence capture.
  --url <base-url>       ds4 base URL (default: http://127.0.0.1:8000)
  --timeout <seconds>    curl timeout for /v1/models (default: 10)
  --evidence-dir <dir>   Directory for summary and evidence files
  --allow-missing-ds4    Allow dry-run rehearsal when ds4-server is not built
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      FULL_RUNTIME=0
      shift
      ;;
    --full-runtime)
      FULL_RUNTIME=1
      shift
      ;;
    --open)
      OPEN_OPENCODE=1
      shift
      ;;
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
    --allow-missing-ds4)
      ALLOW_MISSING_DS4=1
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
if [[ "$FULL_RUNTIME" -eq 1 && "$ALLOW_MISSING_DS4" -eq 1 ]]; then
  echo "--allow-missing-ds4 is only valid with dry-run rehearsal." >&2
  exit 2
fi
if [[ "$OPEN_OPENCODE" -eq 1 && "$FULL_RUNTIME" -eq 0 ]]; then
  echo "--open is only valid with --full-runtime." >&2
  exit 2
fi
if [[ "$FULL_RUNTIME" -eq 1 ]] && ! command -v curl >/dev/null 2>&1; then
  echo "curl is required for full ds4 runtime evidence." >&2
  exit 2
fi

mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/commands.log"
PROFILE_JSON="$EVIDENCE_DIR/profile-128gb-ds4-flash.json"
RENDER_JSON="$EVIDENCE_DIR/render-opencode.json"
OPENCODE_CONFIG="$EVIDENCE_DIR/opencode.json"
RUNTIME_STATUS_DRY="$EVIDENCE_DIR/runtime-status-dry.json"
DS4_BINARY="$EVIDENCE_DIR/ds4-binary.txt"
DS4_MISSING="$EVIDENCE_DIR/ds4-missing.txt"
HARDWARE_JSON="$EVIDENCE_DIR/hardware.json"
EXPECTED_COMMAND="$EVIDENCE_DIR/expected-ds4-command.txt"
OPEN_SESSION="$EVIDENCE_DIR/opencode-session.txt"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lac-ds4-128gb.XXXXXX")"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [[ "$FULL_RUNTIME" -eq 1 ]]; then
  STATE_ROOT="${LAC_STATE_ROOT:-$ROOT/state}"
  MODELS_DIR="${AI_MODELS_DIR:-$ROOT/models}"
else
  STATE_ROOT="$TMP_DIR/state"
  MODELS_DIR="$TMP_DIR/models"
fi
LAC_ENV=(env "LAC_STATE_ROOT=$STATE_ROOT" "AI_MODELS_DIR=$MODELS_DIR" "AI_LOCAL_RUNTIME=auto")

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

run_text_allow_failure() {
  local output="$1"
  shift
  log_cmd "$@" >/dev/null
  set +e
  "$@" >"$output" 2>>"$LOG"
  local status=$?
  set -e
  echo "$status"
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

resolve_ds4_bin() {
  local configured="${DS4_BIN:-ds4-server}"
  if [[ -x "$configured" ]]; then
    printf '%s\n' "$configured"
    return 0
  fi
  command -v "$configured" 2>/dev/null || return 1
}

echo "ds4/DwarfStar 128GB release evidence"
echo "- Evidence directory: $EVIDENCE_DIR"
echo "- State root: $STATE_ROOT"
echo "- Models dir: $MODELS_DIR"
echo "- Runtime URL: $BASE_URL"
if [[ "$FULL_RUNTIME" -eq 1 ]]; then
  echo "- Mode: full runtime"
else
  echo "- Mode: dry-run rehearsal"
fi

run_text date -u
run_text uname -a
run_text "$LAC" --version
run_text git -C "$ROOT" rev-parse HEAD

run_text_allow_failure "$EVIDENCE_DIR/sw_vers.txt" sw_vers >/dev/null
run_text_allow_failure "$EVIDENCE_DIR/hw-memsize.txt" sysctl -n hw.memsize >/dev/null
run_text_allow_failure "$EVIDENCE_DIR/hw-model.txt" sysctl -n hw.model >/dev/null
run_text_allow_failure "$EVIDENCE_DIR/cpu-brand.txt" sysctl -n machdep.cpu.brand_string >/dev/null

ds4_status=0
if ds4_path="$(resolve_ds4_bin)"; then
  {
    printf 'DS4_BIN=%s\n' "${DS4_BIN:-ds4-server}"
    printf 'resolved=%s\n' "$ds4_path"
  } >"$DS4_BINARY"
  run_text_allow_failure "$EVIDENCE_DIR/ds4-ls.txt" ls -l "$ds4_path" >/dev/null
  if command -v shasum >/dev/null 2>&1; then
    run_text_allow_failure "$EVIDENCE_DIR/ds4-sha256.txt" shasum -a 256 "$ds4_path" >/dev/null
  fi
  ds4_dir="$(cd "$(dirname "$ds4_path")" && pwd)"
  if git -C "$ds4_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    run_text_allow_failure "$EVIDENCE_DIR/ds4-commit.txt" git -C "$ds4_dir" rev-parse HEAD >/dev/null
    run_text_allow_failure "$EVIDENCE_DIR/ds4-remote.txt" git -C "$ds4_dir" remote -v >/dev/null
  else
    cat >"$EVIDENCE_DIR/ds4-commit.txt" <<'EOF'
No git checkout was detected next to DS4_BIN. Record the antirez/ds4 commit
used to build this binary before closing the ds4-128gb release gate.
EOF
  fi
else
  ds4_status=127
  cat >"$DS4_MISSING" <<'EOF'
ds4-server was not found.

Build antirez/ds4 on the target machine and make the binary available:

  git clone https://github.com/antirez/ds4
  cd ds4
  make
  export DS4_BIN=$PWD/ds4-server
EOF
  if [[ "$FULL_RUNTIME" -eq 1 || "$ALLOW_MISSING_DS4" -eq 0 ]]; then
    cat "$DS4_MISSING" >&2
    exit 127
  fi
fi

python3 - "$EVIDENCE_DIR" "$FULL_RUNTIME" <<'PY'
import json
import platform
import sys
from pathlib import Path

evidence_dir = Path(sys.argv[1])
full_runtime = sys.argv[2] == "1"

def read_int(path: Path) -> int:
    try:
        return int(path.read_text(encoding="utf-8").strip())
    except Exception:
        return 0

mem_bytes = read_int(evidence_dir / "hw-memsize.txt")
payload = {
    "platform": platform.platform(),
    "machine": platform.machine(),
    "system": platform.system(),
    "mem_bytes": mem_bytes,
    "mem_gib": round(mem_bytes / (1024 ** 3), 2) if mem_bytes else None,
    "meets_128gb_gate": bool(platform.system() == "Darwin" and mem_bytes >= 120 * (1024 ** 3)),
    "full_runtime_requested": full_runtime,
}
(evidence_dir / "hardware.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
if full_runtime and not payload["meets_128gb_gate"]:
    print("Full ds4 release evidence requires 128GB-class Apple Silicon hardware.", file=sys.stderr)
    raise SystemExit(2)
PY

profile_status="$(run_json_allow_failure "$PROFILE_JSON" "${LAC_ENV[@]}" "$LAC" profile apply 128gb-ds4-flash --json)"
render_status="$(run_json_allow_failure "$RENDER_JSON" "${LAC_ENV[@]}" "$LAC" client render opencode --json)"
opencode_config_status="$(run_text_allow_failure "$EVIDENCE_DIR/copy-opencode-config.log" cp "$STATE_ROOT/clients/opencode/opencode.json" "$OPENCODE_CONFIG")"
runtime_status_dry_code="$(run_json_allow_failure "$RUNTIME_STATUS_DRY" "${LAC_ENV[@]}" "$LAC" runtime status --json)"

cat >"$EXPECTED_COMMAND" <<EOF
Expected ds4 launch command shape:

  ${DS4_BIN:-ds4-server} -m ${DS4_MODEL:-$MODELS_DIR/ds4/ds4flash.gguf} --ctx ${DS4_CTX:-100000} --kv-disk-dir $STATE_ROOT/runtime/ds4-kv --kv-disk-space-mb ${DS4_KV_DISK_SPACE_MB:-8192} --host 127.0.0.1 --port ${DS4_PORT:-8000}
EOF

model_sync_status=0
runtime_start_status=0
runtime_status_full_code=0
models_curl_status=0
opencode_open_status=0
if [[ "$FULL_RUNTIME" -eq 1 ]]; then
  model_sync_status="$(run_text_allow_failure "$EVIDENCE_DIR/model-sync.log" "${LAC_ENV[@]}" "$LAC" models sync 128gb-ds4-flash)"
  runtime_start_status="$(run_json_allow_failure "$EVIDENCE_DIR/runtime-start.json" "${LAC_ENV[@]}" "$LAC" runtime start --json)"
  runtime_status_full_code="$(run_json_allow_failure "$EVIDENCE_DIR/runtime-status.json" "${LAC_ENV[@]}" "$LAC" runtime status --json)"
  models_curl_status="$(curl_allow_failure "$EVIDENCE_DIR/models.json" curl -sS -L --max-time "$TIMEOUT" "$BASE_URL/v1/models")"
  run_json_allow_failure "$EVIDENCE_DIR/render-opencode-after-runtime.json" "${LAC_ENV[@]}" "$LAC" client render opencode --json >/dev/null
else
  cat >"$EVIDENCE_DIR/full-runtime-skipped.txt" <<'EOF'
Full ds4 runtime validation was skipped.

Re-run on a 128GB+ M3/M4/M5 Apple Silicon machine with antirez/ds4 built:

  ./scripts/release-ds4-128gb.sh --full-runtime

That mode runs model sync, starts ds4, probes /v1/models, and captures runtime
status for the manual ds4-128gb release gate.
EOF
fi

if [[ "$OPEN_OPENCODE" -eq 1 ]]; then
  opencode_open_status="$(run_text_allow_failure "$EVIDENCE_DIR/opencode-open.log" "${LAC_ENV[@]}" "$LAC" client open opencode)"
  cat >"$OPEN_SESSION" <<'EOF'
OpenCode launch was requested. Record the selected ds4/deepseek-v4-flash model
and attach a screenshot reference, transcript summary, or manual session notes
before closing the ds4-128gb gate.
EOF
else
  cat >"$OPEN_SESSION" <<'EOF'
OpenCode launch was not requested.

Before closing the ds4-128gb gate, launch OpenCode on the same machine, select
the ds4/deepseek-v4-flash model, and record a screenshot reference, transcript
summary, or manual session notes.
EOF
fi

python3 - "$EVIDENCE_DIR" "$BASE_URL" "$ds4_status" "$profile_status" "$render_status" "$opencode_config_status" "$runtime_status_dry_code" "$model_sync_status" "$runtime_start_status" "$runtime_status_full_code" "$models_curl_status" "$opencode_open_status" "$FULL_RUNTIME" "$ALLOW_MISSING_DS4" "$OPEN_OPENCODE" <<'PY'
import json
import sys
from pathlib import Path

evidence_dir = Path(sys.argv[1])
base_url = sys.argv[2]
ds4_status = int(sys.argv[3])
profile_status = int(sys.argv[4])
render_status = int(sys.argv[5])
opencode_config_status = int(sys.argv[6])
runtime_status_dry_code = int(sys.argv[7])
model_sync_status = int(sys.argv[8])
runtime_start_status = int(sys.argv[9])
runtime_status_full_code = int(sys.argv[10])
models_curl_status = int(sys.argv[11])
opencode_open_status = int(sys.argv[12])
full_runtime = sys.argv[13] == "1"
allow_missing_ds4 = sys.argv[14] == "1"
open_opencode = sys.argv[15] == "1"


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return {"_parse_error": str(exc), "_path": path.name}


def first_line(path: Path, default: str = "missing") -> str:
    try:
        text = path.read_text(encoding="utf-8", errors="replace").strip()
    except FileNotFoundError:
        return default
    return text.splitlines()[0] if text else "empty"


profile = load_json(evidence_dir / "profile-128gb-ds4-flash.json")
render = load_json(evidence_dir / "render-opencode.json")
opencode_config = load_json(evidence_dir / "opencode.json")
runtime_dry = load_json(evidence_dir / "runtime-status-dry.json")
hardware = load_json(evidence_dir / "hardware.json")
runtime_full = load_json(evidence_dir / "runtime-status.json") if full_runtime else {}
models = load_json(evidence_dir / "models.json") if full_runtime else {}

opencode_config_path = str(evidence_dir / "opencode.json")
model_count = len(models.get("data", [])) if isinstance(models.get("data"), list) else None
ds4_missing_allowed = ds4_status == 127 and allow_missing_ds4 and not full_runtime
dry_ok = (
    profile_status == 0
    and render_status == 0
    and opencode_config_status == 0
    and runtime_status_dry_code == 0
    and profile.get("profile_id") == "128gb-ds4-flash"
    and opencode_config.get("model") == "ds4/deepseek-v4-flash"
    and opencode_config.get("small_model") == "ds4/deepseek-v4-flash"
    and runtime_dry.get("runtime") == "ds4"
    and runtime_dry.get("port") == 8000
    and str(runtime_dry.get("pid_path", "")).endswith("runtime/ds4.pid")
    and str(runtime_dry.get("log_path", "")).endswith("logs/ds4.log")
    and (ds4_status == 0 or ds4_missing_allowed)
)
full_runtime_ok = (
    full_runtime
    and dry_ok
    and hardware.get("meets_128gb_gate") is True
    and model_sync_status == 0
    and runtime_start_status == 0
    and runtime_status_full_code == 0
    and models_curl_status == 0
    and runtime_full.get("runtime") == "ds4"
    and runtime_full.get("port") == 8000
    and runtime_full.get("health_reachable") is True
    and model_count is not None
)

files = [
    "commands.log",
    "hardware.json",
    "sw_vers.txt",
    "hw-memsize.txt",
    "hw-model.txt",
    "cpu-brand.txt",
    "profile-128gb-ds4-flash.json",
    "render-opencode.json",
    "opencode.json",
    "runtime-status-dry.json",
    "expected-ds4-command.txt",
    "ds4-binary.txt or ds4-missing.txt",
    "ds4-commit.txt",
    "opencode-session.txt",
]
if full_runtime:
    files.extend([
        "model-sync.log",
        "runtime-start.json",
        "runtime-status.json",
        "models.json",
        "render-opencode-after-runtime.json",
    ])
else:
    files.append("full-runtime-skipped.txt")
if open_opencode:
    files.append("opencode-open.log")

lines = [
    "# ds4 128GB Evidence Summary",
    "",
    "- Status: open",
    f"- Mode: {'full runtime' if full_runtime else 'dry-run rehearsal'}",
    f"- Runtime URL: {base_url}",
    f"- Hardware: system={hardware.get('system', 'unknown')} machine={hardware.get('machine', 'unknown')} mem_gib={hardware.get('mem_gib', 'unknown')}",
    f"- 128GB Apple Silicon gate met: {hardware.get('meets_128gb_gate', False)}",
    f"- ds4 binary status: {first_line(evidence_dir / 'ds4-binary.txt', first_line(evidence_dir / 'ds4-missing.txt'))} (exit {ds4_status})",
    f"- ds4 commit/source: {first_line(evidence_dir / 'ds4-commit.txt')}",
    f"- profile apply exit code: {profile_status}",
    f"- OpenCode config copy exit code: {opencode_config_status}",
    f"- rendered model: {opencode_config.get('model', 'unknown')}",
    f"- rendered config path: {opencode_config_path}",
    f"- runtime status exit code: {runtime_status_dry_code}",
    f"- runtime dry path: runtime={runtime_dry.get('runtime', 'unknown')} port={runtime_dry.get('port', 'unknown')} pid={runtime_dry.get('pid_path', 'unknown')} log={runtime_dry.get('log_path', 'unknown')}",
    f"- dry-run preflight complete: {dry_ok}",
    f"- model sync exit code: {model_sync_status if full_runtime else 'skipped'}",
    f"- runtime start exit code: {runtime_start_status if full_runtime else 'skipped'}",
    f"- /v1/models curl exit code: {models_curl_status if full_runtime else 'skipped'}",
    f"- /v1/models count: {model_count if model_count is not None else 'unknown'}",
    f"- OpenCode launch exit code: {opencode_open_status if open_opencode else 'skipped'}",
    f"- full-runtime ds4 smoke complete: {full_runtime_ok}",
    "",
    "## Files",
    "",
]
lines.extend(f"- {name}" for name in files)
lines.append("")

if full_runtime_ok:
    lines.extend([
        "The ds4 runtime smoke passed. Keep the manual `ds4-128gb` gate open",
        "until the tester also records the OpenCode session evidence showing",
        "`ds4/deepseek-v4-flash` selected on the same hardware.",
        "",
    ])
elif full_runtime:
    lines.extend([
        "Full ds4 runtime evidence is incomplete. Keep the manual `ds4-128gb`",
        "gate open and inspect the captured files above.",
        "",
    ])
else:
    lines.extend([
        "This was a dry-run rehearsal. It proves the lac ds4 profile/config",
        "path only; the manual `ds4-128gb` gate remains open until full runtime",
        "evidence is captured on 128GB+ Apple Silicon with antirez/ds4 built.",
        "",
    ])

(evidence_dir / "summary.md").write_text("\n".join(lines), encoding="utf-8")

if not dry_ok:
    raise SystemExit(1)
if full_runtime and not full_runtime_ok:
    raise SystemExit(1)
PY

echo
echo "ds4 128GB evidence captured."
echo "Evidence summary: $EVIDENCE_DIR/summary.md"
if [[ "$FULL_RUNTIME" -eq 0 ]]; then
  echo "Dry-run only. Use --full-runtime on 128GB+ Apple Silicon for release gate evidence."
else
  echo "Keep ds4-128gb open until OpenCode ds4 model-selection notes are attached."
fi
