"""Runtime lifecycle: start, stop, status for llama.cpp, oMLX, and ds4."""

import os
import signal
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

from lac.network import allocate_service, persist_started_service, resolve_service, url


def log_info(message):
    import sys
    print(message, file=sys.stderr)


def command_exists(name):
    import shutil
    return shutil.which(name) is not None


LOCAL_MLX_MODEL_IDS = {
    "qwen3.6-27b-q3": "Qwen3.6-27B-UD-MLX-6bit",
    "qwen3.6-27b-q4": "Qwen3.6-27B-UD-MLX-6bit",
    "qwen3.6-35b-a3b-q8": "Qwen3.6-35B-A3B-MLX-8bit",
    "gemma-4-31b-q4": "gemma-4-31b-it-UD-MLX-4bit",
    "gemma-4-31b-q8": "gemma-4-31b-it-UD-MLX-8bit",
    "gemma-4-31b-bf16": "gemma-4-31b-it-UD-MLX-bf16",
    "gemma-4-e4b-q8": "gemma-4-E4B-it-MLX-8bit",
    "gemma-4-26b-a4b-q4": "gemma-4-26b-a4b-it-UD-MLX-8bit",
}


def _local_model_name(selector):
    if not selector.startswith("local-cluster/"):
        return ""
    return selector.split("/", 1)[1]


def _profile_supports_omlx(profile, verbose=False):
    if not profile or profile.get("runtime_mode") != "local":
        if verbose:
            log_info(f"[omlx] Profile '{profile.get('id', '?')}' rejected: not a local runtime profile")
        return False
    # Only the default model gates oMLX eligibility: the small model is a
    # title/compaction helper and is substituted at render time when unmapped.
    default_id = _local_model_name(profile.get("default_model", ""))
    if default_id and default_id not in LOCAL_MLX_MODEL_IDS:
        if verbose:
            log_info(f"[omlx] Profile '{profile.get('id')}' rejected: no MLX model ID mapped for {default_id}")
        return False
    return bool(default_id)


def _normalize_local_runtime(value):
    normalized = (value or "").strip().lower()
    if normalized in {"", "auto"}:
        return "auto"
    if normalized in {"omlx", "mlx"}:
        return "omlx"
    if normalized in {"ds4", "dwarfstar"}:
        return "ds4"
    if normalized in {"llama", "llama.cpp", "llamacpp", "llama-server"}:
        return "llama.cpp"
    raise SystemExit(f"Unsupported AI_LOCAL_RUNTIME: {value}. Use auto, ds4, omlx, or llama.cpp.")


def selected_local_runtime(profile=None, verbose=False):
    import sys
    requested = _normalize_local_runtime(os.environ.get("AI_LOCAL_RUNTIME", "auto"))
    if requested != "auto":
        if requested == "ds4" and profile and profile.get("runtime_mode") != "local":
            if verbose:
                log_info("[runtime] Requested ds4 runtime is only compatible with local profiles. Falling back to llama.cpp.")
        elif requested == "omlx" and sys.platform != "darwin":
            if verbose:
                log_info(f"[runtime] oMLX is only supported on macOS. Ignoring AI_LOCAL_RUNTIME=omlx.")
        elif requested == "omlx" and not _profile_supports_omlx(profile, verbose=verbose):
            if verbose:
                log_info("[runtime] Requested oMLX runtime is not compatible with this profile. Falling back to llama.cpp.")
        else:
            if verbose:
                log_info(f"[runtime] Using requested runtime: {requested}")
            return requested
    if profile and profile.get("preferred_runtime") == "ds4":
        if verbose:
            log_info("[runtime] Auto-selected ds4 runtime from profile preference")
        return "ds4"
    if sys.platform == "darwin" and _profile_supports_omlx(profile, verbose=False):
        omlx_bin = os.environ.get("OMLX_BIN", "omlx")
        if not command_exists(omlx_bin):
            if verbose:
                log_info(f"[runtime] oMLX auto-selection skipped: `{omlx_bin}` is not in PATH")
        else:
            if verbose:
                log_info(f"[runtime] Auto-selected oMLX runtime (macOS + MLX models detected)")
            return "omlx"
    elif verbose and sys.platform == "darwin":
        log_info("[runtime] oMLX auto-selection skipped: profile is not eligible")
    if verbose:
        log_info(f"[runtime] Using default runtime: llama.cpp")
    return "llama.cpp"


