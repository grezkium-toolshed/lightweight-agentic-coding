import json
import os
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from lac import clients, network, runtime


class NetworkContractTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.ctx = SimpleNamespace(state_root=Path(self.temp.name) / "state")

    def tearDown(self):
        self.temp.cleanup()

    def test_default_runtime_is_loopback_and_not_persisted(self):
        with patch.dict(os.environ, {}, clear=True):
            effective = network.resolve_service(self.ctx, "runtime")
        self.assertEqual(effective["bind_host"], "127.0.0.1")
        self.assertEqual(effective["connect_host"], "127.0.0.1")
        self.assertEqual(effective["port"], 8080)
        self.assertEqual(effective["port_source"], "default")

    def test_cli_env_config_persisted_default_precedence(self):
        config = Path(self.temp.name) / "network-config.json"
        config.write_text(json.dumps({
            "contractType": network.CONTRACT_TYPE,
            "version": network.CONTRACT_VERSION,
            "services": {"runtime": {"port": 8111}},
        }), encoding="utf-8")
        state = self.ctx.state_root / "network.v1.json"
        state.parent.mkdir(parents=True)
        state.write_text(json.dumps({
            "contractType": network.CONTRACT_TYPE,
            "version": network.CONTRACT_VERSION,
            "services": {"runtime": {"port": 8222}},
        }), encoding="utf-8")
        with patch.dict(os.environ, {"LAC_NETWORK_CONFIG": str(config)}, clear=True):
            self.assertEqual(network.resolve_service(self.ctx, "runtime")["port"], 8111)
        with patch.dict(os.environ, {"LAC_NETWORK_CONFIG": str(config), "LAC_PORT": "8333"}, clear=True):
            self.assertEqual(network.resolve_service(self.ctx, "runtime")["port"], 8333)
            self.assertEqual(network.resolve_service(self.ctx, "runtime", cli_port=8444)["port"], 8444)

    def test_automatic_fallback_persists_and_explicit_collision_fails(self):
        with patch.dict(os.environ, {}, clear=True), patch.object(network, "_port_available", side_effect=[False, True]):
            effective = network.allocate_service(self.ctx, "runtime")
        self.assertEqual(effective["port"], 8081)
        self.assertEqual(effective["port_source"], "automatic-fallback")
        self.assertFalse((self.ctx.state_root / "network.v1.json").exists())
        network.persist_started_service(self.ctx, effective)
        saved = json.loads((self.ctx.state_root / "network.v1.json").read_text(encoding="utf-8"))
        self.assertEqual(saved["services"]["runtime"]["port"], 8081)
        self.assertTrue(saved["services"]["runtime"]["automatic"])
        self.assertEqual(saved["services"]["runtime"]["allocation_source"], "automatic-fallback")
        self.assertIn("updated_at", saved["services"]["runtime"])
        with patch.dict(os.environ, {"LAC_PORT": "8555"}, clear=True), patch.object(network, "_port_available", return_value=False):
            with self.assertRaisesRegex(SystemExit, "occupied"):
                network.allocate_service(self.ctx, "runtime")

    def test_explicit_cli_port_is_recorded_after_start_but_not_reused(self):
        with patch.dict(os.environ, {}, clear=True), patch.object(network, "_port_available", return_value=True):
            effective = network.allocate_service(self.ctx, "openchamber", cli_port=4123)
        self.assertFalse((self.ctx.state_root / "network.v1.json").exists())
        network.persist_started_service(self.ctx, effective)
        with patch.dict(os.environ, {}, clear=True):
            effective = network.resolve_service(self.ctx, "openchamber")
        self.assertEqual(effective["port"], 3000)
        self.assertEqual(effective["port_source"], "default")

    def test_runtime_status_follows_a_live_one_off_endpoint(self):
        pid_path = Path(self.temp.name) / "runtime.pid"
        state_path = Path(self.temp.name) / "runtime.json"
        log_path = Path(self.temp.name) / "runtime.log"
        pid_path.write_text("4242\n", encoding="utf-8")
        state_path.write_text(json.dumps({
            "pid": 4242,
            "port": 8444,
            "bind_host": "127.0.0.1",
            "connect_host": "127.0.0.1",
        }), encoding="utf-8")
        ctx = SimpleNamespace(active_profile=lambda: {})
        paths = {"pid": pid_path, "state": state_path, "log": log_path}
        with patch.object(runtime, "selected_local_runtime", return_value="llama.cpp"), \
             patch.object(runtime, "runtime_paths", return_value=paths), \
             patch.object(runtime, "is_pid_running", return_value=True), \
             patch.object(runtime, "request_json", return_value=({"status": "ok"}, "{}")):
            status = runtime.collect_runtime_status(ctx)
        self.assertEqual(status["port"], 8444)
        self.assertEqual(status["url"], "http://127.0.0.1:8444")
        self.assertTrue(status["running"])
        self.assertTrue(status["health_reachable"])

    def test_foreground_start_persists_the_endpoint_after_readiness(self):
        preset = Path(self.temp.name) / "active.ini"
        preset.write_text("[model]\n", encoding="utf-8")
        log = Path(self.temp.name) / "runtime.log"
        pid = Path(self.temp.name) / "runtime.pid"
        state = Path(self.temp.name) / "runtime.json"
        ctx = SimpleNamespace(
            active_profile=lambda: {"runtime_mode": "local"},
            active_profile_id=lambda: "micro",
            paths={"active_preset": preset},
        )
        endpoint = {
            "service": "runtime",
            "port": 8181,
            "bind_host": "127.0.0.1",
            "connect_host": "127.0.0.1",
        }

        class Process:
            pid = 4242

            def poll(self):
                return None

            def wait(self, timeout=None):
                return 0

        with patch.object(runtime, "selected_local_runtime", return_value="llama.cpp"), \
             patch.object(runtime, "collect_runtime_status", return_value={"running": False, "health_reachable": False}), \
             patch.object(runtime, "local_runtime_endpoint", return_value=endpoint), \
             patch.object(runtime, "runtime_paths", return_value={"pid": pid, "state": state, "log": log}), \
             patch("lac.config.render_opencode_config"), \
             patch.object(runtime.subprocess, "Popen", return_value=Process()), \
             patch.object(runtime, "request_json", return_value=({"status": "ok"}, "{}")), \
             patch.object(runtime, "write_runtime_state") as write_state, \
             patch.object(runtime, "persist_started_service") as persist:
            result = runtime.runtime_start(ctx, foreground=True)

        self.assertTrue(result["ok"])
        persist.assert_called_once_with(ctx, endpoint)
        self.assertIsNotNone(write_state.call_args_list[-1].args[2]["ready_at"])

    def test_automatic_fallback_uses_requested_persisted_port_window(self):
        path = self.ctx.state_root / "network.v1.json"
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps({
            "contractType": network.CONTRACT_TYPE,
            "version": network.CONTRACT_VERSION,
            "services": {"runtime": {"port": 8120, "automatic": True}},
        }), encoding="utf-8")
        with patch.dict(os.environ, {}, clear=True), patch.object(network, "_port_available", side_effect=[False, True]):
            effective = network.allocate_service(self.ctx, "runtime")
        self.assertEqual(effective["port"], 8121)

    def test_remote_bind_is_rejected_even_with_legacy_opt_in(self):
        with patch.dict(os.environ, {"LAC_BIND_HOST": "0.0.0.0"}, clear=True):
            with self.assertRaisesRegex(SystemExit, "Refusing non-loopback"):
                network.resolve_service(self.ctx, "runtime")
            with self.assertRaisesRegex(SystemExit, "Refusing non-loopback"):
                network.resolve_service(self.ctx, "runtime", allow_remote=True)

    def test_remote_host_rejects_credentials_and_non_http_schemes(self):
        self.assertEqual(network.validate_remote_host("https://100.64.0.1:4095/"), "https://100.64.0.1:4095")
        for value in ("ssh://host:4095", "http://user:secret@host:4095", "not-a-url"):
            with self.assertRaises(SystemExit):
                network.validate_remote_host(value)

    def test_reset_removes_only_persisted_record(self):
        path = self.ctx.state_root / "network.v1.json"
        path.parent.mkdir(parents=True)
        path.write_text("{}", encoding="utf-8")
        self.assertTrue(network.reset_ports(self.ctx)["reset"])
        self.assertFalse(path.exists())

    def test_openchamber_receives_selected_ports(self):
        config = Path(self.temp.name) / "opencode.json"
        config.write_text("{}", encoding="utf-8")
        ctx = SimpleNamespace(
            paths={"opencode_config": config, "opencode_config_dir": config.parent},
            state_root=self.ctx.state_root,
        )
        chamber = {"port": 4123, "connect_host": "127.0.0.1"}
        opencode = {"port": 4199, "connect_host": "127.0.0.1"}

        class Process:
            def poll(self):
                return None

        with patch.object(clients, "resolve_command", return_value="/fake/openchamber"), \
             patch.object(clients, "_inspect_before_open", return_value={"checked": True, "warnings": []}), \
             patch.object(clients, "allocate_service", side_effect=[chamber, opencode]), \
             patch.object(clients, "persist_started_service") as persist, \
             patch.object(clients.subprocess, "Popen", return_value=Process()) as popen, \
             patch.object(clients.time, "sleep"):
            result = clients.client_open(ctx, "openchamber", port=4123)
        env = popen.call_args.kwargs["env"]
        self.assertEqual(env["OPENCHAMBER_PORT"], "4123")
        self.assertEqual(env["OPENCODE_PORT"], "4199")
        self.assertEqual(env["OPENCODE_DISABLE_AUTOUPDATE"], "1")
        self.assertEqual(popen.call_args.args[0], ["/fake/openchamber", "--port", "4123"])
        self.assertEqual([call.args[1] for call in persist.call_args_list], [chamber, opencode])
        self.assertIn("127.0.0.1:4123", result["message"])
        self.assertFalse(result["reused"])
        session = json.loads((ctx.state_root / "clients/openchamber/session.json").read_text(encoding="utf-8"))
        self.assertEqual(session["openchamber"]["port"], 4123)
        self.assertEqual(session["opencode"]["port"], 4199)

    def test_openchamber_reuses_matching_managed_session(self):
        config = Path(self.temp.name) / "opencode.json"
        config.write_text("{}", encoding="utf-8")
        ctx = SimpleNamespace(
            paths={"opencode_config": config, "opencode_config_dir": config.parent},
            state_root=self.ctx.state_root,
        )
        session_path = ctx.state_root / "clients/openchamber/session.json"
        session_path.parent.mkdir(parents=True)
        session_path.write_text(json.dumps({
            "version": 1,
            "executable": "/fake/openchamber",
            "config_fingerprint": clients._openchamber_config_fingerprint(ctx),
            "remote_host": None,
            "openchamber": {"port": 3001, "connect_host": "127.0.0.1"},
            "opencode": {"port": 4096, "connect_host": "127.0.0.1"},
        }), encoding="utf-8")

        with patch.object(clients, "resolve_command", return_value="/fake/openchamber"), \
             patch.object(clients, "_inspect_before_open", return_value={"checked": True, "warnings": []}), \
             patch.object(clients, "_http_probe", return_value=True) as probe, \
             patch.object(clients, "allocate_service") as allocate, \
             patch.object(clients.subprocess, "Popen") as popen:
            result = clients.client_open(ctx, "openchamber")

        self.assertTrue(result["reused"])
        self.assertIn("127.0.0.1:3001", result["message"])
        self.assertEqual(probe.call_count, 2)
        allocate.assert_not_called()
        popen.assert_not_called()

    def test_openchamber_does_not_reuse_changed_config(self):
        config = Path(self.temp.name) / "opencode.json"
        config.write_text("{}", encoding="utf-8")
        ctx = SimpleNamespace(
            paths={"opencode_config": config, "opencode_config_dir": config.parent},
            state_root=self.ctx.state_root,
        )
        session_path = ctx.state_root / "clients/openchamber/session.json"
        session_path.parent.mkdir(parents=True)
        session_path.write_text(json.dumps({
            "version": 1,
            "executable": "/fake/openchamber",
            "config_fingerprint": "stale",
            "remote_host": None,
            "openchamber": {"port": 3001, "connect_host": "127.0.0.1"},
            "opencode": {"port": 4096, "connect_host": "127.0.0.1"},
        }), encoding="utf-8")
        chamber = {"service": "openchamber", "port": 3002, "connect_host": "127.0.0.1"}
        opencode = {"service": "opencode", "port": 4097, "connect_host": "127.0.0.1"}

        class Process:
            def poll(self):
                return None

        with patch.object(clients, "resolve_command", return_value="/fake/openchamber"), \
             patch.object(clients, "_inspect_before_open", return_value={"checked": True, "warnings": []}), \
             patch.object(clients, "allocate_service", side_effect=[chamber, opencode]), \
             patch.object(clients, "persist_started_service"), \
             patch.object(clients.subprocess, "Popen", return_value=Process()) as popen, \
             patch.object(clients.time, "sleep"):
            result = clients.client_open(ctx, "openchamber")

        self.assertFalse(result["reused"])
        popen.assert_called_once()

    def test_automatic_range_is_capped_at_valid_tcp_port(self):
        state = self.ctx.state_root / "network.v1.json"
        state.parent.mkdir(parents=True)
        state.write_text(json.dumps({
            "contractType": network.CONTRACT_TYPE,
            "version": network.CONTRACT_VERSION,
            "services": {"runtime": {"port": 65535, "automatic": True}},
        }), encoding="utf-8")
        with patch.dict(os.environ, {}, clear=True), \
             patch.object(network, "_port_available", return_value=False):
            with self.assertRaisesRegex(SystemExit, "65535-65535"):
                network.allocate_service(self.ctx, "runtime")

    def test_openchamber_remote_mode_does_not_allocate_or_start_local_opencode(self):
        config = Path(self.temp.name) / "opencode.json"
        config.write_text("{}", encoding="utf-8")
        ctx = SimpleNamespace(
            paths={"opencode_config": config, "opencode_config_dir": config.parent},
            state_root=self.ctx.state_root,
        )
        chamber = {"port": 4123, "connect_host": "127.0.0.1"}

        class Process:
            def poll(self):
                return None

        with patch.dict(os.environ, {}, clear=True), \
             patch.object(clients, "resolve_command", return_value="/fake/openchamber"), \
             patch.object(clients, "_inspect_before_open", return_value={"checked": True, "warnings": []}), \
             patch.object(clients, "allocate_service", return_value=chamber) as allocate, \
             patch.object(clients, "persist_started_service"), \
             patch.object(clients.subprocess, "Popen", return_value=Process()) as popen, \
             patch.object(clients.time, "sleep"):
            result = clients.client_open(ctx, "openchamber", remote_host="https://100.64.0.1:4095")
        allocate.assert_called_once()
        env = popen.call_args.kwargs["env"]
        self.assertEqual(env["OPENCODE_HOST"], "https://100.64.0.1:4095")
        self.assertEqual(env["OPENCODE_SKIP_START"], "true")
        self.assertNotIn("OPENCODE_PORT", env)
        self.assertIn("connecting to https://100.64.0.1:4095", result["message"])

    def test_openchamber_desktop_receives_and_records_selected_ports(self):
        config = Path(self.temp.name) / "opencode.json"
        config.write_text("{}", encoding="utf-8")
        ctx = SimpleNamespace(
            paths={"opencode_config": config, "opencode_config_dir": config.parent},
            state_root=self.ctx.state_root,
        )
        chamber = {"port": 4123, "connect_host": "127.0.0.1"}
        opencode = {"port": 4199, "connect_host": "127.0.0.1"}

        class Process:
            def poll(self):
                return None

        with patch.object(clients, "resolve_command", return_value="/fake/openchamber"), \
             patch.object(clients, "_inspect_before_open", return_value={"checked": True, "warnings": []}), \
             patch.object(clients, "allocate_service", side_effect=[chamber, opencode]), \
             patch.object(clients.sys, "platform", "darwin"), \
             patch.object(clients.Path, "is_file", return_value=True), \
             patch.object(clients, "persist_started_service") as persist, \
             patch.object(clients.subprocess, "Popen", return_value=Process()) as popen, \
             patch.object(clients.time, "sleep"):
            result = clients.client_open(ctx, "openchamber", desktop=True, port=4123)
        self.assertEqual(popen.call_args.args[0][-2:], ["--port", "4123"])
        self.assertEqual([call.args[1] for call in persist.call_args_list], [chamber, opencode])
        self.assertTrue(result["desktop"])


if __name__ == "__main__":
    unittest.main()
