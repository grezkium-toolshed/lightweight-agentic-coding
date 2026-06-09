"""lac CLI — argument parsing, dispatch, and text rendering."""

import argparse
import copy
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from lac import VERSION
from lac.context import Context, ROOT, STATE_ROOT, HOST, PORT, OMLX_PORT
from lac.lib.jsonc import load_jsonc
from lac.profiles import (
    profile_list, profile_apply, render_preset,
    RAM_BUCKETS, FAMILY_DESCRIPTIONS,
    detect_total_ram_gb, detect_hardware, _bucket_for_ram,
    recommend_profile, family_alternatives,
)
from lac.config import render_opencode_config, LOCAL_MLX_MODEL_IDS
from lac.runtime import (
    selected_local_runtime, runtime_paths, local_runtime_port,
    local_runtime_base_url, is_pid_running, request_json,
    collect_runtime_status, write_runtime_state,
    runtime_start, runtime_stop, runtime_status,
)
from lac.providers import (
    PROVIDER_VERIFICATION, _get_provider_entry, _verify_provider_record,
    verify_provider, verify_all_providers, refresh_provider_catalog,
    _provider_configured, collect_provider_readiness,
    provider_list, provider_models, provider_status,
)
from lac.packs import (
    build_pack_summary, pack_list, pack_show,
    load_asset_catalog, load_workflow_catalog,
    optional_skill_root, optional_skill_path, optional_skill_status,
    install_optional_skill, remove_optional_skill, verify_optional_skill,
)
from lac.scenarios import scenario_list, scenario_show
from lac.clients import render_client, client_open
from lac.models import models_sync
from lac.catalog import sync_free
from lac.init import (
    init_wizard, render_init_text, CLOUD_PROVIDER_HINTS,
    _parse_cloud_arg, _validate_cloud_ids,
)
from lac.bench import bench
from lac.doctor import run_fixes
from lac.render import (
    render_pack_list, render_pack_show, render_skill_status, render_skill_verify,
    render_scenario_list, render_scenario_show, render_provider_list,
    render_provider_models, render_provider_status, _render_verify_row,
    render_provider_verify_single, render_provider_verify_all,
    render_doctor_text, render_smoke_text,
)


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def command_exists(name):
    import shutil
    return shutil.which(name) is not None


def log_info(message):
    print(message, file=sys.stderr)


def utc_now():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _host_install_platform():
    if sys.platform == "darwin":
        return "macos"
    if sys.platform.startswith("win"):
        return "windows"
    return "linux"


def _install_hint(tool_id, env_var=None):
    platform_id = _host_install_platform()
    hints = {
        "python": {
            "summary": "Install Python 3 and make sure python3, python, or py is on PATH.",
            "macos": ["brew install python"],
            "linux": ["sudo apt install python3"],
            "windows": ["winget install Python.Python.3.12"],
            "docs": "https://www.python.org/downloads/",
        },
        "opencode": {
            "summary": "Install the OpenCode CLI, then restart your shell so opencode is on PATH.",
            "macos": ["curl -fsSL https://opencode.ai/install | bash", "npm install -g opencode-ai"],
            "linux": ["curl -fsSL https://opencode.ai/install | bash", "npm install -g opencode-ai"],
            "windows": ["npm install -g opencode-ai"],
            "docs": "https://opencode.ai/docs",
        },
        "llama-server": {
            "summary": "Install llama.cpp and make sure the llama-server binary is on PATH.",
            "macos": ["brew install llama.cpp"],
            "linux": [
                "git clone https://github.com/ggml-org/llama.cpp",
                "cmake -B llama.cpp/build -S llama.cpp -DLLAMA_CURL=ON",
                "cmake --build llama.cpp/build --config Release -j",
            ],
            "windows": ["Download a llama.cpp release and add the folder containing llama-server.exe to PATH."],
            "docs": "https://github.com/ggml-org/llama.cpp",
        },
        "omlx": {
            "summary": "Install oMLX only on Apple Silicon macOS when you want MLX serving.",
            "macos": ["brew tap jundot/omlx https://github.com/jundot/omlx", "brew install omlx"],
            "linux": ["oMLX is macOS/Apple Silicon only; use llama.cpp on Linux."],
            "windows": ["oMLX is macOS/Apple Silicon only; use llama.cpp on Windows."],
            "docs": "https://github.com/jundot/omlx",
        },
        "hf": {
            "summary": "Install the Hugging Face CLI if you want authenticated model downloads or MLX repo staging.",
            "macos": ["python3 -m pip install --user 'huggingface_hub[cli]'"],
            "linux": ["python3 -m pip install --user 'huggingface_hub[cli]'"],
            "windows": ["py -3 -m pip install --user \"huggingface_hub[cli]\""],
            "docs": "https://huggingface.co/docs/huggingface_hub/guides/cli",
        },
        "openchamber": {
            "summary": "Install OpenChamber — web/PWA/desktop interface for OpenCode with mobile/remote access.",
            "macos": ["curl -fsSL https://raw.githubusercontent.com/openchamber/openchamber/main/scripts/install.sh | bash", "brew install openchamber/tap/openchamber"],
            "linux": ["curl -fsSL https://raw.githubusercontent.com/openchamber/openchamber/main/scripts/install.sh | bash"],
            "windows": ["curl -fsSL https://raw.githubusercontent.com/openchamber/openchamber/main/scripts/install.sh | bash"],
            "docs": "https://github.com/openchamber/openchamber",
        },
    }
    if env_var:
        return {
            "summary": f"Set {env_var} in your shell before running init/provider verification.",
            "commands": [f"export {env_var}=..."] if platform_id != "windows" else [f"$env:{env_var} = \"...\""],
            "docs": "docs/providers/AUTHENTICATION.md",
        }
    hint = hints.get(tool_id)
    if not hint:
        return None
    return {
        "summary": hint["summary"],
        "commands": hint.get(platform_id, []),
        "docs": hint.get("docs"),
    }


