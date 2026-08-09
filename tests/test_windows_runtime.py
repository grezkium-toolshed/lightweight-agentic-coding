import os
import signal
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from lac import runtime  # noqa: E402
from lac.cli import _install_hint  # noqa: E402
from lac.models import _curl_executable  # noqa: E402


class WindowsRuntimeTests(unittest.TestCase):
    @unittest.skipUnless(os.name == "nt", "requires Windows")
    def test_win32_probe_observes_current_process(self):
        self.assertTrue(runtime._windows_pid_running(os.getpid()))

    def test_windows_pid_check_never_sends_signal_zero(self):
        with (
            patch("lac.runtime.os.name", "nt"),
            patch("lac.runtime._windows_pid_running", return_value=True) as probe,
            patch("lac.runtime.os.kill") as kill,
        ):
            self.assertTrue(runtime.is_pid_running(1234))
        probe.assert_called_once_with(1234)
        kill.assert_not_called()

    def test_windows_tail_hint_uses_powershell(self):
        with patch("lac.runtime.os.name", "nt"):
            hint = runtime.log_tail_hint(Path("C:/lac state/runtime.log"))
        self.assertEqual(hint, "Get-Content -Path 'C:\\lac state\\runtime.log' -Wait -Tail 50")

    def test_windows_background_flags(self):
        with (
            patch("lac.runtime.os.name", "nt"),
            patch.object(runtime.subprocess, "CREATE_NEW_PROCESS_GROUP", 512, create=True),
            patch.object(runtime.subprocess, "DETACHED_PROCESS", 8, create=True),
        ):
            flags, kwargs = runtime._background_process_options()
        self.assertEqual(flags, 520)
        self.assertEqual(kwargs, {})

    def test_windows_stop_terminates_then_uses_safe_polling(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            pid_path = tmp_path / "runtime.pid"
            pid_path.write_text("1234\n", encoding="utf-8")
            ctx = SimpleNamespace(
                active_profile=lambda: {"runtime_mode": "local"},
                paths={
                    "llama_pid": pid_path,
                    "llama_state": tmp_path / "runtime.json",
                    "llama_log": tmp_path / "runtime.log",
                },
            )
            with (
                patch("lac.runtime.os.name", "nt"),
                patch("lac.runtime.is_pid_running", side_effect=[True, False, False]) as probe,
                patch("lac.runtime.os.kill") as kill,
                patch("lac.runtime.time.sleep"),
            ):
                result = runtime.runtime_stop(ctx)
        self.assertTrue(result["ok"])
        kill.assert_called_once_with(1234, signal.SIGTERM)
        self.assertEqual(probe.call_count, 3)

    def test_windows_openchamber_hint_never_pipes_to_bash(self):
        with patch("lac.cli.sys.platform", "win32"):
            hint = _install_hint("openchamber")
        self.assertTrue(any("OpenChamber Desktop" in command for command in hint["commands"]))
        self.assertFalse(any("| bash" in command for command in hint["commands"]))

    def test_native_windows_uses_curl_executable_not_powershell_alias(self):
        with patch("lac.models.os.name", "nt"):
            self.assertEqual(_curl_executable(), "curl.exe")


if __name__ == "__main__":
    unittest.main()
