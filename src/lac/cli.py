"""Local AI Cluster CLI — argument parsing, dispatch, and text rendering."""

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


def run_models_sync(profile_id):
    if os.name == "nt":
        command = [
            "pwsh", "-NoLogo", "-NoProfile", "-File",
            str(ROOT / "scripts/setup-models-device.ps1"),
            "-Profile", profile_id,
        ]
    else:
        command = ["bash", str(ROOT / "scripts/setup-models-device.sh"), "--profile", profile_id]
    result = subprocess.run(command, check=False)
    return result.returncode


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
            "opencode_agents": len(list((ctx.root / ".opencode/agents").glob("*.md"))),
            "opencode_skills": len(list((ctx.root / ".opencode/skills").glob("*/SKILL.md"))),
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
            "agents": len(list((ctx.root / ".opencode/agents").glob("*.md"))),
            "skills": len(list((ctx.root / ".opencode/skills").glob("*/SKILL.md"))),
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


CLOUD_PROVIDER_HINTS = {
    "opencode-go": "$10/mo subscription. Curated model list. Recommended hosted overlay. Uses OPENCODE_GO_API_KEY.",
    "openrouter": "Free tier, rate-limited. Good trial fallback. Uses OPENROUTER_API_KEY.",
    "opencode-zen": "Pay-per-request (beta). Broader catalog than Go. Uses OPENCODE_ZEN_API_KEY.",
    "codex-auth": "Reuse ChatGPT Plus/Pro/Team via third-party OAuth helper. Uses OPENAI_API_KEY.",
    "anthropic": "Claude 4.x family (API key only — subscription does NOT work). Uses ANTHROPIC_API_KEY.",
    "antigravity": "Hosted fallback for frontier-grade cloud coding. Uses ANTIGRAVITY_API_KEY.",
    "z-ai": "Z.AI GLM family. Uses ZAI_API_KEY.",
    "nvidia-nim": "NVIDIA free/trial OpenAI-compatible endpoints. Uses NVIDIA_API_KEY.",
}


def _prompt_yes_no(prompt, default=True):
    suffix = "[Y/n]" if default else "[y/N]"
    while True:
        answer = input(f"{prompt} {suffix} ").strip().lower()
        if not answer:
            return default
        if answer in {"y", "yes"}:
            return True
        if answer in {"n", "no"}:
            return False


def _prompt_choice(prompt, choices, default_index=0):
    while True:
        print(prompt)
        for idx, (key, label) in enumerate(choices):
            marker = "*" if idx == default_index else " "
            print(f"  {marker} {idx + 1}. {key} — {label}")
        raw = input(f"Pick [1-{len(choices)}, default {default_index + 1}]: ").strip()
        if not raw:
            return choices[default_index][0]
        try:
            idx = int(raw) - 1
        except ValueError:
            print("Enter a number.")
            continue
        if 0 <= idx < len(choices):
            return choices[idx][0]
        print("Out of range.")


def _prompt_multiselect(prompt, choices, preselected):
    selected = set(preselected)
    print(prompt)
    print("Toggle by number. Blank line to accept.")
    while True:
        for idx, (key, label) in enumerate(choices):
            marker = "[x]" if key in selected else "[ ]"
            print(f"  {marker} {idx + 1}. {key} — {label}")
        raw = input(f"Toggle [1-{len(choices)}] or Enter to accept: ").strip()
        if not raw:
            return [key for key, _ in choices if key in selected]
        try:
            idx = int(raw) - 1
        except ValueError:
            print("Enter a number or press Enter to accept.")
            continue
        if 0 <= idx < len(choices):
            key = choices[idx][0]
            if key in selected:
                selected.remove(key)
            else:
                selected.add(key)
        else:
            print("Out of range.")


def _parse_cloud_arg(cloud_arg, no_cloud):
    if no_cloud:
        return []
    if not cloud_arg:
        return []
    return [item.strip() for item in cloud_arg.split(",") if item.strip()]


