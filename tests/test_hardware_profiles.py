import configparser
import copy
import json
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from lac.hardware import (  # noqa: E402
    _record, _run, detect_accelerators, detect_execution_environment, normalize_hardware,
    parse_llama_devices, parse_nvidia_smi,
    parse_rocm_smi, parse_windows_adapters, parse_xpu_smi,
)
from lac.models import PROFILE_MODELS  # noqa: E402
from lac.profiles import recommend_profile  # noqa: E402
from lac.lib.jsonc import load_jsonc  # noqa: E402


class HardwareProfileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixtures = json.loads((ROOT / "tests/fixtures/hardware-probes.json").read_text(encoding="utf-8"))
        cls.profiles = json.loads((ROOT / "runtime-config/profiles.json").read_text(encoding="utf-8"))["profiles"]

    def profile_for(self, hardware, profiles=None):
        return recommend_profile(
            hardware["effective_budget_gb"], profiles=profiles or self.profiles, hardware=hardware,
        )

    def test_vendor_parsers_and_failures(self):
        nvidia = parse_nvidia_smi(self.fixtures["nvidia"])
        self.assertEqual([round(item["budget_gb"]) for item in nvidia], [8, 24])
        self.assertEqual(round(parse_rocm_smi(self.fixtures["amd"])[0]["budget_gb"]), 24)
        self.assertEqual(round(parse_xpu_smi(self.fixtures["intel"])[0]["budget_gb"]), 16)
        self.assertEqual(round(parse_llama_devices(self.fixtures["llama_igpu_6"])[0]["budget_gb"]), 6)
        self.assertEqual(parse_llama_devices("BLAS: Accelerate (0 MiB, 0 MiB free)"), [])
        self.assertEqual(parse_windows_adapters(self.fixtures["windows_qualcomm"])[0]["vendor"], "qualcomm")
        self.assertEqual(parse_rocm_smi(self.fixtures["malformed"]), [])
        self.assertEqual(parse_xpu_smi(self.fixtures["malformed"]), [])
        with patch("lac.hardware.subprocess.run", side_effect=subprocess.TimeoutExpired("probe", 1)):
            self.assertEqual(_run(["probe"], timeout=1), "")

    def test_effective_budget_selection(self):
        igpu4 = normalize_hardware(16, "linux", "x86_64", parse_llama_devices(self.fixtures["llama_igpu_4"]))
        igpu6 = normalize_hardware(16, "win32", "AMD64", parse_llama_devices(self.fixtures["llama_igpu_6"]))
        apple16 = normalize_hardware(16, "darwin", "arm64", [])
        discrete24 = normalize_hardware(64, "linux", "x86_64", [_record("NVIDIA RTX", 24, "fixture")])
        multi = normalize_hardware(64, "linux", "x86_64", parse_nvidia_smi(self.fixtures["nvidia"]))
        unknown_igpu = normalize_hardware(16, "win32", "AMD64", [_record("Intel Iris Xe", None, "fixture")])
        unknown_nvidia = normalize_hardware(
            16, "win32", "AMD64", [_record("NVIDIA GeForce RTX 3050", None, "windows-cim")],
        )
        snapdragon = normalize_hardware(
            32, "win32", "ARM64", parse_windows_adapters(self.fixtures["windows_qualcomm"]),
        )
        wsl_unknown = normalize_hardware(16, "linux", "x86_64", [], "wsl2")
        wsl_igpu = normalize_hardware(
            16, "linux", "x86_64", [_record("Intel Iris Xe", None, "windows-cim")], "wsl2",
        )
        wsl_nvidia = normalize_hardware(
            64, "linux", "x86_64", parse_nvidia_smi(self.fixtures["nvidia"]), "wsl2",
        )
        cpu16 = normalize_hardware(16, "linux", "x86_64", [])
        missing = normalize_hardware(None, "linux", "x86_64", [])

        self.assertEqual(self.profile_for(igpu4), "4gb")
        self.assertEqual(self.profile_for(igpu6), "6gb")
        self.assertEqual(self.profile_for(apple16), "macos-16gb")
        self.assertEqual(self.profile_for(discrete24), "24gb")
        self.assertEqual(multi["effective_budget_gb"], 24)
        self.assertEqual(unknown_igpu["effective_budget_gb"], 4)
        self.assertEqual(unknown_igpu["confidence"], "low")
        self.assertEqual(unknown_nvidia["effective_budget_gb"], 4)
        self.assertEqual(self.profile_for(unknown_nvidia), "4gb")
        self.assertIn("not measured", unknown_nvidia["selection_guidance"])
        self.assertEqual(snapdragon["memory_kind"], "snapdragon-shared")
        self.assertEqual(snapdragon["runtime_acceleration"], "experimental-opencl")
        self.assertEqual(self.profile_for(snapdragon), "4gb")
        self.assertEqual(wsl_unknown["execution_environment"], "wsl2")
        self.assertEqual(wsl_unknown["probe_source"], "wsl-conservative")
        self.assertEqual(self.profile_for(wsl_unknown), "4gb")
        self.assertIn("WSL2", wsl_unknown["selection_guidance"])
        self.assertEqual(self.profile_for(wsl_igpu), "4gb")
        self.assertEqual(wsl_igpu["confidence"], "low")
        self.assertEqual(wsl_nvidia["effective_budget_gb"], 24)
        self.assertEqual(self.profile_for(wsl_nvidia), "24gb")
        self.assertEqual(self.profile_for(cpu16), "16gb")
        self.assertEqual(self.profile_for(missing), "6gb")

    def test_environment_and_platform_safe_large_profile(self):
        with patch("lac.hardware.sys.platform", "linux"):
            self.assertEqual(detect_execution_environment("5.15.153.1-microsoft-standard-WSL2", {}), "wsl2")
            self.assertEqual(detect_execution_environment("6.8.0-generic", {}), "native")
            self.assertEqual(detect_execution_environment("6.8.0-generic", {"WSL_INTEROP": "/run/WSL/1"}), "wsl2")

        windows128 = normalize_hardware(128, "win32", "AMD64", [])
        linux128 = normalize_hardware(128, "linux", "x86_64", [])
        apple128 = normalize_hardware(128, "darwin", "arm64", [])
        self.assertEqual(self.profile_for(windows128), "128gb-multi")
        self.assertEqual(self.profile_for(linux128), "128gb-multi")
        self.assertEqual(self.profile_for(apple128), "128gb-ds4-flash")

    def test_wsl_probe_includes_host_adapter_names(self):
        def fixture_run(command, timeout=5):
            if command[0] == "nvidia-smi":
                return self.fixtures["nvidia"]
            if command[0] == "powershell.exe":
                return self.fixtures["windows_qualcomm"]
            return ""

        with (
            patch("lac.hardware._run", side_effect=fixture_run),
            patch("lac.hardware._linux_drm_records", return_value=[]),
            patch("lac.hardware.sys.platform", "linux"),
        ):
            records = detect_accelerators("wsl2")
        self.assertIn("nvidia-smi", {record["source"] for record in records})
        self.assertIn("windows-cim", {record["source"] for record in records})

    def test_48gb_gate_and_boundaries(self):
        hardware = normalize_hardware(48, "darwin", "arm64", [])
        self.assertEqual(self.profile_for(hardware), "32gb")
        enabled = copy.deepcopy(self.profiles)
        enabled["48gb"]["auto_recommend"] = True
        self.assertEqual(self.profile_for(hardware, enabled), "48gb")
        self.assertEqual(recommend_profile(45.9, profiles=enabled), "32gb")
        self.assertEqual(recommend_profile(60, profiles=enabled), "64gb")

    def test_profile_manifest_parity(self):
        template = load_jsonc(ROOT / "opencode.template.jsonc")
        provider_ids = set(template["provider"])
        required = {
            "memory_target_gb", "recommendation_floor_gb", "estimated_default_weight_gb", "auto_recommend",
        }
        for profile_id, profile in self.profiles.items():
            for field in ("default_model", "small_model"):
                self.assertIn(profile[field].split("/", 1)[0], provider_ids, (profile_id, field))
            if profile["runtime_mode"] != "local":
                continue
            self.assertFalse(required - profile.keys(), profile_id)
            self.assertIn(profile_id, PROFILE_MODELS)
            preset_path = ROOT / profile["preset"]
            self.assertTrue(preset_path.is_file(), profile_id)
            parser = configparser.ConfigParser(interpolation=None, strict=False)
            parser.read_string("[global]\n" + preset_path.read_text(encoding="utf-8"))
            for selector in (profile["default_model"], profile["small_model"]):
                if selector.startswith("local-cluster/"):
                    self.assertIn(selector.split("/", 1)[1], parser.sections(), profile_id)


if __name__ == "__main__":
    unittest.main()
