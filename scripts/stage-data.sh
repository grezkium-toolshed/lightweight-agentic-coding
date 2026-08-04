#!/bin/bash
set -euo pipefail

# Regenerate src/lac/data/ from the canonical top-level trees.
# Thin wrapper over the portable Python stager (see scripts/stage_data.py).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${PYTHON:-python3}" "$ROOT/scripts/stage_data.py"