def _validate_cloud_ids(ctx, cloud_ids):
    catalog = load_json(ctx.paths["provider_catalog"])
    known = {p["id"] for p in catalog["providers"] if p["id"] != "local-cluster"}
    invalid = [cid for cid in cloud_ids if cid not in known]
    if invalid:
        raise SystemExit(f"Unknown cloud provider(s): {', '.join(invalid)}. Known: {', '.join(sorted(known))}")


def _provider_id_from_model(model_selector):
    if not isinstance(model_selector, str) or "/" not in model_selector:
        return ""
    return model_selector.split("/", 1)[0]


def _profile_provider_ids(profile):
    provider_ids = []
    for field in ("default_model", "small_model"):
        provider_id = _provider_id_from_model(profile.get(field, ""))
        if provider_id and provider_id not in provider_ids:
            provider_ids.append(provider_id)
    return provider_ids


def _init_recommendation(profile_id, profile, hardware):
    ram_gb = hardware.get("ram_gb")
    alternatives = family_alternatives(ram_gb)
    recommended_profile = recommend_profile(ram_gb)
    if profile["runtime_mode"] == "cloud":
        recommended_path = "cloud-only zero-download profile"
    else:
        recommended_path = "local-first with optional OpenCode Go and OpenRouter overlays"
    return {
        "selected_profile": profile_id, "selected_label": profile["label"],
        "selected_runtime_mode": profile["runtime_mode"],
        "hardware_recommended_profile": recommended_profile,
        "family_alternatives": alternatives,
        "default_cloud_overlays": ["opencode-go", "openrouter"],
        "recommended_path": recommended_path,
    }


def _status_item(item_id, label, ready, detail, command=None, optional=False, install_hint=None):
    item = {
        "id": item_id, "label": label,
        "status": "ready" if ready else ("optional" if optional else "blocked"),
        "detail": detail,
    }
    if command:
        item["command"] = command
    if install_hint and item["status"] != "ready":
        item["install_hint"] = install_hint
    return item


def _init_required_provider_ids(ctx, profile, cloud_ids):
    required = []
    known_cloud = {p["id"] for p in load_json(ctx.paths["provider_catalog"])["providers"] if p["id"] != "local-cluster"}
    for provider_id in _profile_provider_ids(profile) + list(cloud_ids):
        if provider_id in known_cloud and provider_id not in required:
            required.append(provider_id)
    return required


def _init_prerequisites(ctx, profile, cloud_ids):
    required = [
        _status_item("python", "Python 3", command_exists("python3") or command_exists("python"),
                     "Required to run the lac CLI.", command="python3 --version", install_hint=_install_hint("python")),
        _status_item("opencode", "OpenCode CLI", command_exists("opencode"),
                     "Required for `./bin/lac client open opencode`.", command="opencode --version",
                     install_hint=_install_hint("opencode")),
    ]
    if profile.get("local_runtime_required"):
        runtime = selected_local_runtime(profile)
        runtime_command = "omlx" if runtime == "omlx" else "llama-server"
        required.append(
            _status_item(runtime_command, "Local runtime", command_exists(runtime_command),
                         f"Required to start the selected local runtime ({runtime}).",
                         command=f"{runtime_command} --help", install_hint=_install_hint(runtime_command)))
    provider_catalog = {p["id"]: p for p in load_json(ctx.paths["provider_catalog"])["providers"]}
    for provider_id in _init_required_provider_ids(ctx, profile, cloud_ids):
        provider = provider_catalog[provider_id]
        env_var = provider["env_var"]
        env_command = f"$env:{env_var} = \"...\"" if _host_install_platform() == "windows" else f"export {env_var}=..."
        required.append(
            _status_item(f"{provider_id}-api-key", f"{provider['label']} API key",
                         bool(os.environ.get(env_var)), f"Set {env_var} to use {provider_id}.",
                         command=env_command, install_hint=_install_hint(f"{provider_id}-api-key", env_var=env_var)))
    optional = [
        _status_item("hf", "Hugging Face CLI", command_exists("hf") or command_exists("huggingface-cli"),
                     "Optional helper for `./bin/lac models sync`.", command="hf --version",
                     optional=True, install_hint=_install_hint("hf")),
        _status_item("omlx", "oMLX", command_exists("omlx"),
                     "Optional macOS MLX runtime when compatible models are selected.",
                     command="omlx --help", optional=True, install_hint=_install_hint("omlx")),
    ]
    return {"required": required, "optional": optional}


