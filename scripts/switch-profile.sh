#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 || "$1" != "--profile" ]]; then
  echo "Usage: $0 --profile <16gb|24gb|32gb|64gb|128gb-multi|128gb-qwen122b|128gb-minimax|gemma-16gb|gemma-24gb|gemma-32gb|gemma-64gb>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/setup-config-device.sh" --profile "$2"
