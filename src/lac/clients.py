"""Client integrations: render adapters, open clients."""

import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib import error as urlerror
from urllib import request as urlrequest

from lac.network import allocate_service, persist_started_service, url as network_url, validate_remote_host
from lac.opencode import inspect_opencode_coexistence, opencode_env, print_opencode_warnings


def utc_now():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def resolve_command(name):
    found = shutil.which(name)
    if found or name != "openchamber":
        return found

    home = Path.home()
    roots = []
    pnpm_home = os.environ.get("PNPM_HOME")
    if pnpm_home:
        roots.extend((Path(pnpm_home) / "bin", Path(pnpm_home)))
    roots.extend((
        home / "Library/pnpm/bin",
        home / "Library/pnpm",
        home / ".local/share/pnpm/bin",
        home / ".local/share/pnpm",
        home / ".openchamber/bin",
    ))
    names = (name, f"{name}.cmd", f"{name}.exe") if os.name == "nt" else (name,)
    for root in roots:
        for candidate_name in names:
            candidate = root / candidate_name
            if candidate.is_file() and (os.name == "nt" or os.access(candidate, os.X_OK)):
                return str(candidate)
    return None


def command_exists(name):
    return resolve_command(name) is not None


def render_client(ctx, target):
    from lac.packs import build_pack_summary
    packs = build_pack_summary(ctx)
    manifest = {
        "generated_at": utc_now(),
        "target": target,
        "pack_count": len(packs),
        "packs": packs,
    }
    if target == "opencode":
        out_path = ctx.paths["opencode_config_dir"] / "manifest.json"
        out_path.parent.mkdir(parents=True, exist_ok=True)
        for asset_type, source in (
            ("agents", ctx.paths["opencode_agents_dir"]),
            ("skills", ctx.paths["opencode_skills_dir"]),
        ):
            destination = ctx.paths["opencode_config_dir"] / asset_type
            if destination.exists():
                shutil.rmtree(destination)
            if not ctx._is_repo and source.is_dir():
                shutil.copytree(source, destination)
        out_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        manifest_path = out_path
        if ctx._is_repo:
            repo_manifest = ctx.root / ".opencode/render-manifest.json"
            repo_manifest.parent.mkdir(parents=True, exist_ok=True)
            repo_manifest.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
            manifest_path = repo_manifest
        return {
            "target": target,
            "manifest_path": str(manifest_path),
            "pack_count": len(packs),
            "packs": packs,
            "runtime_asset_root": str(ctx.paths["opencode_agents_dir"].parent),
        }
    if target == "claude-code":
        target_root = ctx.state_root / "clients/claude-code"
        target_root.mkdir(parents=True, exist_ok=True)
        template_root = ctx.root / "templates/claude-code"
        shutil.copytree(template_root, target_root / "templates", dirs_exist_ok=True)
        lines = [
            "# Claude Code Adapter", "",
            "This adapter reuses the curated lac workflow packs as references for Claude Code.",
            "", "## Included Packs", "",
        ]
        for pack in packs:
            lines.append(f"- `{pack['id']}`: {pack['description']}")
        lines.append("")
        lines.append("OpenCode remains the lead runtime target. This adapter is a reviewed reference bundle.")
        (target_root / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
        (target_root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        return {
            "target": target,
            "manifest_path": str(target_root / "manifest.json"),
            "pack_count": len(packs),
            "packs": packs,
            "render_root": str(target_root),
        }
    if target == "codex-reference":
        target_root = ctx.state_root / "clients/codex-reference"
        target_root.mkdir(parents=True, exist_ok=True)
        lines = [
            "# Codex Reference Adapter", "",
            "This adapter provides a reference view of the curated workflow packs for Codex-style environments.",
            "", "## Workflow Packs", "",
        ]
        for pack in packs:
            lines.append(f"- `{pack['id']}`: trust `{pack['trust_level']}`, tools `{', '.join(pack['required_tools'])}`")
        lines.append("")
        lines.append("Use the asset catalog for source attribution, support tier, and permission notes.")
        (target_root / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
        (target_root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        return {
            "target": target,
            "manifest_path": str(target_root / "manifest.json"),
            "pack_count": len(packs),
            "packs": packs,
            "render_root": str(target_root),
        }
    if target == "openchamber":
        target_root = ctx.state_root / "clients/openchamber"
        target_root.mkdir(parents=True, exist_ok=True)
        lines = [
            "# OpenChamber Adapter", "",
            "This adapter generates connection config for OpenChamber — the web/PWA/desktop UI for OpenCode.",
            "", "## Included Packs", "",
        ]
        for pack in packs:
            lines.append(f"- `{pack['id']}`: {pack['description']}")
        lines.append("")
        lines.append("Launch with: lac client open openchamber")
        lines.append("Remote access: lac client open openchamber --remote-host http://<tailscale-ip>:4095")
        (target_root / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
        (target_root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        env_lines = [
            "# Generated by lac — point OpenChamber at this cluster's OpenCode config",
            f"OPENCODE_CONFIG={ctx.paths['opencode_config']}",
            f"OPENCODE_CONFIG_DIR={ctx.paths['opencode_config_dir']}",
            "OPENCODE_DISABLE_AUTOUPDATE=1",
        ]
        (target_root / "openchamber.env").write_text("\n".join(env_lines) + "\n", encoding="utf-8")
        return {
            "target": target,
            "manifest_path": str(target_root / "manifest.json"),
            "pack_count": len(packs),
            "packs": packs,
            "render_root": str(target_root),
        }
    raise SystemExit(f"Unsupported client target: {target}")


def _inspect_before_open(ctx, env):
    profile = ctx.active_profile() if hasattr(ctx, "active_profile") else None
    report = inspect_opencode_coexistence(
        ctx,
        profile=profile,
        env=env,
        command=resolve_command("opencode"),
    )
    print_opencode_warnings(report)
    return report


def _openchamber_session_path(ctx):
    return ctx.state_root / "clients/openchamber/session.json"


def _openchamber_config_fingerprint(ctx):
    digest = hashlib.sha256()
    paths = [ctx.paths["opencode_config"]]
    dcp_config = ctx.paths.get("dcp_config")
    if dcp_config:
        paths.append(dcp_config)
    for path in paths:
        path = Path(path)
        if not path.is_file():
            return ""
        digest.update(str(path.name).encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def _http_probe(host, port, path="/", marker=None):
    try:
        with urlrequest.urlopen(network_url(host, port) + path, timeout=2) as response:
            body = response.read(65536).decode("utf-8", errors="ignore")
        return marker is None or marker.lower() in body.lower()
    except urlerror.HTTPError as exc:
        # OpenCode protects its HTTP surface and answers unauthenticated health
        # requests with 401/403. OpenChamber may do the same when its optional
        # UI password is enabled. Either response proves the endpoint exists.
        return exc.code in {401, 403}
    except (OSError, TypeError, ValueError, urlerror.URLError, TimeoutError):
        return False


def _reusable_openchamber_session(ctx, command, *, desktop, remote_host, port):
    if desktop:
        return None
    path = _openchamber_session_path(ctx)
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if state.get("version") != 1 or state.get("executable") != str(command):
        return None
    if state.get("remote_host") != remote_host:
        return None
    chamber = state.get("openchamber", {})
    if port is not None and chamber.get("port") != int(port):
        return None
    if state.get("config_fingerprint") != _openchamber_config_fingerprint(ctx):
        return None
    if not _http_probe(chamber.get("connect_host", "127.0.0.1"), chamber.get("port"), marker="OpenChamber"):
        return None
    opencode = state.get("opencode")
    if remote_host is None:
        if not isinstance(opencode, dict):
            return None
        if not _http_probe(opencode.get("connect_host", "127.0.0.1"), opencode.get("port"), path="/global/health"):
            return None
    return state


def _write_openchamber_session(ctx, command, chamber, opencode=None, remote_host=None):
    path = _openchamber_session_path(ctx)
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "version": 1,
        "started_at": utc_now(),
        "executable": str(command),
        "config_fingerprint": _openchamber_config_fingerprint(ctx),
        "remote_host": remote_host,
        "openchamber": {
            "port": chamber["port"],
            "bind_host": chamber.get("bind_host", "127.0.0.1"),
            "connect_host": chamber.get("connect_host", "127.0.0.1"),
        },
        "opencode": None if opencode is None else {
            "port": opencode["port"],
            "bind_host": opencode.get("bind_host", "127.0.0.1"),
            "connect_host": opencode.get("connect_host", "127.0.0.1"),
        },
    }
    temporary = path.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def client_open(ctx, target, desktop=False, remote_host=None, port=None):
    config_path = ctx.paths["opencode_config"]

    if target == "openchamber":
        openchamber_command = resolve_command("openchamber")
        if not openchamber_command:
            if sys.platform.startswith("win"):
                raise SystemExit(
                    "OpenChamber CLI launcher not found. Native Windows auto-launch is not implemented.\n"
                    "Install OpenChamber Desktop from https://github.com/openchamber/openchamber/releases, "
                    "or use the CLI installer inside WSL/Git Bash. Go/Zen are hosted and not local-only."
                )
            raise SystemExit(
                "OpenChamber launcher not found in PATH or common pnpm install locations.\n"
                "Install the v0.3-tested client: pnpm add -g @openchamber/web@1.16.3"
            )
        if not config_path.is_file():
            raise SystemExit(f"Missing generated OpenCode config: {config_path}\nRun ./bin/lac profile apply <profile> first.")
        env = opencode_env(ctx)
        normalized_remote_host = validate_remote_host(remote_host) if remote_host else None
        coexistence = _inspect_before_open(ctx, env)
        existing = _reusable_openchamber_session(
            ctx,
            openchamber_command,
            desktop=desktop,
            remote_host=normalized_remote_host,
            port=port,
        )
        if existing:
            chamber = existing["openchamber"]
            return {
                "ok": True,
                "target": target,
                "desktop": False,
                "reused": True,
                "message": (
                    "OpenChamber is already running at "
                    f"{network_url(chamber['connect_host'], chamber['port'])}; reusing the managed session."
                ),
                "opencode_coexistence": coexistence,
            }
        chamber = allocate_service(ctx, "openchamber", cli_port=port)
        # OpenChamber and the OpenCode server own their process lifecycles. lac
        # supplies explicit ports but does not broaden their bind address.
        env["OPENCHAMBER_PORT"] = str(chamber["port"])
        if normalized_remote_host:
            env["OPENCODE_HOST"] = normalized_remote_host
            env["OPENCODE_SKIP_START"] = "true"
        else:
            opencode = allocate_service(ctx, "opencode")
            env["OPENCODE_PORT"] = str(opencode["port"])
        if desktop:
            app_name = "OpenChamber"
            if sys.platform == "darwin":
                candidates = [
                    Path("/Applications") / f"{app_name}.app" / "Contents/MacOS" / app_name,
                    Path.home() / "Applications" / f"{app_name}.app" / "Contents/MacOS" / app_name,
                ]
                for executable in candidates:
                    if executable.is_file():
                        process = subprocess.Popen(
                            [str(executable), "--port", str(chamber["port"])],
                            env=env,
                            start_new_session=True,
                        )
                        time.sleep(1)
                        if process.poll() is not None:
                            raise SystemExit(f"OpenChamber Desktop exited during startup with code {process.returncode}.")
                        persist_started_service(ctx, chamber)
                        if not remote_host:
                            persist_started_service(ctx, opencode)
                        return {
                            "ok": True, "target": target, "desktop": True,
                            "message": f"Launched {app_name} desktop connecting to OpenCode config: {config_path}",
                            "opencode_coexistence": coexistence,
                        }
                if command_exists("open"):
                    result = subprocess.run(
                        ["open", "-a", app_name, "--args", "--port", str(chamber["port"])],
                        env=env,
                        check=False,
                    )
                    if result.returncode != 0:
                        raise SystemExit(f"Failed to launch {app_name}. Install OpenChamber Desktop from https://github.com/openchamber/openchamber/releases")
                    persist_started_service(ctx, chamber)
                    if not remote_host:
                        persist_started_service(ctx, opencode)
                    return {
                        "ok": True, "target": target, "desktop": True,
                        "message": f"Launched {app_name} desktop. If it was already running, fully quit and restart it so env vars are picked up.",
                        "opencode_coexistence": coexistence,
                    }
            raise SystemExit("Desktop auto-launch is only implemented for macOS.")
        process = subprocess.Popen([openchamber_command, "--port", str(chamber["port"])], env=env, start_new_session=True)
        time.sleep(1)
        if process.poll() is not None:
            raise SystemExit(f"OpenChamber exited during startup with code {process.returncode}.")
        persist_started_service(ctx, chamber)
        if not normalized_remote_host:
            persist_started_service(ctx, opencode)
        _write_openchamber_session(
            ctx,
            openchamber_command,
            chamber,
            opencode=None if normalized_remote_host else opencode,
            remote_host=normalized_remote_host,
        )
        hint = (
            f"OpenChamber web UI should be available at {network_url(chamber['connect_host'], chamber['port'])}"
            if not normalized_remote_host else f"OpenChamber connecting to {env['OPENCODE_HOST']}"
        )
        return {
            "ok": True,
            "target": target,
            "desktop": False,
            "reused": False,
            "message": hint,
            "opencode_coexistence": coexistence,
        }

    if target != "opencode":
        raise SystemExit("Only 'opencode' and 'openchamber' targets support launch.")
    if not config_path.is_file():
        raise SystemExit(f"Missing generated OpenCode config: {config_path}\nRun ./bin/lac profile apply <profile> first.")
    env = opencode_env(ctx)
    coexistence = _inspect_before_open(ctx, env)
    if desktop:
        app_name = os.environ.get("OPENCODE_DESKTOP_APP", "OpenCode")
        if sys.platform == "darwin":
            candidates = [
                Path("/Applications") / f"{app_name}.app" / "Contents/MacOS" / app_name,
                Path.home() / "Applications" / f"{app_name}.app" / "Contents/MacOS" / app_name,
            ]
            for executable in candidates:
                if executable.is_file():
                    subprocess.Popen([str(executable)], env=env, start_new_session=True)
                    return {
                        "ok": True, "target": target, "desktop": True,
                        "message": f"Launched {app_name} desktop with generated config: {config_path}",
                        "opencode_coexistence": coexistence,
                    }
            if command_exists("open"):
                result = subprocess.run(["open", "-a", app_name], env=env, check=False)
                if result.returncode != 0:
                    raise SystemExit(f"Failed to launch {app_name}. Set OPENCODE_DESKTOP_APP if the app name differs.")
                return {
                    "ok": True, "target": target, "desktop": True,
                    "message": f"Launched {app_name} desktop. If it was already running, fully quit and restart it so OPENCODE_CONFIG is picked up: {config_path}",
                    "opencode_coexistence": coexistence,
                }
        raise SystemExit("Desktop auto-launch is only implemented for macOS.")
    if not command_exists("opencode"):
        raise SystemExit("opencode is not in PATH.")
    completed = subprocess.run(["opencode"], env=env, check=False)
    return {
        "ok": completed.returncode == 0,
        "target": target,
        "desktop": False,
        "opencode_coexistence": coexistence,
    }
