"""Doctor — diagnostics and auto-fix registry.

Each fix is a callable registered with a priority, description, check function,
and fix function. The dispatch loop runs checks in priority order, shows the
plan, and executes fixes with user confirmation.
"""

import sys
import subprocess

from lac.profiles import profile_apply
from lac.models import models_sync
from lac.runtime import runtime_start
from lac.clients import render_client


FIX_REGISTRY = []


class Fix:
    __slots__ = ("priority", "description", "check", "fix", "needs_sudo", "needs_confirm")

    def __init__(self, priority, description, check, fix, needs_sudo=False, needs_confirm=True):
        self.priority = priority
        self.description = description
        self.check = check
        self.fix = fix
        self.needs_sudo = needs_sudo
        self.needs_confirm = needs_confirm


def register(priority, description, needs_sudo=False, needs_confirm=True):
    def decorator(fn):
        FIX_REGISTRY.append(
            Fix(priority, description, fn, fn, needs_sudo=needs_sudo, needs_confirm=needs_confirm)
        )
        return fn
    return decorator


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

@register("P0", "Install opencode CLI", needs_confirm=True)
def fix_opencode(ctx, yes=False):
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


@register("P1", "Install llama-server", needs_sudo=False, needs_confirm=True)
def fix_llama_server(ctx, yes=False):
    active = ctx.active_profile()
    if active and active.get("runtime_mode") == "cloud":
        return True
    runtime = "llama-server"
    if active:
        from lac.runtime import selected_local_runtime
        runtime = selected_local_runtime(active)
    if runtime == "omlx":
        if _command_exists("omlx"):
            return True
        cmds = _install_hint("omlx")
        for cmd in cmds:
            if not _run_cmd(cmd, "Installing oMLX..."):
                return False
        return _command_exists("omlx")
    if _command_exists("llama-server"):
        return True
    cmds = _install_hint("llama-server")
    if not cmds:
        print("  No install command known for this platform.")
        return False
    for cmd in cmds:
        if not _run_cmd(cmd, "Installing llama.cpp..."):
            return False
    return _command_exists("llama-server")


@register("P2", "Regenerate runtime config", needs_confirm=True)
def fix_generated_state(ctx, yes=False):
    profile_id = ctx.active_profile_id()
    if not profile_id:
        print("  No active profile set. Run 'lac init' first.")
        return False
    profile_apply(ctx, profile_id)
    return True


@register("P2", "Download missing model files", needs_confirm=True)
def fix_model_files(ctx, yes=False):
    profile_id = ctx.active_profile_id()
    if not profile_id:
        print("  No active profile set.")
        return False
    active = ctx.active_profile()
    if active and active.get("runtime_mode") == "cloud":
        print("  Cloud profile — no local models needed.")
        return True
    return models_sync(profile_id, root=ctx.root) == 0


@register("P3", "Start local runtime", needs_confirm=True)
def fix_runtime_start(ctx, yes=False):
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


@register("P4", "Re-render OpenChamber client config", needs_confirm=True)
def fix_openchamber_render(ctx, yes=False):
    active = ctx.active_profile()
    if not active:
        return False
    if "openchamber" not in active.get("supported_clients", []):
        return True  # not needed
    try:
        render_client(ctx, "openchamber")
        return True
    except Exception as e:
        return False
