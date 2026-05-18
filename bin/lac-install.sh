#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dev|-e) DEV="-e"; shift ;;
    -h|--help)
      echo "Usage: ./bin/lac install [--dev]"
      echo ""
      echo "Install the Local AI Cluster CLI (lac) into your Python environment."
      echo ""
      echo "Options:"
      echo "  --dev, -e    Editable install (changes to source reflect immediately)"
      echo "  -h, --help   Show this help"
      echo ""
      echo "Examples:"
      echo "  ./bin/lac install          # Standard install"
      echo "  ./bin/lac install --dev    # Development install"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

echo "[lac] Installing Local AI Cluster CLI..."
echo "[lac] Package: local-ai-cluster"
echo "[lac] Source: $ROOT"
if [[ -n "$DEV" ]]; then
  echo "[lac] Mode: editable (development)"
else
  echo "[lac] Mode: standard"
fi
echo ""

if command -v python3 >/dev/null 2>&1; then
  PYTHON=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON=python
elif command -v py >/dev/null 2>&1; then
  PYTHON=py
else
  echo "[lac] ERROR: Python 3 is required but not found on PATH." >&2
  echo "[lac] Install Python 3.10+ and try again." >&2
  exit 1
fi

PYTHON_VERSION=$($PYTHON -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
if [[ "$PYTHON_VERSION" < "3.10" ]]; then
  echo "[lac] ERROR: Python 3.10+ is required (found $PYTHON_VERSION)." >&2
  exit 1
fi

echo "[lac] Using $($PYTHON --version 2>&1)"
echo ""

cd "$ROOT"
if $PYTHON -m pip install $DEV .; then
  echo ""
  echo "[lac] Install complete."
  echo "[lac] Verify with: lac --version"
  echo "[lac] Get started: lac init"
else
  echo "[lac] Install failed." >&2
  exit 1
fi
