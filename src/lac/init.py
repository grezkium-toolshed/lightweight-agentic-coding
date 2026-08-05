"""Init wizard: interactive onboarding, prompts, prerequisites, readiness."""

import os

from lac.profiles import family_alternatives, recommend_profile, FAMILY_DESCRIPTIONS, effective_memory_gb
from lac.runtime import selected_local_runtime


CLOUD_PROVIDER_HINTS = {
    "opencode-go": "$10/mo subscription. Curated model list. Recommended hosted overlay. Uses OPENCODE_GO_API_KEY.",
    "openrouter": "Free tier, rate-limited. Good trial fallback. Uses OPENROUTER_API_KEY.",
    "nvidia-nim": "NVIDIA free/trial OpenAI-compatible endpoints. Uses NVIDIA_API_KEY.",
    "anthropic": "Claude 4.x family (API key only — subscription does NOT work). Uses ANTHROPIC_API_KEY.",
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


def _validate_cloud_ids(ctx, cloud_ids, load_json):
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
    eff_gb = effective_memory_gb(hardware)
    ram_gb = hardware.get("ram_gb")
    alternatives = family_alternatives(eff_gb)
    recommended_profile = recommend_profile(eff_gb)
    if profile["runtime_mode"] == "cloud":
        recommended_path = "cloud-only zero-download profile"
    elif profile.get("preferred_runtime") == "ds4":
        recommended_path = "ds4 local runtime for 128 GB+ DeepSeek V4 Flash"
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


def _init_required_provider_ids(ctx, profile, cloud_ids, load_json):
    required = []
    known_cloud = {p["id"] for p in load_json(ctx.paths["provider_catalog"])["providers"] if p["id"] != "local-cluster"}
    for provider_id in _profile_provider_ids(profile) + list(cloud_ids):
        if provider_id in known_cloud and provider_id not in required:
            required.append(provider_id)
    return required


def _init_prerequisites(ctx, profile, cloud_ids, load_json, command_exists, _host_install_platform, _install_hint):
    from lac.profiles import profile_apply
    required = [
        _status_item("python", "Python 3", command_exists("python3") or command_exists("python"),
                     "Required to run the lac CLI.", command="python3 --version", install_hint=_install_hint("python")),
        _status_item("opencode", "OpenCode CLI", command_exists("opencode"),
                     "Required for `lac client open opencode`.", command="opencode --version",
                     install_hint=_install_hint("opencode")),
    ]
    if profile.get("local_runtime_required"):
        runtime = selected_local_runtime(profile)
        if runtime == "omlx":
            runtime_id = "omlx"
            runtime_command = "omlx"
        elif runtime == "ds4":
            runtime_id = "ds4"
            runtime_command = os.environ.get("DS4_BIN", "ds4-server")
        else:
            runtime_id = "llama-server"
            runtime_command = "llama-server"
        required.append(
            _status_item(runtime_id, "Local runtime", command_exists(runtime_command),
                         f"Required to start the selected local runtime ({runtime}).",
                         command=f"{runtime_command} --help", install_hint=_install_hint(runtime_id)))
    provider_catalog = {p["id"]: p for p in load_json(ctx.paths["provider_catalog"])["providers"]}
    for provider_id in _init_required_provider_ids(ctx, profile, cloud_ids, load_json):
        provider = provider_catalog[provider_id]
        env_var = provider["env_var"]
        env_command = f"$env:{env_var} = \"...\"" if _host_install_platform() == "windows" else f"export {env_var}=..."
        required.append(
            _status_item(f"{provider_id}-api-key", f"{provider['label']} API key",
                         bool(os.environ.get(env_var)), f"Set {env_var} to use {provider_id}.",
                         command=env_command, install_hint=_install_hint(f"{provider_id}-api-key", env_var=env_var)))
    optional = [
        _status_item("openchamber", "OpenChamber UI", command_exists("openchamber"),
                     "Recommended chat UI (web/desktop) — the front door for non-coding use.",
                     command="openchamber --version", optional=True, install_hint=_install_hint("openchamber")),
        _status_item("hf", "Hugging Face CLI", command_exists("hf") or command_exists("huggingface-cli"),
                     "Optional helper for `lac models sync`.", command="hf --version",
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


def _next_steps(ctx, profile_id, cloud_ids, load_json):
    profile = ctx.get_profile(profile_id)
    steps = []
    for cid in cloud_ids:
        hint = CLOUD_PROVIDER_HINTS.get(cid, "see docs/providers/AUTHENTICATION.md")
        steps.append(f"Enable {cid}: {hint}")
    if profile.get("downloads_required"):
        steps.append(f"Download models: lac models sync {profile_id}")
    if profile.get("local_runtime_required"):
        steps.append("Start runtime: lac runtime start")
    else:
        required_providers = _init_required_provider_ids(ctx, profile, cloud_ids, load_json)
        for provider_id in required_providers:
            steps.append(f"Verify {provider_id}: lac provider verify {provider_id}")
    steps.append("Open the chat UI (recommended): lac client open openchamber")
    steps.append("Or the coding agent: lac client open opencode")
    return steps


def init_wizard(ctx, yes=False, profile=None, cloud=None, no_cloud=False, also_download=False,
                load_json=None, command_exists=None, _host_install_platform=None, _install_hint=None):
    from lac.profiles import profile_apply, detect_hardware, effective_memory_gb
    hardware = detect_hardware()
    ram_gb = effective_memory_gb(hardware)
    if yes:
        chosen_profile = profile or recommend_profile(ram_gb)
        ctx.get_profile(chosen_profile)
        cloud_ids = _parse_cloud_arg(cloud, no_cloud)
        if not cloud_ids and not no_cloud and cloud is None:
            cloud_ids = ["opencode-go", "openrouter"]
        _validate_cloud_ids(ctx, cloud_ids, load_json)
        also_download_profile = None
    else:
        ram_label = f"{ram_gb:.1f} GB" if ram_gb is not None else "unknown"
        vram_label = f"{hardware['vram_gb']:.1f} GB" if hardware.get("vram_gb") is not None else ""
        detected_label = f"RAM {ram_label}" + (f" / VRAM {vram_label}" if vram_label else "")
        print(f"Detected: {hardware['os']} / {hardware['arch']} / {detected_label}")
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
    prerequisites = _init_prerequisites(ctx, chosen_profile_record, cloud_ids, load_json, command_exists, _host_install_platform, _install_hint)
    readiness = _init_readiness(prerequisites, chosen_profile_record)
    generated = dict(summary["generated"])
    generated["client_manifest"] = summary["render"]["manifest_path"]
    result = {
        "applied": True, "status": _init_status(readiness), "profile": chosen_profile,
        "cloud": cloud_ids, "hardware": hardware,
        "recommendation": _init_recommendation(chosen_profile, chosen_profile_record, hardware),
        "prerequisites": prerequisites, "readiness": readiness, "generated": generated,
        "also_download_profile": also_download_profile, "state_root": summary["state_root"],
        "next_steps": _next_steps(ctx, chosen_profile, cloud_ids, load_json),
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
    print("  lac init — Lightweight Agentic Coding")
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
