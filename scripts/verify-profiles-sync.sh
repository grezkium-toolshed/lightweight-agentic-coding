#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - <<'PY' "$ROOT"
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
manifest_path = root / "runtime-config/profiles.json"
setup_models_sh = root / "scripts/setup-models-device.sh"
setup_models_ps1 = root / "scripts/setup-models-device.ps1"
readme_path = root / "README.md"
config_path = root / "opencode.jsonc"


def load_jsonc(path: Path):
    raw = path.read_text(encoding="utf-8")
    cleaned = "\n".join(
        line for line in raw.splitlines() if not line.lstrip().startswith("//")
    )
    return json.loads(cleaned)


def require(cond: bool, message: str):
    if not cond:
        raise AssertionError(message)


manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
profiles = manifest["profiles"]
manifest_ids = list(profiles.keys())
manifest_id_set = set(manifest_ids)

sh_text = setup_models_sh.read_text(encoding="utf-8")
ps1_text = setup_models_ps1.read_text(encoding="utf-8")

sh_profiles = set(
    match.group(1)
    for match in re.finditer(r"(?m)^[ \t]*([a-z0-9-]+)\)", sh_text)
    if match.group(1) not in {"--profile", "*"}
)
ps1_profiles = set(
    match.group(1)
    for match in re.finditer(r"(?m)^[ \t]*'([a-z0-9-]+)'\s*\{", ps1_text)
)

require(sh_profiles == manifest_id_set, f"setup-models-device.sh profiles differ from runtime-config/profiles.json: {sorted(sh_profiles ^ manifest_id_set)}")
require(ps1_profiles == manifest_id_set, f"setup-models-device.ps1 profiles differ from runtime-config/profiles.json: {sorted(ps1_profiles ^ manifest_id_set)}")

for profile_id, profile in profiles.items():
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

config = load_jsonc(config_path)
providers = config["provider"]
for profile_id, profile in profiles.items():
    for field in ("default_model", "small_model"):
        provider_name, model_id = profile[field].split("/", 1)
        require(provider_name in providers, f"{profile_id}: provider '{provider_name}' from {field} missing in opencode.jsonc")
        require(
            model_id in providers[provider_name]["models"],
            f"{profile_id}: model '{model_id}' from {field} missing in provider '{provider_name}'",
        )

readme = readme_path.read_text(encoding="utf-8")
hardware_section_match = re.search(
    r"## Hardware profiles\n(?P<section>.*?)(?:\n## |\Z)",
    readme,
    re.S,
)
require(hardware_section_match is not None, "README.md is missing the '## Hardware profiles' section")
hardware_section = hardware_section_match.group("section")
readme_profiles = set(re.findall(r"`([a-z0-9-]+)`", hardware_section))
require(
    manifest_id_set <= readme_profiles,
    f"README.md hardware profile list is missing: {sorted(manifest_id_set - readme_profiles)}",
)

print(f"[ok] manifest profiles: {len(manifest_ids)}")
print(f"[ok] setup-models-device.sh profiles match manifest")
print(f"[ok] setup-models-device.ps1 profiles match manifest")
print(f"[ok] README hardware profiles cover manifest ids")
print("Profile parity checks passed.")
PY
