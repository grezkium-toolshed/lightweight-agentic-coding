#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PROFILE="24gb"
PYTHON_BIN="${PYTHON:-}"
FULL_RUNTIME=0
KEEP_TMP=0
EVIDENCE_DIR=""
ALLOW_UNSUPPORTED_PYTHON=0

usage() {
  cat <<'EOF'
Usage: scripts/release-fresh-clone-unix.sh [options]

Run the Unix public-beta onboarding smoke from the current checkout. For the
release gate, run this script from a fresh macOS/Linux clone and pass
--full-runtime to include model sync and runtime startup.

Options:
  --profile <id>       Profile to apply and optionally sync (default: 24gb)
  --python <path>      Python executable used to create the isolated venv
  --evidence-dir <dir> Directory for summary and JSON evidence files
  --full-runtime       Also run models sync, runtime start/status, and stop
  --allow-unsupported-python
                       Allow Python < 3.10 for local no-download rehearsal only
  --keep-tmp           Keep the temporary venv/state/models directory
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="${2:-}"
      [[ -n "$PROFILE" ]] || { echo "--profile requires a value" >&2; exit 2; }
      shift 2
      ;;
    --python)
      PYTHON_BIN="${2:-}"
      [[ -n "$PYTHON_BIN" ]] || { echo "--python requires a value" >&2; exit 2; }
      shift 2
      ;;
    --evidence-dir)
      EVIDENCE_DIR="${2:-}"
      [[ -n "$EVIDENCE_DIR" ]] || { echo "--evidence-dir requires a value" >&2; exit 2; }
      shift 2
      ;;
    --full-runtime)
      FULL_RUNTIME=1
      shift
      ;;
    --allow-unsupported-python)
      ALLOW_UNSUPPORTED_PYTHON=1
      shift
      ;;
    --keep-tmp)
      KEEP_TMP=1
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

case "$(uname -s)" in
  Darwin|Linux) ;;
  *)
    echo "This helper is for macOS/Linux fresh-clone validation." >&2
    exit 2
    ;;
esac

if [[ ! -f "$ROOT/pyproject.toml" || ! -f "$ROOT/bin/lac" ]]; then
  echo "Run this helper from the lightweight-agentic-coding repository." >&2
  exit 2
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is required for release evidence metadata." >&2
  exit 2
fi
if [[ -z "$PYTHON_BIN" ]]; then
  if [[ "$ALLOW_UNSUPPORTED_PYTHON" -eq 1 && "$FULL_RUNTIME" -eq 0 ]]; then
    for candidate in python3.14 python3.13 python3.12 python3.11 python3.10 python3; do
      command -v "$candidate" >/dev/null 2>&1 || continue
      if "$candidate" -c 'import setuptools.build_meta' >/dev/null 2>&1; then
        PYTHON_BIN="$candidate"
        break
      fi
    done
  fi
  if [[ -z "$PYTHON_BIN" ]]; then
    for candidate in python3.14 python3.13 python3.12 python3.11 python3.10 python3; do
      command -v "$candidate" >/dev/null 2>&1 || continue
      if "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' >/dev/null 2>&1; then
        PYTHON_BIN="$candidate"
        break
      fi
      if [[ -z "$PYTHON_BIN" ]]; then
        PYTHON_BIN="$candidate"
      fi
    done
  fi
fi
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "Python executable not found: $PYTHON_BIN" >&2
  exit 2
fi
if ! "$PYTHON_BIN" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' >/dev/null 2>&1; then
  if [[ "$ALLOW_UNSUPPORTED_PYTHON" -eq 0 || "$FULL_RUNTIME" -eq 1 ]]; then
    echo "Python 3.10+ is required for release evidence. Found: $("$PYTHON_BIN" --version 2>&1)" >&2
    echo "Install Python 3.10+ or pass --python <path>." >&2
    exit 2
  fi
  echo "[warn] Using unsupported Python for local no-download rehearsal: $("$PYTHON_BIN" --version 2>&1)" >&2
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lac-fresh-clone-unix.XXXXXX")"
if [[ -z "$EVIDENCE_DIR" ]]; then
  EVIDENCE_DIR="$ROOT/state/release-evidence/fresh-clone-unix-$STAMP"
fi
mkdir -p "$EVIDENCE_DIR"

LOG="$EVIDENCE_DIR/commands.log"
SUMMARY="$EVIDENCE_DIR/summary.md"
STATE_ROOT="$TMP_DIR/state"
MODELS_DIR="$TMP_DIR/models"
VENV_DIR="$TMP_DIR/venv"

log_cmd() {
  {
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  } | tee -a "$LOG"
}

run() {
  log_cmd "$@"
  "$@" 2>&1 | tee -a "$LOG"
}

run_in_repo() {
  {
    printf '+ cd %q &&' "$ROOT"
    printf ' %q' "$@"
    printf '\n'
  } | tee -a "$LOG"
  (cd "$ROOT" && "$@") 2>&1 | tee -a "$LOG"
}

run_json() {
  local output="$1"
  shift
  log_cmd "$@"
  "$@" >"$output" 2>>"$LOG"
}