def _strip_global_json_flag(argv):
    json_mode = False
    filtered = []
    for arg in argv:
        if arg == "--json":
            json_mode = True
            continue
        filtered.append(arg)
    return filtered, json_mode


def device_setup(ctx, profile_id):
    from lac.profiles import profile_apply
    print(f"[setup] Applying profile: {profile_id}")
    profile_apply(ctx, profile_id, verbose_runtime=False)
    omlx_settings = Path.home() / ".omlx" / "settings.json"
    if omlx_settings.is_file():
        print(f"[setup] oMLX detected at {omlx_settings} — updating context limits...")
        cfg = json.loads(omlx_settings.read_text(encoding="utf-8"))
        cfg.setdefault("sampling", {})
        cfg["sampling"]["max_context_window"] = 262144
        cfg["sampling"]["max_tokens"] = 16384
        omlx_settings.write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8")
        print("[setup] oMLX max_context_window=262144 max_tokens=16384")
    else:
        print(f"[setup] oMLX not detected (no {omlx_settings}). Skipping oMLX configuration.")
    dcp_plugin = "@tarquinen/opencode-dcp@latest"
    dcp_cache_dir = Path.home() / ".cache" / "opencode" / "packages" / dcp_plugin
    dcp_package_json = dcp_cache_dir / "node_modules" / dcp_plugin / "package.json"
    if dcp_package_json.is_file() and '"version"' in dcp_package_json.read_text(encoding="utf-8") and '"3.1.9"' in dcp_package_json.read_text(encoding="utf-8"):
        print("[setup] Removing stale DCP 3.1.9 package cache before reinstall...")
        shutil.rmtree(dcp_cache_dir, ignore_errors=True)
    if os.environ.get("AI_CLUSTER_INSTALL_DCP", "1") == "0":
        print("[setup] DCP plugin install skipped (AI_CLUSTER_INSTALL_DCP=0).")
    elif command_exists("opencode"):
        print(f"[setup] Installing/updating Dynamic Context Pruning plugin: {dcp_plugin}")
        result = subprocess.run(["opencode", "plugin", dcp_plugin, "--global", "--force"], check=False)
        if result.returncode == 0:
            print("[setup] DCP plugin ready. Restart OpenCode and run /dcp to verify.")
        else:
            print("[setup] WARNING: DCP plugin install failed.")
            print(f"[setup] Retry manually with: opencode plugin {dcp_plugin} --global --force")
    else:
        print("[setup] WARNING: opencode is not in PATH; cannot install DCP plugin.")
        print(f"[setup] After installing OpenCode, run: opencode plugin {dcp_plugin} --global --force")
    print(f"[setup] Device configuration complete for profile: {profile_id}")
    return 0


