#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - <<'PY' "$ROOT"
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
catalog = json.loads((root / "catalog/providers.json").read_text(encoding="utf-8"))
required_provider_fields = {
    "id",
    "label",
    "env_var",
    "docs_path",
    "risk_level",
    "models",
}
required_model_fields = {
    "id",
    "risk_level",
}

errors = []

for provider in catalog["providers"]:
    missing = sorted(required_provider_fields - provider.keys())
    if missing:
        errors.append(f"provider {provider.get('id', '<unknown>')}: missing {missing}")
    docs_path = root / provider["docs_path"]
    if not docs_path.is_file():
        errors.append(f"provider {provider['id']}: docs path missing {provider['docs_path']}")
    for model in provider["models"]:
        missing_model = sorted(required_model_fields - model.keys())
        if missing_model:
            errors.append(f"provider {provider['id']} model {model.get('id', '<unknown>')}: missing {missing_model}")

if errors:
    print("Provider catalog validation failed:")
    for err in errors:
        print(f"  - {err}")
    raise SystemExit(1)

print(f"[ok] providers checked: {len(catalog['providers'])}")
print("Provider catalog validation passed.")
PY
