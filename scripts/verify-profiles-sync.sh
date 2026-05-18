#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="${ROOT}/scripts:${PYTHONPATH:-}"

python3 - <<'PY' "$ROOT"
import json
import re
import sys
from pathlib import Path

from lib.jsonc import load_jsonc

root = Path(sys.argv[1])
manifest_path = root / "runtime-config/profiles.json"
scenario_catalog_path = root / "catalog/scenarios.json"
models_py = root / "src/lac/models.py"
readme_path = root / "README.md"
config_path = root / "opencode.template.jsonc"


def require(cond: bool, message: str):
    if not cond:
        raise AssertionError(message)


manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
profiles = manifest["profiles"]
scenario_catalog = json.loads(scenario_catalog_path.read_text(encoding="utf-8"))
scenario_ids = {scenario["id"] for scenario in scenario_catalog["scenarios"]}
manifest_ids = set(profiles.keys())

models_text = models_py.read_text(encoding="utf-8")

py_profiles = set(re.findall(r'    "([a-z0-9-]+)":\s*\{', models_text))
cloud_profiles = set(re.findall(r'"([a-z0-9-]+)"', models_text.split("CLOUD_PROFILES = {")[1].split("}")[0]))
all_py_profiles = py_profiles | cloud_profiles
require(all_py_profiles == manifest_ids, f"src/lac/models.py profiles differ from runtime-config/profiles.json: {sorted(all_py_profiles ^ manifest_ids)}")

for profile_id, profile in profiles.items():
    require(profile["id"] == profile_id, f"{profile_id}: id must match profile key")
    preset_rel = profile["preset"]
    preset_path = root / preset_rel
    require(preset_path.is_file(), f"{profile_id}: missing preset file {preset_rel}")
    require(
        profile["runtime_mode"] in {"local", "cloud"},
        f"{profile_id}: runtime_mode must be 'local' or 'cloud'",
    )
    require(
        isinstance(profile["local_runtime_required"], bool),
        f"{profile_id}: local_runtime_required must be boolean",
    )
    require(
        isinstance(profile["downloads_required"], bool),
        f"{profile_id}: downloads_required must be boolean",
    )
    require("/" in profile["default_model"], f"{profile_id}: default_model must include provider prefix")
    require("/" in profile["small_model"], f"{profile_id}: small_model must include provider prefix")
    require(profile["verification_tier"], f"{profile_id}: verification_tier is required")
    require(profile["primary_workload"], f"{profile_id}: primary_workload is required")
    require(isinstance(profile["supported_clients"], list) and profile["supported_clients"], f"{profile_id}: supported_clients must be a non-empty list")
    require(isinstance(profile["recommended_for"], list) and profile["recommended_for"], f"{profile_id}: recommended_for must be a non-empty list")
    require(set(profile["recommended_for"]) <= scenario_ids, f"{profile_id}: recommended_for contains unknown scenarios")

config = load_jsonc(config_path)
providers = config["provider"]
for profile_id, profile in profiles.items():
    for field in ("default_model", "small_model"):
        provider_name, model_id = profile[field].split("/", 1)
        require(provider_name in providers, f"{profile_id}: provider '{provider_name}' from {field} missing in opencode.template.jsonc")
        require(
            model_id in providers[provider_name]["models"],
            f"{profile_id}: model '{model_id}' from {field} missing in provider '{provider_name}'",
        )

readme = readme_path.read_text(encoding="utf-8")
profile_section_match = re.search(
    r"## Which Profile\?\n(?P<section>.*?)(?:\n## |\Z)",
    readme,
    re.S,
)
require(profile_section_match is not None, "README.md is missing the '## Which Profile?' section")
profile_section = profile_section_match.group("section")
readme_profiles = set(re.findall(r"`([a-z0-9-]+)`", profile_section))
require(
    manifest_ids <= readme_profiles,
    f"README.md profile list is missing: {sorted(manifest_ids - readme_profiles)}",
)

require("Qwen3.5-9B-Q4_K_M.gguf" in models_text, "src/lac/models.py missing Qwen3.5 9B Q4_K_M download")
require("gemma-4-E4B-IT-Q8_0.gguf" in models_text, "src/lac/models.py missing Gemma 4 E4B Q8 download")
require("gemma-4-E4B-it-MLX-8bit" in models_text, "src/lac/models.py missing Gemma 4 E4B MLX staging")

print(f"[ok] manifest profiles: {len(manifest_ids)}")
print(f"[ok] src/lac/models.py profiles match manifest")
print(f"[ok] README profile list covers manifest ids")
print("Profile parity checks passed.")
PY
