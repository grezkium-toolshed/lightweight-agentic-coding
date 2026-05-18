#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    -h|--help) echo "Usage: $0 --profile <profile>"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done
if [[ -z "$PROFILE" ]]; then
  echo "Usage: $0 --profile <profile>" >&2; exit 1
fi
exec "$ROOT/bin/lac" setup "$PROFILE"