def verify_free_models(ctx, providers=None, timeout=10):
    if providers is None:
        providers = ["openrouter", "nvidia-nim"]
    provider_endpoints = {
        "openrouter": {"base_url": "https://openrouter.ai/api/v1", "env_var": "OPENROUTER_API_KEY"},
        "nvidia-nim": {"base_url": "https://integrate.api.nvidia.com/v1", "env_var": "NVIDIA_API_KEY"},
    }
    template = load_jsonc(ctx.paths["opencode_template"])
    errors = 0
    print("=== Free Model Verification ===")
    print(f"Timeout per model: {timeout}s")
    print()
    for provider_id in providers:
        if provider_id not in provider_endpoints:
            print(f"[{provider_id}] unknown provider, skipping")
            continue
        endpoint = provider_endpoints[provider_id]
        api_key = os.environ.get(endpoint["env_var"], "")
        provider_block = template.get("provider", {}).get(provider_id, {})
        models = list(provider_block.get("models", {}).keys())
        if not models:
            print(f"[{provider_id}] No models found in provider block")
            print()
            continue
        print(f"[{provider_id}] Free models:")
        if not api_key:
            print(f"  [?] no API key set (set {endpoint['env_var']})")
            print()
            continue
        for model_id in models:
            url = f"{endpoint['base_url']}/chat/completions"
            payload = json.dumps({
                "model": model_id,
                "messages": [{"role": "user", "content": "hi"}],
                "max_tokens": 4,
            }).encode("utf-8")
            req = urllib.request.Request(url, data=payload, method="POST")
            req.add_header("Authorization", f"Bearer {api_key}")
            req.add_header("Content-Type", "application/json")
            http_code = "000"
            try:
                with urllib.request.urlopen(req, timeout=timeout) as resp:
                    http_code = str(resp.status)
            except urllib.error.HTTPError as exc:
                http_code = str(exc.code)
            except Exception:
                http_code = "000"
            if http_code in ("200", "201"):
                print(f"  [ok] {model_id}")
            elif http_code == "404":
                print(f"  [!!] {model_id} — REMOVED (404)")
                errors += 1
            elif http_code == "429":
                print(f"  [--] {model_id} — rate-limited (429)")
            elif http_code in ("401", "403"):
                print(f"  [!!] {model_id} — auth error ({http_code})")
                errors += 1
            elif http_code == "000":
                print(f"  [??] {model_id} — connection timeout")
            else:
                print(f"  [??] {model_id} — unexpected status {http_code}")
        print()
    if errors:
        print("=== Verification complete — some models are broken ===")
        print("Update opencode.template.jsonc and docs/providers/OPENROUTER_FREE.md")
        print("to remove removed models.")
        return 1
    print("=== Verification complete — no broken models ===")
    return 0


def run_models_sync(profile_id):
    return models_sync(profile_id)


def _demo_cloud(ctx, yes=False):
    """Cloud demo: OpenRouter free tier, zero downloads."""
    api_key = os.environ.get("OPENROUTER_API_KEY", "")
    if not api_key:
        print("Cloud demo needs an OpenRouter API key (free tier available).")
        print("Get one: https://openrouter.ai/keys")
        if yes:
            print("No API key set and --yes is active. Aborting cloud demo.")
            return {"status": "error", "message": "OPENROUTER_API_KEY not set"}
        api_key = input("Paste your OpenRouter API key: ").strip()
        if not api_key:
            print("No API key entered. Try: lac demo --local")
            return {"status": "error", "message": "No API key provided"}
        shell_rc = Path.home() / ".zshrc"
        if shell_rc.is_file():
            save = input(f"Save to {shell_rc} for future sessions? [Y/n]: ").strip().lower()
            if save in ("", "y", "yes"):
                existing = shell_rc.read_text(encoding="utf-8")
                if "OPENROUTER_API_KEY" not in existing:
                    shell_rc.write_text(f"{existing}\nexport OPENROUTER_API_KEY=\"{api_key}\"\n", encoding="utf-8")
                    print(f"Saved to {shell_rc}. Restart your shell or run 'source {shell_rc}'.")
                else:
                    print("OPENROUTER_API_KEY already found in .zshrc — skipping.")
        os.environ["OPENROUTER_API_KEY"] = api_key
    else:
        print("Using OPENROUTER_API_KEY from environment.")

    from lac.profiles import profile_apply
    print("Applying openrouter profile...")
    profile_apply(ctx, "openrouter", verbose_runtime=False)

    from lac.clients import render_client, client_open
    print("Rendering OpenChamber client config...")
    render_client(ctx, "openchamber")
    print("Launching OpenChamber...")
    client_open(ctx, "openchamber")

    return {"status": "ok", "mode": "cloud", "profile": "openrouter"}