def _init_readiness(prerequisites, profile):
    required = prerequisites["required"]
    blocked = [item for item in required if item["status"] == "blocked"]
    ready = [item for item in required if item["status"] == "ready"]
    readiness = [
        {"id": "config-rendered", "label": "Runtime config rendered", "status": "ready",
         "detail": "Generated state and client config are in place."},
        {"id": "required-prerequisites", "label": "Required prerequisites",
         "status": "ready" if not blocked else "blocked",
         "detail": f"{len(ready)}/{len(required)} required checks are ready."},
    ]
    if profile.get("downloads_required"):
        readiness.append({"id": "model-downloads", "label": "Model weights", "status": "blocked",
                          "detail": "Run the model sync command before starting the local runtime."})
    else:
        readiness.append({"id": "model-downloads", "label": "Model weights", "status": "ready",
                          "detail": "Selected profile does not require local model downloads."})
    return readiness


def _init_status(readiness):
    return "blocked" if any(item["status"] == "blocked" for item in readiness) else "ready"


def _next_steps(ctx, profile_id, cloud_ids, also_download_profile=None):
    profile = ctx.get_profile(profile_id)
    steps = []
    for cid in cloud_ids:
        hint = CLOUD_PROVIDER_HINTS.get(cid, "see docs/providers/AUTHENTICATION.md")
        steps.append(f"Enable {cid}: {hint}")
    if profile.get("downloads_required"):
        steps.append(f"Download models: ./bin/lac models sync {profile_id}")
        if also_download_profile and also_download_profile != profile_id:
            steps.append(f"Also download alternate family weights: ./bin/lac models sync {also_download_profile}")
    if profile.get("local_runtime_required"):
        steps.append("Start runtime: ./bin/lac runtime start")
    else:
        required_providers = _init_required_provider_ids(ctx, profile, cloud_ids)
        for provider_id in required_providers:
            steps.append(f"Verify {provider_id}: ./bin/lac provider verify {provider_id}")
    steps.append("Open client: ./bin/lac client open opencode")
    return steps


def init_wizard(ctx, yes=False, profile=None, cloud=None, no_cloud=False, also_download=False):
    hardware = detect_hardware()
    ram_gb = hardware["ram_gb"]
    if yes:
        chosen_profile = profile or recommend_profile(ram_gb)
        ctx.get_profile(chosen_profile)
        cloud_ids = _parse_cloud_arg(cloud, no_cloud)
        if not cloud_ids and not no_cloud and cloud is None:
            cloud_ids = ["opencode-go", "openrouter"]
        _validate_cloud_ids(ctx, cloud_ids)
        also_download_profile = None
    else:
        ram_label = f"{ram_gb:.1f} GB" if ram_gb is not None else "unknown"
        print(f"Detected: {hardware['os']} / {hardware['arch']} / RAM {ram_label}")
        alternates = family_alternatives(ram_gb)
        family_choices = [("qwen", FAMILY_DESCRIPTIONS["qwen"]), ("gemma", FAMILY_DESCRIPTIONS["gemma"])]
        family = _prompt_choice("Which local model family?", family_choices, default_index=0)
        recommended = recommend_profile(ram_gb, family=family)
        if profile:
            ctx.get_profile(profile)
            chosen_profile = profile
        else:
            print(f"Recommended profile for your hardware: {recommended}")
            if not _prompt_yes_no("Use this profile?", default=True):
                print("Available profiles:")
                options = [(pid, ctx.profiles[pid]["label"]) for pid in ctx.profiles]
                chosen_profile = _prompt_choice("Pick a profile:", options, default_index=list(ctx.profiles).index(recommended))
            else:
                chosen_profile = recommended
        also_download_profile = None
        other_family = "gemma" if family == "qwen" else "qwen"
        other_profile = alternates[other_family]
        if other_profile != chosen_profile:
            if _prompt_yes_no(f"Also download {other_family.capitalize()} weights ({other_profile}) for optional switching?", default=False):
                also_download_profile = other_profile
        cloud_choices = [(cid, CLOUD_PROVIDER_HINTS[cid]) for cid in CLOUD_PROVIDER_HINTS]
        cloud_ids = _prompt_multiselect("Which hosted model overlays do you want in addition to local models?",
                                        cloud_choices, preselected=["opencode-go", "openrouter"])
    summary = profile_apply(ctx, chosen_profile, verbose_runtime=False)
    chosen_profile_record = ctx.get_profile(chosen_profile)
    prerequisites = _init_prerequisites(ctx, chosen_profile_record, cloud_ids)
    readiness = _init_readiness(prerequisites, chosen_profile_record)
    generated = dict(summary["generated"])
    generated["client_manifest"] = summary["render"]["manifest_path"]
    result = {
        "applied": True, "status": _init_status(readiness), "profile": chosen_profile,
        "cloud": cloud_ids, "hardware": hardware,
        "recommendation": _init_recommendation(chosen_profile, chosen_profile_record, hardware),
        "prerequisites": prerequisites, "readiness": readiness, "generated": generated,
        "also_download_profile": also_download_profile, "state_root": summary["state_root"],
        "next_steps": _next_steps(ctx, chosen_profile, cloud_ids, also_download_profile=also_download_profile),
    }
    return result


