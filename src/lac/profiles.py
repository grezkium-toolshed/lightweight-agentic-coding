"""Profile management: apply, list, recommend, hardware detection."""

from lac.hardware import detect_hardware, detect_total_ram_gb, detect_vram_gb, effective_memory_gb


def render_preset(ctx, profile):
    models_dir = ctx.models_root
    preset_path = ctx.root / profile["preset"]
    if not preset_path.is_file():
        raise SystemExit(f"Preset template missing: {preset_path}")
    rendered = preset_path.read_text(encoding="utf-8")
    rendered = rendered.replace("__MODELS_DIR__", str(models_dir).replace("\\", "/"))
    rendered = rendered.replace("__CLUSTER_ROOT__", str(ctx.root).replace("\\", "/"))
    ctx.paths["active_preset"].parent.mkdir(parents=True, exist_ok=True)
    ctx.paths["active_preset"].write_text(rendered, encoding="utf-8")
    return ctx.paths["active_preset"]


def profile_list(ctx):
    rows = []
    for profile_id, profile in ctx.profiles.items():
        rows.append(
            {
                "id": profile_id,
                "label": profile["label"],
                "runtime_mode": profile["runtime_mode"],
                "verification_tier": profile["verification_tier"],
                "memory_target_gb": profile.get("memory_target_gb"),
                "recommendation_floor_gb": profile.get("recommendation_floor_gb"),
                "estimated_default_weight_gb": profile.get("estimated_default_weight_gb"),
                "auto_recommend": profile.get("auto_recommend", False),
                "primary_workload": profile["primary_workload"],
                "recommended_for": profile["recommended_for"],
                "supported_clients": profile["supported_clients"],
            }
        )
    return rows


def profile_apply(ctx, profile_id, render_target="opencode", verbose_runtime=True):
    from lac.config import render_opencode_config
    from lac.clients import render_client

    profile = ctx.get_profile(profile_id)
    render_preset(ctx, profile)
    render_opencode_config(ctx, profile_id, profile, verbose_runtime=verbose_runtime)
    ctx.paths["active_profile"].parent.mkdir(parents=True, exist_ok=True)
    ctx.paths["active_profile"].write_text(f"{profile_id}\n", encoding="utf-8")

    def utc_now():
        from datetime import datetime, timezone
        return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

    def write_json(path, payload):
        import json
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    summary = {
        "applied_at": utc_now(),
        "profile": profile,
        "profile_id": profile_id,
        "state_root": str(ctx.state_root),
        "generated": {
            "active_profile": str(ctx.paths["active_profile"]),
            "active_preset": str(ctx.paths["active_preset"]),
            "opencode_config": str(ctx.paths["opencode_config"]),
            "opencode_config_dir": str(ctx.paths["opencode_config_dir"]),
            "dcp_config": str(ctx.paths["dcp_config"]),
        },
    }
    write_json(ctx.paths["active_profile_summary"], summary)
    render_result = render_client(ctx, render_target)
    summary["render"] = render_result
    return summary


RAM_BUCKETS = [
    (120, ["128gb-ds4-flash", "128gb-multi", "128gb-qwen122b", "128gb-minimax"], "gemma-64gb"),
    (60, ["64gb"], "gemma-64gb"),
    (30, ["32gb"], "gemma-32gb"),
    (22, ["24gb"], "gemma-24gb"),
    (14, ["16gb"], "gemma-16gb"),
    (10, ["12gb"], "gemma-8gb"),
    (7, ["8gb"], "gemma-8gb"),
    (5, ["6gb"], "gemma-6gb"),
    (0, ["4gb"], "4gb"),
]

FAMILY_DESCRIPTIONS = {
    "qwen": "Qwen 3.6 — default. Stronger coding and agentic tool-use. Best for most workflows.",
    "gemma": "Gemma 4 — multilingual leader. Stronger EU-language handling, competitive reasoning.",
}


def _is_apple_silicon(hardware):
    return bool(
        hardware
        and hardware.get("os") == "darwin"
        and str(hardware.get("arch", "")).lower() in {"arm64", "aarch64"}
    )


def _eligible_qwen_profiles(profile_ids, profiles=None, hardware=None):
    if _is_apple_silicon(hardware):
        return profile_ids
    eligible = []
    for profile_id in profile_ids:
        profile = (profiles or {}).get(profile_id, {})
        if profile.get("preferred_runtime") == "ds4" or profile_id == "128gb-ds4-flash":
            continue
        eligible.append(profile_id)
    return eligible or profile_ids


def _bucket_for_ram(ram_gb, profiles=None, hardware=None):
    if ram_gb is None:
        return RAM_BUCKETS[-2]
    if profiles:
        profile = profiles.get("48gb", {})
        if profile.get("auto_recommend") and ram_gb >= profile.get("recommendation_floor_gb", 46):
            if ram_gb < 60:
                return (profile["recommendation_floor_gb"], ["48gb"], "gemma-32gb")
    for threshold, qwen_profiles, gemma_profile in RAM_BUCKETS:
        if ram_gb >= threshold:
            return (
                threshold,
                _eligible_qwen_profiles(qwen_profiles, profiles=profiles, hardware=hardware),
                gemma_profile,
            )
    return RAM_BUCKETS[-1]


def recommend_profile(ram_gb, family="qwen", profiles=None, hardware=None):
    if hardware and hardware.get("memory_kind") == "unified" and ram_gb is not None and 14 <= ram_gb < 22:
        return "macos-16gb" if family == "qwen" else "gemma-16gb"
    _, qwen_profiles, gemma_profile = _bucket_for_ram(ram_gb, profiles, hardware)
    if family == "gemma":
        return gemma_profile
    return qwen_profiles[0]


def family_alternatives(ram_gb, profiles=None, hardware=None):
    _, qwen_profiles, gemma_profile = _bucket_for_ram(ram_gb, profiles, hardware)
    if hardware and hardware.get("memory_kind") == "unified" and ram_gb is not None and 14 <= ram_gb < 22:
        qwen_profiles, gemma_profile = ["macos-16gb"], "gemma-16gb"
    return {
        "qwen": qwen_profiles[0],
        "gemma": gemma_profile,
    }
