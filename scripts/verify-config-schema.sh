#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="${ROOT}/scripts:${PYTHONPATH:-}"

python3 - <<'PY' "$ROOT"
import json
import sys
from pathlib import Path

from lib.jsonc import load_jsonc

root = Path(sys.argv[1])
catalog_providers = {
    provider["id"]
    for provider in json.loads((root / "catalog/providers.json").read_text(encoding="utf-8"))["providers"]
}
files = [
    root / "opencode.template.jsonc",
    root / "templates/opencode/opencode.example.jsonc",
]


def require(cond: bool, message: str):
    if not cond:
        raise AssertionError(message)


def validate(path: Path):
    obj = load_jsonc(path)
    require(isinstance(obj, dict), f"{path}: root must be an object")

    for key in ("$schema", "model", "small_model", "provider"):
        require(key in obj, f"{path}: missing top-level key '{key}'")

    require(isinstance(obj["model"], str) and "/" in obj["model"], f"{path}: 'model' must include provider prefix")
    require(
        isinstance(obj["small_model"], str) and "/" in obj["small_model"],
        f"{path}: 'small_model' must include provider prefix",
    )

    providers = obj["provider"]
    require(isinstance(providers, dict), f"{path}: 'provider' must be an object")
    removed = sorted(set(providers) - catalog_providers - {"ds4"})
    require(not removed, f"{path}: provider blocks are not in the supported catalog: {removed}")

    for provider_name in ("local-cluster", "openrouter", "nvidia-nim"):
        require(
            provider_name in providers,
            f"{path}: missing provider block '{provider_name}'",
        )

    local_provider = providers["local-cluster"]
    openrouter_provider = providers["openrouter"]
    nim_provider = providers["nvidia-nim"]
    for name, provider in (
        ("local-cluster", local_provider),
        ("openrouter", openrouter_provider),
        ("nvidia-nim", nim_provider),
    ):
        require(isinstance(provider, dict), f"{path}: provider '{name}' must be an object")
        require("models" in provider and isinstance(provider["models"], dict), f"{path}: provider '{name}' missing 'models' object")
        require("options" in provider and isinstance(provider["options"], dict), f"{path}: provider '{name}' missing 'options' object")
        require("baseURL" in provider["options"], f"{path}: provider '{name}' missing options.baseURL")

    require(
        local_provider["options"]["baseURL"] == "http://127.0.0.1:8080/v1",
        f"{path}: local-cluster template default must be http://127.0.0.1:8080/v1; rendered configs may override it",
    )
    require(
        openrouter_provider["options"]["baseURL"] == "https://openrouter.ai/api/v1",
        f"{path}: openrouter baseURL must be https://openrouter.ai/api/v1",
    )
    require(
        nim_provider["options"]["baseURL"] == "https://integrate.api.nvidia.com/v1",
        f"{path}: nvidia-nim baseURL must be https://integrate.api.nvidia.com/v1",
    )

    model_provider, model_id = obj["model"].split("/", 1)
    if model_provider == "local-cluster":
        require(model_id in local_provider["models"], f"{path}: model '{model_id}' not present under provider.local-cluster.models")
    elif model_provider == "openrouter":
        require(model_id in openrouter_provider["models"], f"{path}: model '{model_id}' not present under provider.openrouter.models")
    else:
        require(model_provider in providers, f"{path}: model provider '{model_provider}' missing from provider block")

    small_model_provider, small_model_id = obj["small_model"].split("/", 1)
    if small_model_provider == "local-cluster":
        require(
            small_model_id in local_provider["models"],
            f"{path}: small_model '{small_model_id}' not present under provider.local-cluster.models",
        )
    elif small_model_provider == "openrouter":
        require(
            small_model_id in openrouter_provider["models"],
            f"{path}: small_model '{small_model_id}' not present under provider.openrouter.models",
        )
    else:
        require(
            small_model_provider in providers,
            f"{path}: small_model provider '{small_model_provider}' missing from provider block",
        )

    print(f"[ok] {path.relative_to(root)}")


for config_path in files:
    validate(config_path)

print("Config schema checks passed.")
PY