def _render_init_section(title, items):
    print(title)
    for item in items:
        marker = {"ready": "ready", "blocked": "blocked", "optional": "optional"}.get(item["status"], item["status"])
        print(f"  - {marker}: {item['label']} — {item['detail']}")
        if item.get("command") and item["status"] == "blocked":
            print(f"    next: {item['command']}")
        install_hint = item.get("install_hint")
        if install_hint and item["status"] != "ready":
            print(f"    note: {install_hint['summary']}")
            for command in install_hint.get("commands", []):
                print(f"    install: {command}")


def render_init_text(result):
    hardware = result["hardware"]
    ram_label = f"{hardware['ram_gb']:.1f} GB" if hardware.get("ram_gb") is not None else "unknown"
    recommendation = result["recommendation"]
    print("Local AI Cluster init")
    print(f"Status: {result['status']}")
    print(f"Detected: {hardware['os']} / {hardware['arch']} / RAM {ram_label}")
    print(f"Selected profile: {result['profile']} ({recommendation['selected_label']})")
    print(f"Recommended path: {recommendation['recommended_path']}")
    if result["cloud"]:
        print(f"Cloud overlays selected: {', '.join(result['cloud'])}")
    elif recommendation["selected_runtime_mode"] == "cloud":
        print("Cloud overlays: none added (selected profile is already cloud-only)")
    else:
        print("Cloud overlays: none (pure local)")
    print("Generated:")
    for label, path in result["generated"].items():
        print(f"  - {label}: {path}")
    _render_init_section("Readiness:", result["readiness"])
    _render_init_section("Required checks:", result["prerequisites"]["required"])
    optional_blocked = [item for item in result["prerequisites"]["optional"] if item["status"] != "ready"]
    if optional_blocked:
        _render_init_section("Optional checks:", optional_blocked)
    print("Next steps:")
    for step in result["next_steps"]:
        print(f"  - {step}")


def render_pack_list(packs):
    for pack in packs:
        clients = ", ".join(pack["supported_clients"])
        installed = "installed" if pack.get("installed") else "not installed"
        print(f"{pack['id']}: {pack['label']} | trust {pack['trust_level']} | {pack['asset_count']} assets | {installed} | clients: {clients}")


def render_pack_show(pack):
    print(f"{pack['id']}: {pack['label']}")
    print(f"  trust: {pack['trust_level']}")
    print(f"  installed: {'yes' if pack.get('installed') else 'no'}")
    print(f"  description: {pack['description']}")
    print(f"  clients: {', '.join(pack['supported_clients'])}")
    print(f"  tools: {', '.join(pack['required_tools'])}")
    print(f"  assets ({pack['asset_count']}):")
    for asset in pack["assets"]:
        print(f"    - {asset['id']} [{asset['type']}] support={asset['support_tier']} trust={asset['trust_level']} installed={'yes' if asset.get('installed') else 'no'}")


