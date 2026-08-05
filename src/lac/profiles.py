"""Profile management: apply, list, recommend, hardware detection."""

import os
import platform
import subprocess
import sys
from pathlib import Path

from lac.lib.jsonc import load_jsonc


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


def detect_total_ram_gb():
    try:
        if sys.platform == "darwin":
            raw = subprocess.check_output(["sysctl", "-n", "hw.memsize"], stderr=subprocess.DEVNULL)
            return int(raw.strip()) / (1024 ** 3)
        if sys.platform.startswith("linux"):
            meminfo = Path("/proc/meminfo").read_text(encoding="utf-8")
            for line in meminfo.splitlines():
                if line.startswith("MemTotal:"):
                    kb = int(line.split()[1])
                    return kb / (1024 ** 2)
        if os.name == "nt":
            raw = subprocess.check_output(
                ["powershell.exe", "-NoProfile", "-Command", "(Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize"],
                stderr=subprocess.DEVNULL,
            )
            kb = int(raw.strip())
            return kb / (1024 ** 2)
    except Exception:
        return None
    return None


def detect_vram_gb():
    """Discrete-GPU VRAM in GB via nvidia-smi; None when absent (e.g. Apple Silicon or no NVIDIA GPU)."""
    try:
        raw = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=memory.total", "--format=csv,noheader,nounits"],
            stderr=subprocess.DEVNULL, timeout=10,
        ).decode("utf-8", errors="ignore").strip().splitlines()
        if raw:
            return float(raw[0].strip()) / 1024.0
    except Exception:
        pass
    return None


def detect_hardware():
    return {
        "os": sys.platform,
        "arch": platform.machine(),
        "ram_gb": detect_total_ram_gb(),
        "vram_gb": detect_vram_gb(),
    }


def effective_memory_gb(hardware):
    """Bucketing memory: discrete VRAM when it is smaller than RAM, else RAM.

    On Apple Silicon (unified memory) vram_gb is None, so RAM wins. On a
    discrete-GPU laptop the model must fit VRAM, so VRAM wins.
    """
    ram = hardware.get("ram_gb")
    vram = hardware.get("vram_gb")
    if vram is not None and (ram is None or vram < ram):
        return vram
    return ram


def _bucket_for_ram(ram_gb):
    if ram_gb is None:
        return RAM_BUCKETS[-2]
    for threshold, qwen_profiles, gemma_profile in RAM_BUCKETS:
        if ram_gb >= threshold:
            return (threshold, qwen_profiles, gemma_profile)
    return RAM_BUCKETS[-1]


def recommend_profile(ram_gb, family="qwen"):
    _, qwen_profiles, gemma_profile = _bucket_for_ram(ram_gb)
    if family == "gemma":
        return gemma_profile
    return qwen_profiles[0]


def family_alternatives(ram_gb):
    _, qwen_profiles, gemma_profile = _bucket_for_ram(ram_gb)
    return {
        "qwen": qwen_profiles[0],
        "gemma": gemma_profile,
    }
