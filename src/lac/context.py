"""Context class and repo root detection."""

import os
from pathlib import Path

from lac.lib.jsonc import load_jsonc
from lac import VERSION


def _find_repo_root() -> Path:
    """Locate the repo root by searching for runtime-config/profiles.json."""
    current = Path.cwd().resolve()
    for candidate in [current, *current.parents]:
        if (candidate / "runtime-config" / "profiles.json").is_file():
            return candidate
    return Path(__file__).resolve().parent.parent.parent


ROOT = _find_repo_root()
STATE_ROOT = Path(os.environ.get("AI_CLUSTER_STATE_ROOT", ROOT / "state"))
PORT = int(os.environ.get("AI_CLUSTER_PORT", "8080"))
HOST = os.environ.get("AI_CLUSTER_HOST", "127.0.0.1")
OMLX_PORT = int(os.environ.get("AI_OMLX_PORT", os.environ.get("OMLX_PORT", "8000")))


class Context:
    def __init__(self):
        self.root = ROOT
        self.state_root = STATE_ROOT
        self.paths = {
            "profile_manifest": self.root / "runtime-config/profiles.json",
            "opencode_template": self.root / "opencode.template.jsonc",
            "asset_catalog": self.root / "catalog/assets.json",
            "workflow_catalog": self.root / "catalog/workflow-packs.json",
            "provider_catalog": self.root / "catalog/providers.json",
            "scenario_catalog": self.root / "catalog/scenarios.json",
            "active_profile": self.state_root / "active/profile.txt",
            "active_profile_summary": self.state_root / "active/profile.json",
            "active_preset": self.state_root / "runtime/presets.active.ini",
            "opencode_config": self.state_root / "clients/opencode/opencode.json",
            "llama_pid": self.state_root / "runtime/llama-server.pid",
            "llama_state": self.state_root / "runtime/llama-server.json",
            "llama_log": self.state_root / "logs/llama-server.log",
            "omlx_pid": self.state_root / "runtime/omlx.pid",
            "omlx_state": self.state_root / "runtime/omlx.json",
            "omlx_log": self.state_root / "logs/omlx.log",
            "doctor_report": self.state_root / "reports/doctor.json",
            "smoke_report": self.state_root / "reports/smoke.json",
        }
        self.profile_manifest = load_jsonc(self.paths["profile_manifest"])
        self.profiles = self.profile_manifest["profiles"]

    def get_profile(self, profile_id):
        profile = self.profiles.get(profile_id)
        if profile is None:
            raise SystemExit(f"Unknown profile: {profile_id}")
        return profile

    def active_profile_id(self):
        if self.paths["active_profile"].is_file():
            return self.paths["active_profile"].read_text(encoding="utf-8").strip()
        return ""

    def active_profile(self):
        profile_id = self.active_profile_id()
        if not profile_id:
            return None
        return self.profiles.get(profile_id)