def render_skill_status(payload):
    state = "installed" if payload.get("installed") else "not installed"
    print(f"{payload['id']}: {state} | {payload['path']}")
    if payload.get("message"):
        print(payload["message"])


def render_skill_verify(payload):
    ok = "ok" if payload.get("ok") else "FAIL"
    print(f"{payload['id']}: {ok} | {payload['path']}")
    for check in payload.get("checks", []):
        state = "ok" if check["ok"] else "FAIL"
        print(f"  {check['name']}: {state} {check.get('detail', '')}".rstrip())


def render_scenario_list(scenarios):
    for scenario in scenarios:
        profiles = ", ".join(scenario["recommended_profiles"])
        packs = ", ".join(scenario["recommended_packs"])
        print(f"{scenario['id']}: {scenario['label']} | profiles: {profiles} | packs: {packs}")


def render_scenario_show(scenario):
    print(f"{scenario['id']}: {scenario['label']}")
    print(f"  description: {scenario['description']}")
    print(f"  profiles: {', '.join(scenario['recommended_profiles'])}")
    print(f"  packs: {', '.join(scenario['recommended_packs'])}")
    print(f"  client_target: {scenario['client_target']}")


def render_provider_list(providers):
    for provider in providers:
        if provider["id"] == "local-cluster":
            readiness = "local profile active" if provider["configured"] else "local profile inactive"
            print(f"{provider['id']}: {provider['label']} | {readiness} | risk {provider['risk_level']} | verified {provider['last_verified_at']}")
            continue
        flag = "ready" if provider["configured"] else "unset"
        print(f"{provider['id']}: {provider['label']} | env {provider['env_var']} ({flag}) | risk {provider['risk_level']} | verified {provider['last_verified_at']}")


def _catalog_model_short_id(provider_id, model_id):
    prefix = f"{provider_id}/"
    if model_id.startswith(prefix):
        return model_id[len(prefix):]
    return model_id


def render_provider_models(provider_id, models):
    if not models:
        print(f"{provider_id}: no catalog models recorded")
        return
    for model in models:
        short_id = _catalog_model_short_id(provider_id, model["id"])
        context = model.get("context_length")
        context_label = str(context) if context is not None else "?"
        print(f"{short_id}: context {context_label} | verified {model['last_verified_at']}")


def render_provider_status(payload):
    print(f"Providers: {payload['configured_count']} configured, {payload['unconfigured_count']} unconfigured")
    if payload["configured"]:
        print("  configured:")
        render_provider_list(payload["configured"])
    if payload["unconfigured"]:
        print("  unconfigured:")
        render_provider_list(payload["unconfigured"])


def _render_verify_row(record):
    status = record["status"]
    latency = f"{record['latency_ms']}ms" if record["latency_ms"] is not None else ""
    detail = record.get("reason") or record.get("endpoint") or ""
    print(f"{record['id']:<18}| {status:<6}| {latency:<10}| {detail}")


def render_provider_verify_single(record):
    _render_verify_row(record)


def render_provider_verify_all(payload):
    for record in payload["results"]:
        _render_verify_row(record)
    summary = payload["summary"]
    print(f"Summary: {summary['ok']} ok, {summary['skipped']} skipped, {summary['error']} error")