runtime_started=0
cleanup_runtime() {
  if [[ "$runtime_started" -eq 1 ]]; then
    env LAC_STATE_ROOT="$STATE_ROOT" AI_MODELS_DIR="$MODELS_DIR" "$VENV_DIR/bin/lac" runtime stop --json >>"$LOG" 2>&1 || true
  fi
}

cleanup_all() {
  cleanup_runtime
  if [[ "$KEEP_TMP" -eq 0 ]]; then
    rm -rf "$TMP_DIR"
  else
    echo "Kept temp directory: $TMP_DIR"
  fi
}
trap cleanup_all EXIT

echo "Fresh-clone Unix release smoke"
echo "- Evidence directory: $EVIDENCE_DIR"
echo "- Temporary state: $TMP_DIR"
echo "- Profile: $PROFILE"
if [[ "$FULL_RUNTIME" -eq 1 ]]; then
  echo "- Mode: full runtime"
else
  echo "- Mode: no-download smoke (pass --full-runtime for release gate evidence)"
fi

run date -u
run uname -a
run "$PYTHON_BIN" --version
run git -C "$ROOT" rev-parse HEAD

venv_cmd=("$PYTHON_BIN" -m venv)
if [[ "$ALLOW_UNSUPPORTED_PYTHON" -eq 1 && "$FULL_RUNTIME" -eq 0 ]]; then
  venv_cmd+=(--system-site-packages)
fi
venv_cmd+=("$VENV_DIR")
run "${venv_cmd[@]}"
install_cmd=("$VENV_DIR/bin/python" -m pip install .)
if [[ "$FULL_RUNTIME" -eq 0 ]]; then
  install_cmd+=(--no-build-isolation)
fi
if [[ "$ALLOW_UNSUPPORTED_PYTHON" -eq 1 ]]; then
  install_cmd+=(--ignore-requires-python)
fi
run_in_repo "${install_cmd[@]}"

LAC_ENV=(env "LAC_STATE_ROOT=$STATE_ROOT" "AI_MODELS_DIR=$MODELS_DIR")
LAC_BIN="$VENV_DIR/bin/lac"

run "$LAC_BIN" --version
run_json "$EVIDENCE_DIR/init.json" "${LAC_ENV[@]}" "$LAC_BIN" init --yes --profile "$PROFILE" --no-cloud --json
run_json "$EVIDENCE_DIR/doctor.json" "${LAC_ENV[@]}" "$LAC_BIN" doctor --bootstrap-hint --json
run_json "$EVIDENCE_DIR/render-opencode.json" "${LAC_ENV[@]}" "$LAC_BIN" client render opencode --json
run_json "$EVIDENCE_DIR/runtime-status-dry.json" "${LAC_ENV[@]}" "$LAC_BIN" runtime status --json

if [[ "$FULL_RUNTIME" -eq 1 ]]; then
  run "${LAC_ENV[@]}" "$LAC_BIN" models sync "$PROFILE"
  run_json "$EVIDENCE_DIR/runtime-start.json" "${LAC_ENV[@]}" "$LAC_BIN" runtime start --json
  runtime_started=1
  run_json "$EVIDENCE_DIR/runtime-status.json" "${LAC_ENV[@]}" "$LAC_BIN" runtime status --json
  run_json "$EVIDENCE_DIR/render-opencode-after-runtime.json" "${LAC_ENV[@]}" "$LAC_BIN" client render opencode --json
else
  cat >"$EVIDENCE_DIR/full-runtime-skipped.txt" <<EOF
Full runtime validation was skipped.

Re-run from a fresh macOS/Linux clone with:

  ./scripts/release-fresh-clone-unix.sh --full-runtime

That mode runs model sync, runtime start/status, and OpenCode config render.
EOF
fi

cat >"$SUMMARY" <<EOF
# Fresh-Clone Unix Evidence Summary

- Status: open
- Date: $STAMP
- Repository: $ROOT
- Commit: $(git -C "$ROOT" rev-parse HEAD)
- Profile: $PROFILE
- Mode: $([[ "$FULL_RUNTIME" -eq 1 ]] && echo "full runtime" || echo "no-download smoke")
- Evidence directory: $EVIDENCE_DIR
- Temporary state root: $STATE_ROOT
- Temporary models dir: $MODELS_DIR

## Captured Files

- commands.log
- init.json
- doctor.json
- render-opencode.json
- runtime-status-dry.json
EOF

if [[ "$FULL_RUNTIME" -eq 1 ]]; then
  cat >>"$SUMMARY" <<'EOF'
- runtime-start.json
- runtime-status.json
- render-opencode-after-runtime.json
EOF
else
  cat >>"$SUMMARY" <<'EOF'
- full-runtime-skipped.txt
EOF
fi

cat >>"$SUMMARY" <<'EOF'

Keep the `fresh-clone-unix` manual gate open until this summary comes from a
fresh macOS/Linux clone and `--full-runtime` completed successfully.
EOF

echo
echo "Fresh-clone Unix smoke passed."
echo "Evidence summary: $SUMMARY"
if [[ "$FULL_RUNTIME" -eq 0 ]]; then
  echo "Full runtime validation was skipped. Use --full-runtime for release gate evidence."
fi
