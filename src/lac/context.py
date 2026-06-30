"""Context class and repo root detection."""

import os
import sys
from pathlib import Path

from lac.lib.jsonc import load_jsonc
from lac import VERSION


def _env_or_deprecated(new_key, old_key, default=None):
    val = os.environ.get(new_key)
    if val is not None:
        return val
    val = os.environ.get(old_key)
    if val is not None:
        print(f"Warning: {old_key} is deprecated, use {new_key} instead", file=sys.stderr)
        return val
    return default


def _find_repo_root() -> Path:
    """Locate the repo root by searching for runtime-config/profiles.json."""
    current = Path.cwd().resolve()
    for candidate in [current, *current.parents]:
        if (candidate / "runtime-config" / "profiles.json").is_file():
            return candidate
    return None


def _package_data_dir() -> Path:
    """Return the path to bundled data files when installed as a package."""
    if sys.version_info >= (3, 9):
        from importlib.resources import files
        return files("lac") / "data"
    else:
        from importlib.resources import path as resource_path
        with resource_path("lac", "data") as p:
            return Path(p)


_REPO_ROOT = _find_repo_root()
_PACKAGE_DATA = _package_data_dir() if _REPO_ROOT is None else None
ROOT = _REPO_ROOT or _PACKAGE_DATA
_STATE_DEFAULT = _REPO_ROOT / "state" if _REPO_ROOT else Path.cwd() / "state"
STATE_ROOT = Path(_env_or_deprecated("LAC_STATE_ROOT", "AI_CLUSTER_STATE_ROOT", str(_STATE_DEFAULT)))
PORT = int(_env_or_deprecated("LAC_PORT", "AI_CLUSTER_PORT", "8080"))
HOST = _env_or_deprecated("LAC_HOST", "AI_CLUSTER_HOST", "127.0.0.1")
OMLX_PORT = int(os.environ.get("AI_OMLX_PORT", os.environ.get("OMLX_PORT", "8000")))
DS4_PORT = int(os.environ.get("DS4_PORT", "8000"))


class Context:
    def __init__(self):
        self.root = ROOT
        self.state_root = STATE_ROOT
        self._is_repo = _REPO_ROOT is not None
        self.paths = {
            "profile_manifest": self.root / "runtime-config/profiles.json",
            "opencode_template": self.root / ("opencode/opencode.template.jsonc" if not self._is_repo else "opencode.template.jsonc"),
            "asset_catalog": self.root / "catalog/assets.json",
            "workflow_catalog": self.root / "catalog/workflow-packs.json",
            "provider_catalog": self.root / "catalog/providers.json",
            "scenario_catalog": self.root / "catalog/scenarios.json",
            "opencode_agents_dir": self.root / ("opencode/agents" if not self._is_repo else ".opencode/agents"),
            "opencode_skills_dir": self.root / ("opencode/skills" if not self._is_repo else ".opencode/skills"),
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
            "ds4_pid": self.state_root / "runtime/ds4.pid",
            "ds4_state": self.state_root / "runtime/ds4.json",
            "ds4_log": self.state_root / "logs/ds4.log",
            "ds4_kv": self.state_root / "runtime/ds4-kv",
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