def _demo_local(ctx, yes=False):
    """Local demo: download micro model, start runtime, launch OpenChamber."""
    from lac.models import models_sync
    from lac.profiles import profile_apply
    from lac.runtime import runtime_start
    from lac.clients import render_client, client_open

    models_dir = Path(os.environ.get("AI_MODELS_DIR", str(ROOT / "models")))
    model_file = models_dir / "qwen3.5" / "Qwen3.5-4B-Q4_K_M.gguf"

    need_download = not model_file.is_file()
    if need_download:
        print("Micro model (Qwen3.5-4B ~2.5 GB) needs to be downloaded.")
        if yes:
            print("Downloading (--yes active)...")
        else:
            proceed = input("Download now? [Y/n]: ").strip().lower()
            if proceed not in ("", "y", "yes"):
                print("Aborted. Run later: lac models sync micro")
                return {"status": "error", "message": "Download aborted"}
        print("Downloading model...")
        result = models_sync("micro")
        if result != 0:
            print("Model download failed. Check your internet connection and Hugging Face CLI.")
            return {"status": "error", "message": "Download failed"}

    print("Applying micro profile...")
    profile_apply(ctx, "micro", verbose_runtime=False)

    print("Starting local runtime (llama-server)...")
    runtime_start(ctx, show_logs=False, tail_hint=False)

    print("Rendering OpenChamber client config...")
    render_client(ctx, "openchamber")
    print("Launching OpenChamber...")
    client_open(ctx, "openchamber")

    return {"status": "ok", "mode": "local", "profile": "micro"}


def run_demo(ctx, mode="cloud", yes=False):
    """Run the demo — cloud (OpenRouter) or local (micro model)."""
    if mode == "cloud":
        return _demo_cloud(ctx, yes=yes)
    return _demo_local(ctx, yes=yes)


def doctor(ctx, strict=False, bootstrap_hint=False):
    checks = []
    def add_check(kind, path, exists, generated=False, hint=None):
        checks.append({"kind": kind, "path": str(path), "exists": exists, "generated": generated, "hint": hint})
    source_paths = [
        ctx.paths["opencode_template"], ctx.paths["profile_manifest"],
        ctx.paths["asset_catalog"], ctx.paths["workflow_catalog"],
        ctx.paths["provider_catalog"], ctx.paths["scenario_catalog"],
    ]
    for path in source_paths:
        add_check("source", path, path.is_file())
    generated_paths = [ctx.paths["active_preset"], ctx.paths["active_profile"], ctx.paths["opencode_config"]]
    for path in generated_paths:
        add_check("generated", path, path.is_file(), generated=True,
                  hint="Run ./bin/lac profile apply <profile> to regenerate state." if bootstrap_hint else None)
    commands = {
        "opencode": command_exists("opencode"),
        "llama-server": command_exists("llama-server"),
        "omlx": command_exists("omlx"),
        "python3": command_exists("python3") or command_exists("python"),
        "openchamber": command_exists("openchamber"),
    }
    active_profile_id = ctx.active_profile_id()
    active_profile = ctx.active_profile()
    required_command_names = {"opencode", "python3"}
    if active_profile and active_profile.get("runtime_mode") != "cloud":
        runtime = selected_local_runtime(active_profile)
        required_command_names.add("omlx" if runtime == "omlx" else "llama-server")
    command_install_hints = {
        name: _install_hint("python" if name == "python3" else name)
        for name, exists in commands.items()
        if name in required_command_names and not exists
    }
    runtime_status_data = collect_runtime_status(ctx)
    asset_catalog = load_asset_catalog(ctx)
    workflow_catalog = load_workflow_catalog(ctx)
    report = {
        "generated_at": utc_now(),
        "state_root": str(ctx.state_root),
        "checks": checks,
        "active_profile_id": active_profile_id,
        "active_profile": active_profile,
        "commands": commands,
        "command_install_hints": command_install_hints,
        "provider_readiness": collect_provider_readiness(ctx),
        "runtime": runtime_status_data,
        "assets": {
            "catalog_asset_count": len(asset_catalog["assets"]),
            "pack_count": len(workflow_catalog["packs"]),
            "opencode_agents": len(list(ctx.paths["opencode_agents_dir"].glob("*.md"))),
            "opencode_skills": len(list(ctx.paths["opencode_skills_dir"].glob("*/SKILL.md"))),
        },
    }
    failures = []
    for check in checks:
        if not check["exists"] and not check["generated"]:
            failures.append(check["path"])
    if strict:
        if active_profile and active_profile["runtime_mode"] != "cloud" and not runtime_status_data["health_reachable"]:
            failures.append("runtime health endpoint")
        required_runtime = runtime_status_data.get("runtime", "llama.cpp")
        required_commands = {"opencode", "omlx" if required_runtime == "omlx" else "llama-server"}
        for name, exists in commands.items():
            if name in required_commands and not exists:
                failures.append(name)
    report["ok"] = not failures
    report["failures"] = failures
    write_json(ctx.paths["doctor_report"], report)
    return report