def runtime_paths(ctx, runtime):
    if runtime == "omlx":
        return {
            "pid": ctx.paths["omlx_pid"],
            "state": ctx.paths["omlx_state"],
            "log": ctx.paths["omlx_log"],
            "label": "oMLX",
        }
    if runtime == "ds4":
        return {
            "pid": ctx.paths["ds4_pid"],
            "state": ctx.paths["ds4_state"],
            "log": ctx.paths["ds4_log"],
            "label": "ds4",
        }
    return {
        "pid": ctx.paths["llama_pid"],
        "state": ctx.paths["llama_state"],
        "log": ctx.paths["llama_log"],
        "label": "llama.cpp",
    }


def runtime_service(runtime):
    return runtime if runtime in {"omlx", "ds4"} else "runtime"


def local_runtime_endpoint(ctx, runtime, *, port=None, bind_host=None, allow_remote=False, allocate=False):
    resolver = allocate_service if allocate else resolve_service
    return resolver(
        ctx, runtime_service(runtime), cli_port=port, cli_bind_host=bind_host, allow_remote=allow_remote
    )


def local_runtime_port(ctx, runtime):
    return local_runtime_endpoint(ctx, runtime)["port"]


def local_runtime_base_url(ctx, runtime):
    endpoint = local_runtime_endpoint(ctx, runtime)
    return url(endpoint["connect_host"], endpoint["port"])


def _windows_pid_running(pid):
    """Query a Windows process without sending a signal to it."""
    import ctypes
    from ctypes import wintypes

    synchronize = 0x00100000
    wait_timeout = 0x00000102
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel32.OpenProcess.restype = wintypes.HANDLE
    kernel32.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    kernel32.WaitForSingleObject.restype = wintypes.DWORD
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL

    handle = kernel32.OpenProcess(synchronize, False, pid)
    if not handle:
        return False
    try:
        return kernel32.WaitForSingleObject(handle, 0) == wait_timeout
    finally:
        kernel32.CloseHandle(handle)


def is_pid_running(pid):
    if not pid:
        return False
    if os.name == "nt":
        return _windows_pid_running(pid)
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def log_tail_hint(log_path):
    if os.name == "nt":
        escaped = str(log_path).replace("'", "''")
        return f"Get-Content -Path '{escaped}' -Wait -Tail 50"
    return f"tail -f {log_path}"


def _background_process_options():
    if os.name == "nt":
        return subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS, {}
    return 0, {"start_new_session": True}


def request_json(url, method="GET", payload=None, timeout=5, headers=None):
    import json
    import urllib.request
    import urllib.error
    request_headers = dict(headers or {})
    data = None
    if payload is not None:
        request_headers["Content-Type"] = "application/json"
        data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(url, data=data, headers=request_headers, method=method)
    with urllib.request.urlopen(request, timeout=timeout) as response:
        raw = response.read().decode("utf-8")
    return json.loads(raw), raw


