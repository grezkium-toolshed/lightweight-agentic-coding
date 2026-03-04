#!/bin/bash
set -euo pipefail

echo "[deprecated] setup-models.sh now delegates to scripts/setup-models-device.sh"
echo "Using default profile: 32gb"

"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/setup-models-device.sh" --profile 32gb