def smoke(ctx, timeout):
    profile = ctx.active_profile()
    profile_id = ctx.active_profile_id()
    runtime = selected_local_runtime(profile)
    base_url = local_runtime_base_url(runtime)
    report = {
        "generated_at": utc_now(),
        "active_profile_id": profile_id,
        "profile": profile,
        "timeout_seconds": timeout,
        "runtime": runtime,
        "runtime_url": base_url,
        "client_assets": {
            "agents": len(list(ctx.paths["opencode_agents_dir"].glob("*.md"))),
            "skills": len(list(ctx.paths["opencode_skills_dir"].glob("*/SKILL.md"))),
        },
    }
    if profile and profile["runtime_mode"] == "cloud":
        report["skipped"] = True
        report["reason"] = "cloud-profile"
        report["ok"] = ctx.paths["opencode_config"].is_file()
        write_json(ctx.paths["smoke_report"], report)
        return report
    started = time.time()
    health = {}
    if runtime != "omlx":
        try:
            health, _ = request_json(f"{base_url}/health", timeout=timeout)
        except Exception as exc:
            report["ok"] = False
            report["error"] = f"health request failed: {exc}"
            write_json(ctx.paths["smoke_report"], report)
            return report
    try:
        models, _ = request_json(f"{base_url}/v1/models", timeout=timeout)
    except Exception as exc:
        report["ok"] = False
        report["error"] = f"models request failed: {exc}"
        write_json(ctx.paths["smoke_report"], report)
        return report
    chat_payload = {
        "model": load_json(ctx.paths["opencode_config"]).get("model", "local-cluster/default").split("/", 1)[1],
        "messages": [{"role": "user", "content": "Say hello in one word."}],
        "max_tokens": 16,
        "temperature": 0.1,
    }
    try:
        chat, _ = request_json(f"{base_url}/v1/chat/completions", method="POST", payload=chat_payload, timeout=timeout)
    except Exception as exc:
        report["ok"] = False
        report["error"] = f"chat request failed: {exc}"
        write_json(ctx.paths["smoke_report"], report)
        return report
    elapsed_ms = int((time.time() - started) * 1000)
    choices = chat.get("choices", [])
    content = ""
    if choices:
        content = choices[0].get("message", {}).get("content", "")
    report.update({
        "ok": bool(choices), "health": health,
        "model_count": len(models.get("data", [])),
        "chat_content_preview": content[:80], "benchmark_ms": elapsed_ms,
    })
    write_json(ctx.paths["smoke_report"], report)
    return report

def emit(payload, json_mode=False, kind=None):
    if json_mode:
        print(json.dumps(payload, indent=2))
        return
    if kind == "pack-list":
        render_pack_list(payload); return
    if kind == "pack-show":
        render_pack_show(payload); return
    if kind == "skill-status":
        render_skill_status(payload); return
    if kind == "skill-verify":
        render_skill_verify(payload); return
    if kind == "scenario-list":
        render_scenario_list(payload); return
    if kind == "scenario-show":
        render_scenario_show(payload); return
    if kind == "provider-list":
        render_provider_list(payload); return
    if kind == "provider-models":
        render_provider_models(payload["provider_id"], payload["models"]); return
    if kind == "provider-status":
        render_provider_status(payload); return
    if kind == "provider-verify":
        render_provider_verify_single(payload); return
    if kind == "provider-verify-all":
        render_provider_verify_all(payload); return
    if kind == "doctor":
        render_doctor_text(payload); return
    if kind == "smoke":
        render_smoke_text(payload); return
    if kind == "init":
        render_init_text(payload); return
    if isinstance(payload, list):
        for item in payload:
            print(f"{item['id']}: {item['label']} | {item['runtime_mode']} | {item['verification_tier']} | {', '.join(item['recommended_for'])}")
        return
    if isinstance(payload, dict):
        if payload.get("desktop") and payload.get("message"):
            print(payload["message"]); return
        if payload.get("profile_id") and payload.get("generated"):
            print(f"Applied profile: {payload['profile_id']}")
            print(f"State root: {payload['state_root']}")
            print(f"Generated OpenCode config: {payload['generated']['opencode_config']}")
            return
        if payload.get("running") and payload.get("url"):
            print(f"llama-server ready at {payload['url']}")
            print(f"Log file: {payload['log_path']}")
            if payload.get("tail_hint"):
                print(f"Tail logs: {payload['tail_hint']}")
            return
        if payload.get("target") and payload.get("manifest_path"):
            print(f"Rendered {payload['target']} adapter: {payload['manifest_path']}"); return
        if payload.get("message"):
            print(payload["message"]); return
        if payload.get("skipped") and payload.get("reason"):
            print(payload["reason"]); return
    print(json.dumps(payload, indent=2))


