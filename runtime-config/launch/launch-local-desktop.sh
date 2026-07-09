#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if command -v lac >/dev/null 2>&1; then
  LAC=(lac)
elif [[ -x "$ROOT/bin/lac" ]]; then
  LAC=("$ROOT/bin/lac")
else
  echo "lac is not installed and the repo-local bin/lac wrapper was not found." >&2
  exit 1
fi
"${LAC[@]}" runtime start
"${LAC[@]}" client open opencode --desktop