def collect_runtime_status(ctx, endpoint=None):
    profile = ctx.active_profile()
    runtime = selected_local_runtime(profile)
    paths = runtime_paths(ctx, runtime)
    pid_path = paths["pid"]
    state_path = paths["state"]
    log_path = paths["log"]
    pid = 0
    running = False
    if pid_path.is_file():
        try:
            pid = int(pid_path.read_text(encoding="utf-8").strip())
        except ValueError:
            pid = 0
        running = is_pid_running(pid)
    launch = None
    if state_path.is_file():
        import json
        launch = json.loads(state_path.read_text(encoding="utf-8"))
    # A one-off explicit CLI endpoint is intentionally not reused for a later
    # start, but status still has to follow the process that is currently alive.
    if endpoint is None and running and launch:
        endpoint = {
            "port": int(launch["port"]),
            "bind_host": launch["bind_host"],
            "connect_host": launch["connect_host"],
        }
    endpoint = endpoint or local_runtime_endpoint(ctx, runtime)
    port = endpoint["port"]
    health_path = "/v1/models" if runtime in {"omlx", "ds4"} else "/health"
    runtime_info = {
        "runtime": runtime,
        "bind_host": endpoint["bind_host"],
        "connect_host": endpoint["connect_host"],
        "port": port,
        "url": url(endpoint["connect_host"], port),
        "log_path": str(log_path),
        "pid_path": str(pid_path),
        "running": running,
        "health_reachable": False,
    }
    if pid_path.is_file():
        runtime_info["pid"] = pid
    if launch is not None:
        runtime_info["launch"] = launch
    try:
        health, _ = request_json(url(endpoint["connect_host"], port, health_path), timeout=2)
        runtime_info["health_reachable"] = True
        runtime_info["health"] = health
    except Exception:
        runtime_info["health_reachable"] = False
    return runtime_info


def write_runtime_state(state_path, pid_path, payload):
    import json
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    pid_path.parent.mkdir(parents=True, exist_ok=True)
    pid_path.write_text(f"{payload['pid']}\n", encoding="utf-8")