def build_parser():
    parser = argparse.ArgumentParser(prog="lac", description="lac — Lightweight Agentic Coding CLI")
    parser.add_argument("--version", action="version", version=f"lac {VERSION}")
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON")
    subparsers = parser.add_subparsers(dest="command", required=True)

    doctor_parser = subparsers.add_parser("doctor")
    doctor_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    doctor_parser.add_argument("--strict", action="store_true")
    doctor_parser.add_argument("--bootstrap-hint", action="store_true")
    doctor_parser.add_argument("--fix", action="store_true", help="Attempt to auto-fix detected issues")

    bench_parser = subparsers.add_parser("bench")
    bench_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    bench_parser.add_argument("--model", help="Benchmark a specific model slot (default: all)")
    bench_parser.add_argument("--draft-n", type=int, help="Experimental: MTP draft token count (requires server support, e.g. 6)")
    bench_parser.add_argument("--prompt", default=None, help="Custom prompt for the benchmark")
    bench_parser.add_argument("--timeout", type=int, default=int(os.environ.get("BENCH_TIMEOUT", "120")),
                              help="Per-request timeout in seconds")

    smoke_parser = subparsers.add_parser("smoke")
    smoke_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    smoke_parser.add_argument("--timeout", type=int, default=int(os.environ.get("SMOKE_TIMEOUT", "30")))

    profile_parser = subparsers.add_parser("profile")
    profile_sub = profile_parser.add_subparsers(dest="profile_command", required=True)
    profile_list_parser = profile_sub.add_parser("list")
    profile_list_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    profile_apply_parser = profile_sub.add_parser("apply")
    profile_apply_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    profile_apply_parser.add_argument("profile_id")
    profile_apply_parser.add_argument("--render-target", default="opencode")

    models_parser = subparsers.add_parser("models")
    models_sub = models_parser.add_subparsers(dest="models_command", required=True)
    models_sync_parser = models_sub.add_parser("sync")
    models_sync_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    models_sync_parser.add_argument("profile_id")

    runtime_parser = subparsers.add_parser("runtime")
    runtime_sub = runtime_parser.add_subparsers(dest="runtime_command", required=True)
    runtime_start_parser = runtime_sub.add_parser("start")
    runtime_start_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    runtime_start_parser.add_argument("--foreground", action="store_true", help="Run llama-server attached to this terminal for visible logs")
    runtime_start_parser.add_argument("--show-logs", action="store_true")
    runtime_start_parser.add_argument("--no-tail-hint", action="store_true")
    runtime_status_parser = runtime_sub.add_parser("status")
    runtime_status_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    runtime_stop_parser = runtime_sub.add_parser("stop")
    runtime_stop_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)

    client_parser = subparsers.add_parser("client")
    client_sub = client_parser.add_subparsers(dest="client_command", required=True)
    client_render_parser = client_sub.add_parser("render")
    client_render_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    client_render_parser.add_argument("target", choices=["opencode", "claude-code", "codex-reference", "openchamber"])
    client_open_parser = client_sub.add_parser("open")
    client_open_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    client_open_parser.add_argument("target", choices=["opencode", "openchamber"])
    client_open_parser.add_argument("--desktop", action="store_true")
    client_open_parser.add_argument("--remote-host", help="Connect to an OpenCode server on a remote host (e.g. http://100.x.x.x:4095 for Tailscale)")

    pack_parser = subparsers.add_parser("pack")
    pack_sub = pack_parser.add_subparsers(dest="pack_command", required=True)
    pack_list_parser = pack_sub.add_parser("list")
    pack_list_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    pack_show_parser = pack_sub.add_parser("show")
    pack_show_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    pack_show_parser.add_argument("pack_id")

    skill_parser = subparsers.add_parser("skill")
    skill_sub = skill_parser.add_subparsers(dest="skill_command", required=True)
    skill_status_parser = skill_sub.add_parser("status")
    skill_status_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    skill_status_parser.add_argument("skill_id", choices=["msgraph"])
    skill_install_parser = skill_sub.add_parser("install")
    skill_install_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    skill_install_parser.add_argument("--source", help="Local msgraph directory or zip; omit to download upstream release")
    skill_install_parser.add_argument("--force", action="store_true", help="Replace an existing optional skill install")
    skill_install_parser.add_argument("skill_id", choices=["msgraph"])
    skill_remove_parser = skill_sub.add_parser("remove")
    skill_remove_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    skill_remove_parser.add_argument("skill_id", choices=["msgraph"])
    skill_verify_parser = skill_sub.add_parser("verify")
    skill_verify_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    skill_verify_parser.add_argument("--timeout", type=int, default=10)
    skill_verify_parser.add_argument("skill_id", choices=["msgraph"])

    scenario_parser = subparsers.add_parser("scenario")
    scenario_sub = scenario_parser.add_subparsers(dest="scenario_command", required=True)
    scenario_list_parser = scenario_sub.add_parser("list")
    scenario_list_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    scenario_show_parser = scenario_sub.add_parser("show")
    scenario_show_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    scenario_show_parser.add_argument("scenario_id")

    provider_parser = subparsers.add_parser("provider")
    provider_sub = provider_parser.add_subparsers(dest="provider_command", required=True)
    provider_list_parser = provider_sub.add_parser("list")
    provider_list_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    provider_models_parser = provider_sub.add_parser("models")
    provider_models_parser.add_argument("provider_id")
    provider_models_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    provider_status_parser = provider_sub.add_parser("status")
    provider_status_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    provider_verify_parser = provider_sub.add_parser("verify")
    provider_verify_parser.add_argument("provider_id", nargs="?", help="Provider id (omit with --all)")
    provider_verify_parser.add_argument("--all", action="store_true", dest="all_providers", help="Verify every catalog provider")
    provider_verify_parser.add_argument("--timeout", type=int, default=5, help="Per-request timeout in seconds")
    provider_verify_parser.add_argument("--refresh-catalog", action="store_true", dest="refresh_catalog", help="Update last_verified_at in catalog/providers.json on success")
    provider_verify_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    provider_verify_models_parser = provider_sub.add_parser("verify-models", help="Verify free models via chat completion probes")
    provider_verify_models_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    provider_verify_models_parser.add_argument("--timeout", type=int, default=10, help="Per-request timeout in seconds")
    provider_verify_models_parser.add_argument("--providers", help="Comma-separated provider ids (default: openrouter,nvidia-nim)")

    setup_parser = subparsers.add_parser("setup", help="Apply profile and configure device (oMLX, DCP plugin)")
    setup_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    setup_parser.add_argument("profile_id")

    catalog_parser = subparsers.add_parser("catalog", help="Catalog management commands")
    catalog_sub = catalog_parser.add_subparsers(dest="catalog_command", required=True)
    catalog_sync_free_parser = catalog_sub.add_parser("sync-free", help="Sync free cloud models from upstream source")
    catalog_sync_free_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    catalog_sync_free_parser.add_argument("--source-url", help="Override upstream source URL")

    init_parser = subparsers.add_parser("init", help="Interactive onboarding wizard")
    init_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    init_parser.add_argument("--yes", action="store_true", help="Non-interactive; accept defaults or flag values")
    init_parser.add_argument("--profile", help="Profile id to apply (skip recommendation)")
    init_parser.add_argument("--cloud", help="Comma-separated cloud provider ids to enable (non-interactive)")
    init_parser.add_argument("--no-cloud", action="store_true", help="Do not enable any cloud overlay")

    demo_parser = subparsers.add_parser("demo", help="Instant chat: cloud (zero download) or local (tiny model)")
    demo_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    demo_parser.add_argument("--yes", action="store_true", help="Non-interactive; accept all prompts")
    demo_group = demo_parser.add_mutually_exclusive_group()
    demo_group.add_argument("--local", action="store_true", help="Download and run a tiny 2.5 GB model locally")
    demo_group.add_argument("--cloud", action="store_true", help="Use OpenRouter free tier (no local models)")

    return parser


