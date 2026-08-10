import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from lac.opencode import inspect_opencode_coexistence, opencode_env  # noqa: E402


class OpenCodeCoexistenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.project = self.root / "project"
        self.config_dir = self.root / "lac-state" / "clients" / "opencode"
        self.home.mkdir()
        self.project.mkdir()
        self.config_dir.mkdir(parents=True)
        self.generated = self.config_dir / "opencode.json"
        self.generated.write_text(json.dumps({
            "share": "disabled",
            "autoupdate": False,
            "model": "local-cluster/qwen3.5-4b-q4",
            "plugin": ["@tarquinen/opencode-dcp@3.1.9", "@dietrichgebert/ponytail@4.9.0"],
            "permission": {"edit": "ask"},
        }), encoding="utf-8")
        self.ctx = SimpleNamespace(paths={
            "opencode_config": self.generated,
            "opencode_config_dir": self.config_dir,
        })
        self.profile = {
            "runtime_mode": "local",
            "default_model": "local-cluster/qwen3.5-4b-q4",
        }

    def completed(self, payload, returncode=0):
        def run(*args, **kwargs):
            return subprocess.CompletedProcess(args[0], returncode, json.dumps(payload), "")
        return run

    def inspect(self, payload, **kwargs):
        with patch("lac.opencode.Path.home", return_value=self.home), \
             patch("lac.opencode.shutil.which", return_value=None):
            return inspect_opencode_coexistence(
                self.ctx,
                profile=self.profile,
                cwd=self.project,
                command="/fake/opencode",
                runner=self.completed(payload),
                **kwargs,
            )

    def test_launch_environment_sets_config_and_disables_updates(self):
        env = opencode_env(self.ctx, {"EXISTING": "yes"})
        self.assertEqual(env["EXISTING"], "yes")
        self.assertEqual(env["OPENCODE_CONFIG"], str(self.generated))
        self.assertEqual(env["OPENCODE_CONFIG_DIR"], str(self.config_dir))
        self.assertEqual(env["OPENCODE_DISABLE_AUTOUPDATE"], "1")

    def test_dirty_home_is_unchanged_and_all_risks_are_reported(self):
        global_config = self.home / ".config" / "opencode" / "opencode.json"
        global_config.parent.mkdir(parents=True)
        global_config.write_text('{"share":"auto"}\n', encoding="utf-8")
        project_config = self.project / "opencode.json"
        project_config.write_text('{"model":"cloud/example"}\n', encoding="utf-8")
        before = {path: path.read_bytes() for path in (global_config, project_config)}
        effective = {
            "share": "auto",
            "autoupdate": True,
            "model": "cloud/example",
            "enabled_providers": ["cloud"],
            "plugin": [
                "@tarquinen/opencode-dcp@3.1.9",
                "@dietrichgebert/ponytail@4.9.0",
                "example-plugin@1.0.0",
            ],
            "mcp": {"remote-example": {"type": "remote", "url": "https://example.invalid/mcp"}},
            "permission": {"edit": "allow"},
        }
        report = self.inspect(effective)
        codes = {warning["code"] for warning in report["warnings"]}
        self.assertTrue(report["checked"])
        self.assertEqual(codes, {
            "existing-config-merged",
            "sharing-enabled",
            "autoupdate-enabled",
            "nonlocal-default-model",
            "local-provider-unavailable",
            "extra-plugin",
            "enabled-mcp",
            "edit-without-approval",
        })
        self.assertEqual(before, {path: path.read_bytes() for path in before})
        self.assertEqual(
            {source["kind"] for source in report["detected_config_sources"]},
            {"lac-generated", "global", "project"},
        )

    def test_safe_effective_config_has_no_risk_warning(self):
        effective = {
            "share": "disabled",
            "autoupdate": False,
            "model": "local-cluster/qwen3.5-4b-q4",
            "plugin": ["@tarquinen/opencode-dcp@3.1.9", "@dietrichgebert/ponytail@4.9.0"],
            "mcp": {"github": {"enabled": False}},
            "permission": {"edit": "ask"},
        }
        self.assertEqual(self.inspect(effective)["warnings"], [])

    def test_missing_malformed_nonzero_and_timeout_are_warning_only(self):
        scenarios = [
            (None, None),
            ("/fake/opencode", lambda *a, **k: subprocess.CompletedProcess(a[0], 0, "not-json", "")),
            ("/fake/opencode", lambda *a, **k: subprocess.CompletedProcess(a[0], 7, "", "failed")),
            ("/fake/opencode", lambda *a, **k: (_ for _ in ()).throw(subprocess.TimeoutExpired(a[0], 10))),
        ]
        with patch("lac.opencode.Path.home", return_value=self.home), \
             patch("lac.opencode.shutil.which", return_value=None):
            for command, runner in scenarios:
                with self.subTest(command=command, runner=runner):
                    report = inspect_opencode_coexistence(
                        self.ctx,
                        profile=self.profile,
                        cwd=self.project,
                        command=command,
                        runner=runner,
                    )
                    self.assertFalse(report["checked"])
                    self.assertEqual(report["warnings"][0]["code"], "effective-config-unavailable")


if __name__ == "__main__":
    unittest.main()
