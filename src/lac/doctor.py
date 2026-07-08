"""Doctor — diagnostics and auto-fix registry.

Each fix is a callable registered with a priority, description, check function,
and fix function. The dispatch loop runs checks in priority order, shows the
plan, and executes fixes with user confirmation.
"""

import os
import sys
import subprocess
from pathlib import Path

from lac.profiles import profile_apply
from lac.models import models_sync
from lac.runtime import runtime_start
from lac.clients import render_client


class Fix:
    __slots__ = ("priority", "description", "check", "fix", "needs_sudo")

    def __init__(self, priority, description, check, fix, needs_sudo=False):
        self.priority = priority
        self.description = description
        self.check = check   # side-effect-free: returns True if OK, else a problem detail
        self.fix = fix       # performs remediation; returns bool. Runs only after consent.
        self.needs_sudo = needs_sudo


def _command_exists(name):
    import shutil
    return shutil.which(name) is not None


def _host_install_platform():
    import platform
    system = platform.system().lower()
    return {"darwin": "macos", "windows": "windows"}.get(system, "linux")


def _run_cmd(cmd, label=None):
    if label:
        print(f"  → {label}")
    print(f"    $ {cmd}")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"    [fail] {result.stderr.strip()}")
        return False
    if result.stdout.strip():
        for line in result.stdout.strip().splitlines()[:5]:
            print(f"    {line}")
    return True


def _install_hint(tool_id):
    hints = {
        "opencode": {
            "macos": ["curl -fsSL https://opencode.ai/install | bash"],
            "linux": ["curl -fsSL https://opencode.ai/install | bash"],
            "windows": ["npm install -g opencode-ai"],
        },
        "llama-server": {
            "macos": ["brew install llama.cpp"],
            "linux": ["git clone --depth 1 https://github.com/ggml-org/llama.cpp",
                      "cmake -B llama.cpp/build -S llama.cpp -DLLAMA_CURL=ON",
                      "cmake --build llama.cpp/build --config Release -j $(nproc)",
                      "sudo cp llama.cpp/build/bin/llama-server /usr/local/bin/"],
            "windows": ["winget install llama.cpp"],
        },
        "python3": {
            "macos": ["brew install python"],
            "linux": ["sudo apt install python3"],
            "windows": ["winget install Python.Python.3.12"],
        },
        "openchamber": {
            "macos": ["curl -fsSL https://raw.githubusercontent.com/openchamber/openchamber/main/scripts/install.sh | bash"],
            "linux": ["curl -fsSL https://raw.githubusercontent.com/openchamber/openchamber/main/scripts/install.sh | bash"],
            "windows": ["curl -fsSL https://raw.githubusercontent.com/openchamber/openchamber/main/scripts/install.sh | bash"],
        },
        "omlx": {
            "macos": ["brew tap jundot/omlx https://github.com/jundot/omlx", "brew install omlx"],
            "linux": [],
            "windows": [],
        },
        "ds4": {
            "macos": ["git clone https://github.com/antirez/ds4", "cd ds4 && make", "export DS4_BIN=$PWD/ds4-server"],
            "linux": ["git clone https://github.com/antirez/ds4", "cd ds4 && make cuda-generic", "export DS4_BIN=$PWD/ds4-server"],
            "windows": [],
        },
    }
    return hints.get(tool_id, {}).get(_host_install_platform(), [])


# --- Fix implementations ---

PRIORITY_ORDER = {
    "P0": 0, "P1": 1, "P2": 2, "P3": 3, "P4": 4,
}


