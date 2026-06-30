"""Runtime lifecycle: start, stop, status for llama.cpp, oMLX, and ds4."""

import os
import signal
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

from lac.context import HOST, PORT, OMLX_PORT, DS4_PORT, ROOT, STATE_ROOT


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
    model_ids = {
        _local_model_name(profile.get("default_model", "")),
        _local_model_name(profile.get("small_model", "")),
    }
    unsupported = [mid for mid in model_ids if mid and mid not in LOCAL_MLX_MODEL_IDS]
    if unsupported:
        if verbose:
            log_info(f"[omlx] Profile '{profile.get('id')}' rejected: no MLX model ID mapped for {', '.join(unsupported)}")
        return False
    return bool(model_ids)


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


def local_runtime_port(runtime):
    if runtime == "ds4":
        return DS4_PORT
    return OMLX_PORT if runtime == "omlx" else PORT


def local_runtime_base_url(runtime):
    return f"http://{HOST}:{local_runtime_port(runtime)}"


def is_pid_running(pid):
    if not pid:
        return False
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


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


def collect_runtime_status(ctx):
    profile = ctx.active_profile()
    runtime = selected_local_runtime(profile)
    port = local_runtime_port(runtime)
    health_path = "/v1/models" if runtime in {"omlx", "ds4"} else "/health"
    paths = runtime_paths(ctx, runtime)
    pid_path = paths["pid"]
    state_path = paths["state"]
    log_path = paths["log"]
    runtime_info = {
        "runtime": runtime,
        "host": HOST,
        "port": port,
        "url": f"http://{HOST}:{port}",
        "log_path": str(log_path),
        "pid_path": str(pid_path),
        "running": False,
        "health_reachable": False,
    }
    if pid_path.is_file():
        try:
            pid = int(pid_path.read_text(encoding="utf-8").strip())
        except ValueError:
            pid = 0
        runtime_info["pid"] = pid
        runtime_info["running"] = is_pid_running(pid)
    if state_path.is_file():
        import json
        runtime_info["launch"] = json.loads(state_path.read_text(encoding="utf-8"))
    try:
        health, _ = request_json(f"http://{HOST}:{port}{health_path}", timeout=2)
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


def runtime_start(ctx, show_logs=False, tail_hint=True, foreground=False):
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
    port = local_runtime_port(runtime)
    base_url = local_runtime_base_url(runtime)
    status = collect_runtime_status(ctx)
    if status["running"] and status["health_reachable"]:
        return {
            "ok": True,
            "running": True,
            "message": f"{runtime} already running at {base_url}",
            "log_path": status.get("log_path"),
        }
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
    if runtime == "omlx":
        if not command_exists(os.environ.get("OMLX_BIN", "omlx")):
            raise SystemExit("oMLX runtime selected but `omlx` is not in PATH. Install with Homebrew or set AI_LOCAL_RUNTIME=llama.cpp.")
        models_dir = Path(os.environ.get("AI_MODELS_DIR", str(ctx.root / "models"))) / "mlx"
        env["OMLX_MODEL_DIR"] = str(models_dir)
        env["OMLX_HOST"] = HOST
        env["OMLX_PORT"] = str(port)
        command = [os.environ.get("OMLX_BIN", "omlx"), "serve", "--model-dir", str(models_dir)]
        ready_url = f"{base_url}/v1/models"
    elif runtime == "ds4":
        ds4_bin = os.environ.get("DS4_BIN", "ds4-server")
        if not command_exists(ds4_bin):
            raise SystemExit("ds4 runtime selected but `ds4-server` is not in PATH. Build antirez/ds4 and set DS4_BIN, or set AI_LOCAL_RUNTIME=llama.cpp.")
        models_dir = Path(os.environ.get("AI_MODELS_DIR", str(ctx.root / "models")))
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
            os.environ.get("DS4_CTX", "100000"),
            "--kv-disk-dir",
            str(kv_dir),
            "--kv-disk-space-mb",
            os.environ.get("DS4_KV_DISK_SPACE_MB", "8192"),
            "--host",
            HOST,
            "--port",
            str(port),
        ]
        ready_url = f"{base_url}/v1/models"
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
            HOST,
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
        process = subprocess.Popen(command, env=env)
        payload = {
            "started_at": started_at,
            "ready_at": None,
            "launch_latency_ms": None,
            "pid": process.pid,
            "port": port,
            "host": HOST,
            "log_path": str(log_path),
            "profile_id": profile_id,
            "runtime": runtime,
            "foreground": True,
        }
        _write_runtime_state(payload)
        try:
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
    flags = 0
    kwargs = {}
    if os.name == "nt":
        flags = subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS
    else:
        kwargs["start_new_session"] = True
    log_handle = log_path.open("a", encoding="utf-8")
    process = subprocess.Popen(
        command,
        stdout=log_handle,
        stderr=subprocess.STDOUT,
        env=env,
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
        "host": HOST,
        "log_path": str(log_path),
        "profile_id": profile_id,
        "runtime": runtime,
    }
    _write_runtime_state(payload)
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
        result["tail_hint"] = f"tail -f {log_path}"
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