def runtime_start(ctx, show_logs=False, tail_hint=True, foreground=False, port=None, bind_host=None, allow_remote=False):
    profile = ctx.active_profile()
    profile_id = ctx.active_profile_id()
    if profile and profile["runtime_mode"] == "cloud":
        return {
            "ok": True,
            "skipped": True,
            "reason": f"Active profile '{profile_id}' is cloud-only.",
        }
    preset = ctx.paths["active_preset"]
    if not preset.is_file():
        raise SystemExit(f"Missing preset file: {preset}\nRun ./bin/lac profile apply <profile> first.")
    runtime = selected_local_runtime(profile, verbose=True)
    status = collect_runtime_status(ctx)
    if status["running"] and status["health_reachable"]:
        if port is not None or bind_host is not None:
            requested_endpoint = local_runtime_endpoint(
                ctx, runtime, port=port, bind_host=bind_host, allow_remote=allow_remote
            )
            if (
                requested_endpoint["port"] != status["port"]
                or requested_endpoint["bind_host"] != status["bind_host"]
            ):
                raise SystemExit(
                    f"{runtime} is already running at {status['url']}. "
                    "Stop it with `lac runtime stop` before changing its endpoint."
                )
        return {
            "ok": True,
            "running": True,
            "message": f"{runtime} already running at {status['url']}",
            "log_path": status.get("log_path"),
        }
    endpoint = local_runtime_endpoint(
        ctx, runtime, port=port, bind_host=bind_host, allow_remote=allow_remote, allocate=True
    )
    port = endpoint["port"]
    bind_host = endpoint["bind_host"]
    base_url = url(endpoint["connect_host"], port)
    # Render the transient requested/fallback endpoint before launch; persistence
    # happens only after the server proves it is ready.
    from lac.config import render_opencode_config
    render_opencode_config(ctx, profile_id, profile, verbose_runtime=False, runtime_endpoint=endpoint)
    paths = runtime_paths(ctx, runtime)
    pid_path = paths["pid"]
    state_path = paths["state"]
    log_path = paths["log"]
    log_path.parent.mkdir(parents=True, exist_ok=True)
    if log_path.exists():
        backup = log_path.with_suffix(log_path.suffix + ".1")
        if backup.exists():
            backup.unlink()
        log_path.replace(backup)
    env = os.environ.copy()
    launch_cwd = None
    if runtime == "omlx":
        if not command_exists(os.environ.get("OMLX_BIN", "omlx")):
            raise SystemExit("oMLX runtime selected but `omlx` is not in PATH. Install with Homebrew or set AI_LOCAL_RUNTIME=llama.cpp.")
        models_dir = ctx.models_root / "mlx"
        env["OMLX_MODEL_DIR"] = str(models_dir)
        env["OMLX_HOST"] = bind_host
        env["OMLX_PORT"] = str(port)
        command = [os.environ.get("OMLX_BIN", "omlx"), "serve", "--model-dir", str(models_dir)]
        ready_url = f"{base_url}/v1/models"
    elif runtime == "ds4":
        ds4_bin = os.environ.get("DS4_BIN", "ds4-server")
        if not command_exists(ds4_bin):
            raise SystemExit("ds4 runtime selected but `ds4-server` is not in PATH. Build antirez/ds4 and set DS4_BIN, or set AI_LOCAL_RUNTIME=llama.cpp.")
        models_dir = ctx.models_root
        model_path = Path(os.environ.get("DS4_MODEL", str(models_dir / "ds4" / "ds4flash.gguf")))
        if not model_path.is_file():
            raise SystemExit(f"Missing ds4 model file: {model_path}\nRun ./bin/lac models sync 128gb-ds4-flash first, or set DS4_MODEL.")
        kv_dir = ctx.paths["ds4_kv"]
        kv_dir.mkdir(parents=True, exist_ok=True)
        command = [
            ds4_bin,
            "-m",
            str(model_path),
            "--ctx",
            os.environ.get("DS4_CTX", "262144"),
            "--kv-disk-dir",
            str(kv_dir),
            "--kv-disk-space-mb",
            os.environ.get("DS4_KV_DISK_SPACE_MB", "8192"),
            "--host",
            bind_host,
            "--port",
            str(port),
        ]
        ready_url = f"{base_url}/v1/models"
        launch_cwd = str(Path(ds4_bin).resolve().parent)
    else:
        env["LLAMA_ARG_JINJA"] = "true"
        command = [
            os.environ.get("LLAMA_SERVER_BIN", "llama-server"),
            "--jinja",
            "--models-preset",
            str(preset),
            "--port",
            str(port),
            "--host",
            bind_host,
        ]
        ready_url = f"{base_url}/health"

    def _write_runtime_state(payload):
        write_runtime_state(state_path, pid_path, payload)

    if foreground:
        started_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
        def _foreground_cleanup(signum=None, frame=None):
            if signum is not None:
                log_info(f"\n[{runtime}] Received signal {signum}, shutting down...")
            try:
                process.terminate()
                process.wait(timeout=5)
            except (subprocess.TimeoutExpired, OSError):
                try:
                    process.kill()
                    process.wait(timeout=3)
                except Exception:
                    pass
            pid_path.unlink(missing_ok=True)
            if signum is not None:
                raise SystemExit(128 + signum)
        original_sigint = signal.getsignal(signal.SIGINT)
        original_sigterm = signal.getsignal(signal.SIGTERM)
        signal.signal(signal.SIGINT, _foreground_cleanup)
        signal.signal(signal.SIGTERM, _foreground_cleanup)
        process = subprocess.Popen(command, env=env, cwd=launch_cwd)
        payload = {
            "started_at": started_at,
            "ready_at": None,
            "launch_latency_ms": None,
            "pid": process.pid,
            "port": port,
            "bind_host": bind_host,
            "connect_host": endpoint["connect_host"],
            "log_path": str(log_path),
            "profile_id": profile_id,
            "runtime": runtime,
            "foreground": True,
        }
        _write_runtime_state(payload)
        try:
            ready = False
            for _ in range(60):
                if process.poll() is not None:
                    break
                try:
                    request_json(ready_url, timeout=2)
                    ready = True
                    break
                except Exception:
                    time.sleep(1)
            if not ready:
                exit_code = process.poll()
                _foreground_cleanup()
                raise SystemExit(
                    f"{runtime} foreground process did not become ready at {ready_url}"
                    + (f" (exit code {exit_code})" if exit_code is not None else "")
                )
            ready_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
            payload["ready_at"] = ready_at
            payload["launch_latency_ms"] = int(
                (datetime.fromisoformat(ready_at.replace("Z", "+00:00"))
                 - datetime.fromisoformat(started_at.replace("Z", "+00:00"))).total_seconds() * 1000
            )
            _write_runtime_state(payload)
            persist_started_service(ctx, endpoint)
            exit_code = process.wait()
        finally:
            signal.signal(signal.SIGINT, original_sigint)
            signal.signal(signal.SIGTERM, original_sigterm)
            pid_path.unlink(missing_ok=True)
        return {
            "ok": exit_code == 0,
            "running": False,
            "foreground": True,
            "exit_code": exit_code,
            "message": f"{runtime} exited with code {exit_code}",
        }

    started_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    flags, kwargs = _background_process_options()
    log_handle = log_path.open("a", encoding="utf-8")
    process = subprocess.Popen(
        command,
        stdout=log_handle,
        stderr=subprocess.STDOUT,
        env=env,
        cwd=launch_cwd,
        creationflags=flags,
        **kwargs,
    )
    ready = False
    for _ in range(60):
        time.sleep(1)
        if process.poll() is not None:
            break
        try:
            request_json(ready_url, timeout=2)
            ready = True
            break
        except Exception:
            continue
    if not ready:
        log_handle.close()
        recent = ""
        if log_path.exists():
            recent = "\n".join(log_path.read_text(encoding="utf-8").splitlines()[-20:])
        raise SystemExit(f"{runtime} failed to start.\nRecent logs:\n{recent}")
    ready_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    payload = {
        "started_at": started_at,
        "ready_at": ready_at,
        "launch_latency_ms": int((datetime.fromisoformat(ready_at.replace("Z", "+00:00")) - datetime.fromisoformat(started_at.replace("Z", "+00:00"))).total_seconds() * 1000),
        "pid": process.pid,
        "port": port,
        "bind_host": bind_host,
        "connect_host": endpoint["connect_host"],
        "log_path": str(log_path),
        "profile_id": profile_id,
        "runtime": runtime,
    }
    _write_runtime_state(payload)
    persist_started_service(ctx, endpoint)
    log_handle.close()
    result = {
        "ok": True,
        "running": True,
        "runtime": runtime,
        "url": base_url,
        "log_path": str(log_path),
        "launch_latency_ms": payload["launch_latency_ms"],
    }
    if show_logs and command_exists("tail") and os.name != "nt":
        subprocess.run(["tail", "-f", str(log_path)], check=False)
    elif tail_hint:
        result["tail_hint"] = log_tail_hint(log_path)
    return result


def runtime_stop(ctx):
    runtime = selected_local_runtime(ctx.active_profile())
    paths = runtime_paths(ctx, runtime)
    pid_path = paths["pid"]
    label = paths["label"]
    if not pid_path.is_file():
        return {"ok": True, "running": False, "message": f"No {label} pid file found."}
    pid = int(pid_path.read_text(encoding="utf-8").strip())
    if not is_pid_running(pid):
        pid_path.unlink(missing_ok=True)
        return {"ok": True, "running": False, "message": f"{label} process was not running."}
    sig = signal.SIGTERM
    os.kill(pid, sig)
    for _ in range(10):
        time.sleep(0.5)
        if not is_pid_running(pid):
            break
    if is_pid_running(pid):
        os.kill(pid, signal.SIGKILL if os.name != "nt" else signal.SIGTERM)
    pid_path.unlink(missing_ok=True)
    return {"ok": True, "running": False, "message": f"Stopped {label} pid {pid}."}


def runtime_status(ctx):
    report = collect_runtime_status(ctx)
    report["active_profile_id"] = ctx.active_profile_id()
    return report