def run_fixes(ctx, yes=False):
    problems = []
    for fix in sorted(FIX_REGISTRY, key=lambda f: (PRIORITY_ORDER.get(f.priority, 99), f.description)):
        result = fix.check(ctx)
        if result is not True and result is not None:
            problems.append((fix, result))

    if not problems:
        print("No issues found.")
        return {"ok": True, "fixed": [], "failed": []}

    print(f"Found {len(problems)} issue(s):")
    for fix, detail in problems:
        status = "sudo" if fix.needs_sudo else ""
        if status:
            status = f" [{status}]"
        print(f"  [{fix.priority}{status}] {fix.description}")
        if isinstance(detail, str):
            print(f"        {detail}")

    if not yes:
        try:
            resp = input("\nApply these fixes? [Y/n] ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            print()
            return {"ok": False, "fixed": [], "failed": ["cancelled"]}
        if resp and resp not in ("y", "yes", ""):
            print("Aborted.")
            return {"ok": False, "fixed": [], "failed": ["cancelled"]}

    fixed = []
    failed = []
    for fix, detail in problems:
        print(f"\n[{fix.priority}] {fix.description}")
        try:
            ok = fix.fix(ctx, yes=yes)
        except Exception as e:
            print(f"  [error] {e}")
            ok = False
        if ok:
            fixed.append(fix.description)
        else:
            failed.append(fix.description)

    overall = not failed
    print(f"\nResults: {len(fixed)} fixed, {len(failed)} failed" + (" ✓" if overall else " ✗"))
    return {"ok": overall, "fixed": fixed, "failed": failed}


# --- Individual fixes ---
#
# Each entry is a (check, fix) pair. `check` is strictly read-only and returns True when
# healthy or a problem string when not. `fix` performs the remediation (installs, downloads,
# runtime start) and runs only after the user confirms in run_fixes.


def _runtime_tool(active):
    """Return (runtime_id, binary_name) for the active profile's local runtime."""
    from lac.runtime import selected_local_runtime
    runtime = selected_local_runtime(active) if active else "llama-server"
    if runtime == "omlx":
        return "omlx", "omlx"
    if runtime == "ds4":
        return "ds4", os.environ.get("DS4_BIN", "ds4-server")
    return "llama-server", "llama-server"


# P0 — opencode CLI present
def _check_opencode(ctx):
    return True if _command_exists("opencode") else "opencode CLI not found on PATH"


def _fix_opencode(ctx, yes=False):
    if _command_exists("opencode"):
        return True
    cmds = _install_hint("opencode")
    if not cmds:
        print("  No install command known for this platform.")
        return False
    for cmd in cmds:
        if not _run_cmd(cmd, "Installing opencode..."):
            return False
    return _command_exists("opencode")


# P1 — local runtime binary present
def _check_runtime(ctx):
    active = ctx.active_profile()
    if active and active.get("runtime_mode") == "cloud":
        return True
    _, binary = _runtime_tool(active)
    return True if _command_exists(binary) else f"local runtime '{binary}' not found on PATH"


def _fix_runtime(ctx, yes=False):
    active = ctx.active_profile()
    if active and active.get("runtime_mode") == "cloud":
        return True
    runtime, binary = _runtime_tool(active)
    if _command_exists(binary):
        return True
    label = {"omlx": "oMLX", "ds4": "ds4"}.get(runtime, "llama.cpp")
    cmds = _install_hint(runtime)
    if not cmds:
        print("  No install command known for this platform.")
        return False
    for cmd in cmds:
        if not _run_cmd(cmd, f"Installing {label}..."):
            return False
    return _command_exists(binary)


# P2 — generated runtime config present
def _check_generated_state(ctx):
    if not ctx.active_profile_id():
        return "No active profile set. Run 'lac init' first."
    missing = [p.name for p in (ctx.paths["active_preset"], ctx.paths["opencode_config"]) if not p.is_file()]
    return True if not missing else f"generated config missing: {', '.join(missing)}"


def _fix_generated_state(ctx, yes=False):
    profile_id = ctx.active_profile_id()
    if not profile_id:
        print("  No active profile set. Run 'lac init' first.")
        return False
    profile_apply(ctx, profile_id)
    return True


# P2 — local model files present on disk
def _check_model_files(ctx):
    profile_id = ctx.active_profile_id()
    if not profile_id:
        return "No active profile set."
    active = ctx.active_profile()
    if active and active.get("runtime_mode") == "cloud":
        return True
    from lac.models import PROFILE_MODELS
    profile = PROFILE_MODELS.get(profile_id)
    if not profile:
        return True
    models_dir = Path(os.environ.get("AI_MODELS_DIR", str(ctx.root / "models")))
    for item in profile["gguf"]:
        subdir, filename = item[0], item[1]
        if not (models_dir / subdir / filename).is_file():
            return f"missing model file: {subdir}/{filename}"
    return True


def _fix_model_files(ctx, yes=False):
    profile_id = ctx.active_profile_id()
    if not profile_id:
        print("  No active profile set.")
        return False
    active = ctx.active_profile()
    if active and active.get("runtime_mode") == "cloud":
        print("  Cloud profile — no local models needed.")
        return True
    return models_sync(profile_id, root=ctx.root) == 0


# P3 — local runtime responding
def _check_runtime_running(ctx):
    active = ctx.active_profile()
    if active and active.get("runtime_mode") == "cloud":
        return True
    from lac.runtime import collect_runtime_status
    if collect_runtime_status(ctx).get("health_reachable"):
        return True
    return "local runtime not responding"


def _fix_runtime_start(ctx, yes=False):
    active = ctx.active_profile()
    if active and active.get("runtime_mode") == "cloud":
        print("  Cloud profile — no local runtime needed.")
        return True
    try:
        runtime_start(ctx)
        return True
    except Exception as e:
        print(f"  [error] Failed to start runtime: {e}")
        return False


# P4 — OpenChamber client config rendered
def _check_openchamber(ctx):
    active = ctx.active_profile()
    if not active or "openchamber" not in active.get("supported_clients", []):
        return True
    return True if ctx.paths["opencode_config"].is_file() else "OpenChamber client config not rendered"


def _fix_openchamber(ctx, yes=False):
    active = ctx.active_profile()
    if not active or "openchamber" not in active.get("supported_clients", []):
        return True
    try:
        render_client(ctx, "openchamber")
        return True
    except Exception:
        return False


FIX_REGISTRY = [
    Fix("P0", "Install opencode CLI", _check_opencode, _fix_opencode),
    Fix("P1", "Install local runtime", _check_runtime, _fix_runtime),
    Fix("P2", "Regenerate runtime config", _check_generated_state, _fix_generated_state),
    Fix("P2", "Download missing model files", _check_model_files, _fix_model_files),
    Fix("P3", "Start local runtime", _check_runtime_running, _fix_runtime_start),
    Fix("P4", "Re-render OpenChamber client config", _check_openchamber, _fix_openchamber),
]
