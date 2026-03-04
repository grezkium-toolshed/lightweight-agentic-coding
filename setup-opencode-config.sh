#!/bin/bash
set -euo pipefail

echo "[deprecated] setup-opencode-config.sh now delegates to scripts/setup-config-device.sh"
echo "Using default profile: 32gb"

"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/setup-config-device.sh" --profile 32gb
