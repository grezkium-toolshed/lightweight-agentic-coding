#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
"$ROOT/scripts/launch-llama.sh"
"$ROOT/scripts/launch-opencode.sh"