def main():
    parser = build_parser()
    argv, json_mode = _strip_global_json_flag(sys.argv[1:])
    args = parser.parse_args(argv)
    args.json = bool(getattr(args, "json", False) or json_mode)
    ctx = Context()

    if args.command == "doctor":
        if getattr(args, "fix", False):
            report = run_fixes(ctx, yes=False)
            emit(report, args.json, kind="doctor")
            raise SystemExit(0 if report["ok"] else 1)
        report = doctor(ctx, strict=args.strict, bootstrap_hint=args.bootstrap_hint)
        emit(report, args.json, kind="doctor")
        raise SystemExit(0 if report["ok"] or not args.strict else 1)

    if args.command == "bench":
        report = bench(ctx, model=args.model, draft_n=args.draft_n,
                       prompt=args.prompt, timeout=args.timeout, json_output=args.json)
        emit(report, args.json, kind="bench")
        raise SystemExit(0 if report.get("ok", False) else 1)

    if args.command == "smoke":
        report = smoke(ctx, timeout=args.timeout)
        emit(report, args.json, kind="smoke")
        raise SystemExit(0 if report.get("ok", False) else 1)

    if args.command == "profile":
        if args.profile_command == "list":
            emit(profile_list(ctx), args.json)
            return
        if args.profile_command == "apply":
            emit(profile_apply(ctx, args.profile_id, render_target=args.render_target), args.json)
            return

    if args.command == "models":
        if args.models_command == "sync":
            raise SystemExit(run_models_sync(args.profile_id))

    if args.command == "runtime":
        if args.runtime_command == "start":
            emit(runtime_start(ctx, show_logs=args.show_logs, tail_hint=not args.no_tail_hint, foreground=args.foreground), args.json)
            return
        if args.runtime_command == "status":
            emit(runtime_status(ctx), args.json)
            return
        if args.runtime_command == "stop":
            emit(runtime_stop(ctx), args.json)
            return

    if args.command == "client":
        if args.client_command == "render":
            emit(render_client(ctx, args.target), args.json)
            return
        if args.client_command == "open":
            emit(client_open(ctx, args.target, desktop=args.desktop, remote_host=getattr(args, "remote_host", None)), args.json)
            return

    if args.command == "pack":
        if args.pack_command == "list":
            emit(pack_list(ctx), args.json, kind="pack-list")
            return
        if args.pack_command == "show":
            emit(pack_show(ctx, args.pack_id), args.json, kind="pack-show")
            return

    if args.command == "skill":
        if args.skill_command == "status":
            emit(optional_skill_status(ctx, args.skill_id), args.json, kind="skill-status")
            return
        if args.skill_command == "install":
            emit(install_optional_skill(ctx, args.skill_id, source=args.source, force=args.force), args.json, kind="skill-status")
            return
        if args.skill_command == "remove":
            emit(remove_optional_skill(ctx, args.skill_id), args.json, kind="skill-status")
            return
        if args.skill_command == "verify":
            payload = verify_optional_skill(ctx, args.skill_id, timeout=args.timeout)
            emit(payload, args.json, kind="skill-verify")
            raise SystemExit(0 if payload["ok"] else 1)

    if args.command == "scenario":
        if args.scenario_command == "list":
            emit(scenario_list(ctx), args.json, kind="scenario-list")
            return
        if args.scenario_command == "show":
            emit(scenario_show(ctx, args.scenario_id), args.json, kind="scenario-show")
            return

    if args.command == "provider":
        if args.provider_command == "list":
            emit(provider_list(ctx), args.json, kind="provider-list")
            return
        if args.provider_command == "models":
            payload = {"provider_id": args.provider_id, "models": provider_models(ctx, args.provider_id)}
            emit(payload if not args.json else payload["models"], args.json, kind="provider-models")
            return
        if args.provider_command == "status":
            emit(provider_status(ctx), args.json, kind="provider-status")
            return
        if args.provider_command == "verify-models":
            providers = [p.strip() for p in args.providers.split(",")] if args.providers else None
            raise SystemExit(verify_free_models(ctx, providers=providers, timeout=args.timeout))
        if args.provider_command == "verify":
            if args.all_providers and args.provider_id:
                parser.error("provider verify: pass either <provider_id> or --all, not both")
            if not args.all_providers and not args.provider_id:
                parser.error("provider verify: pass a provider_id or --all")
            if args.all_providers:
                results = [_verify_provider_record(ctx, p["id"], timeout=args.timeout, include_internal=args.refresh_catalog) for p in load_json(ctx.paths["provider_catalog"])["providers"]]
                payload = {"results": results}
                payload["summary"] = {
                    "ok": sum(1 for r in results if r["status"] == "ok"),
                    "skipped": sum(1 for r in results if r["status"] == "skipped"),
                    "error": sum(1 for r in results if r["status"] == "error"),
                    "total": len(results),
                }
                if args.refresh_catalog:
                    refresh_provider_catalog(ctx, payload["results"])
                    for record in payload["results"]:
                        record.pop("parsed_models", None)
                emit(payload, args.json, kind="provider-verify-all")
                raise SystemExit(1 if payload["summary"]["error"] else 0)
            record = _verify_provider_record(ctx, args.provider_id, timeout=args.timeout, include_internal=args.refresh_catalog)
            if args.refresh_catalog:
                refresh_provider_catalog(ctx, [record])
                record.pop("parsed_models", None)
            emit(record, args.json, kind="provider-verify")
            raise SystemExit(1 if record["status"] == "error" else 0)

    if args.command == "setup":
        raise SystemExit(device_setup(ctx, args.profile_id))

    if args.command == "catalog":
        if args.catalog_command == "sync-free":
            raise SystemExit(sync_free(root=ROOT, source_url=getattr(args, "source_url", None)))

    if args.command == "init":
        result = init_wizard(
            ctx, yes=args.yes, profile=args.profile, cloud=args.cloud, no_cloud=args.no_cloud,
            load_json=load_json, command_exists=command_exists,
            _host_install_platform=_host_install_platform, _install_hint=_install_hint,
        )
        emit(result, args.json, kind="init")
        return

    if args.command == "demo":
        mode = "local" if args.local else "cloud"
        result = run_demo(ctx, mode=mode, yes=args.yes)
        emit(result, args.json, kind="demo")
        raise SystemExit(0 if result["status"] == "ok" else 1)

    parser.error("Unknown command")


if __name__ == "__main__":
    main()