def render_doctor_text(report):
    ok = "ok" if report["ok"] else "FAIL"
    profile_id = report["active_profile_id"] or "(none)"
    print(f"Doctor: {ok} | active profile: {profile_id}")
    print(f"State root: {report['state_root']}")
    failures = report.get("failures", [])
    if failures:
        print(f"Failures ({len(failures)}):")
        for path in failures:
            print(f"  - {path}")
    missing_sources = [c for c in report["checks"] if c["kind"] == "source" and not c["exists"]]
    missing_generated = [c for c in report["checks"] if c["kind"] == "generated" and not c["exists"]]
    if missing_sources:
        print(f"Missing sources: {len(missing_sources)}")
    if missing_generated:
        print(f"Missing generated state: {len(missing_generated)} (run ./bin/lac profile apply <profile>)")
    commands = report["commands"]
    cmd_line = ", ".join(f"{name}={'yes' if exists else 'no'}" for name, exists in commands.items())
    print(f"Commands: {cmd_line}")
    command_hints = report.get("command_install_hints", {})
    if command_hints:
        print("Missing command install notes:")
        for name, hint in command_hints.items():
            print(f"  - {name}: {hint['summary']}")
            for command in hint.get("commands", []):
                print(f"    install: {command}")
    runtime = report["runtime"]
    running = "yes" if runtime.get("running") else "no"
    health = "yes" if runtime.get("health_reachable") else "no"
    print(f"Runtime: {runtime['url']} | running={running} | health={health}")
    providers = report["provider_readiness"]
    configured = sum(1 for p in providers if p["configured"])
    print(f"Providers: {configured}/{len(providers)} configured")
    assets = report["assets"]
    print(f"Assets: {assets['catalog_asset_count']} cataloged | {assets['pack_count']} packs | {assets['opencode_agents']} agents | {assets['opencode_skills']} skills")
    print("Run with --json for full detail.")


def render_smoke_text(report):
    profile_id = report.get("active_profile_id") or "(none)"
    if report.get("skipped"):
        print(f"Smoke: skipped ({report.get('reason')}) | profile: {profile_id}")
        print("Run with --json for full detail.")
        return
    ok = "ok" if report.get("ok") else "FAIL"
    print(f"Smoke: {ok} | profile: {profile_id}")
    if "error" in report:
        print(f"Error: {report['error']}")
    if "model_count" in report:
        print(f"Runtime: {report.get('runtime_url')} | models: {report['model_count']}")
    if "benchmark_ms" in report:
        print(f"Benchmark: {report['benchmark_ms']} ms")
    preview = report.get("chat_content_preview")
    if preview:
        print(f"Reply preview: {preview}")
    print("Run with --json for full detail.")


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
    parser = argparse.ArgumentParser(prog="lac", description="Local AI Cluster 2.0 CLI")
    parser.add_argument("--version", action="version", version=f"lac {VERSION}")
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON")
    subparsers = parser.add_subparsers(dest="command", required=True)

    doctor_parser = subparsers.add_parser("doctor")
    doctor_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    doctor_parser.add_argument("--strict", action="store_true")
    doctor_parser.add_argument("--bootstrap-hint", action="store_true")

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
    client_render_parser.add_argument("target", choices=["opencode", "claude-code", "codex-reference"])
    client_open_parser = client_sub.add_parser("open")
    client_open_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    client_open_parser.add_argument("target", choices=["opencode"])
    client_open_parser.add_argument("--desktop", action="store_true")

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

    init_parser = subparsers.add_parser("init", help="Interactive onboarding wizard")
    init_parser.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    init_parser.add_argument("--yes", action="store_true", help="Non-interactive; accept defaults or flag values")
    init_parser.add_argument("--profile", help="Profile id to apply (skip recommendation)")
    init_parser.add_argument("--cloud", help="Comma-separated cloud provider ids to enable (non-interactive)")
    init_parser.add_argument("--no-cloud", action="store_true", help="Do not enable any cloud overlay")

    return parser


def main():
    parser = build_parser()
    argv, json_mode = _strip_global_json_flag(sys.argv[1:])
    args = parser.parse_args(argv)
    args.json = bool(getattr(args, "json", False) or json_mode)
    ctx = Context()

    if args.command == "doctor":
        report = doctor(ctx, strict=args.strict, bootstrap_hint=args.bootstrap_hint)
        emit(report, args.json, kind="doctor")
        raise SystemExit(0 if report["ok"] or not args.strict else 1)

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
            emit(client_open(ctx, args.target, desktop=args.desktop), args.json)
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

    if args.command == "init":
        result = init_wizard(ctx, yes=args.yes, profile=args.profile, cloud=args.cloud, no_cloud=args.no_cloud)
        emit(result, args.json, kind="init")
        return

    parser.error("Unknown command")


if __name__ == "__main__":
    main()
