"""Small, dependency-free hardware probes used by profile recommendation."""

import json
import os
import platform
import re
import subprocess
import sys
from pathlib import Path


def _run(command, timeout=5):
    try:
        result = subprocess.run(
            command, capture_output=True, text=True, timeout=timeout, check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    return "\n".join(part for part in (result.stdout, result.stderr) if part).strip()


def detect_total_ram_gb():
    try:
        if sys.platform == "darwin":
            raw = _run(["sysctl", "-n", "hw.memsize"])
            if raw.isdigit():
                return int(raw) / (1024 ** 3)
        if sys.platform.startswith("linux"):
            for line in Path("/proc/meminfo").read_text(encoding="utf-8").splitlines():
                if line.startswith("MemTotal:"):
                    return int(line.split()[1]) / (1024 ** 2)
        if os.name == "nt":
            raw = _run([
                "powershell.exe", "-NoProfile", "-Command",
                "(Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize",
            ])
            return int(raw) / (1024 ** 2)
    except (OSError, ValueError):
        pass
    try:
        return os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_PHYS_PAGES") / (1024 ** 3)
    except (AttributeError, OSError, ValueError):
        pass
    return None


def _vendor(name):
    lowered = name.lower()
    for token, vendor in (
        ("nvidia", "nvidia"), ("amd", "amd"), ("radeon", "amd"),
        ("intel", "intel"), ("qualcomm", "qualcomm"), ("adreno", "qualcomm"),
        ("apple", "apple"),
    ):
        if token in lowered:
            return vendor
    return "unknown"


def _memory_kind(name, vendor=None):
    lowered = name.lower()
    vendor = vendor or _vendor(name)
    if vendor == "qualcomm" or "integrated" in lowered:
        return "shared"
    if vendor == "intel" and "arc" not in lowered:
        return "shared"
    if vendor == "amd" and any(token in lowered for token in ("radeon(tm) graphics", "apu", "vega graphics")):
        return "shared"
    return "dedicated"


def _record(name, budget_gb, source, kind=None, confidence="medium"):
    vendor = _vendor(name)
    return {
        "kind": kind or _memory_kind(name, vendor),
        "budget_gb": round(budget_gb, 2) if budget_gb is not None else None,
        "source": source,
        "vendor": vendor,
        "device": name.strip() or "unknown GPU",
        "confidence": confidence,
    }


def parse_nvidia_smi(text):
    records = []
    for line in text.splitlines():
        match = re.match(r"\s*(.+?)\s*,\s*([0-9.]+)\s*(?:MiB)?\s*$", line)
        if match:
            records.append(_record(match.group(1), float(match.group(2)) / 1024, "nvidia-smi", "dedicated", "high"))
    return records


def parse_llama_devices(text):
    records = []
    for line in text.splitlines():
        match = re.search(r"^\s*(?:[-*]\s*)?([^:]+):\s*(.+?)\s*\(([0-9.]+)\s*(MiB|GiB)", line, re.I)
        if not match:
            continue
        if "cpu" in f"{match.group(1)} {match.group(2)}".lower():
            continue
        amount = float(match.group(3))
        budget = amount / 1024 if match.group(4).lower() == "mib" else amount
        if budget <= 0:
            continue
        records.append(_record(f"{match.group(1).strip()} {match.group(2).strip()}", budget, "llama.cpp", confidence="medium"))
    return records


def parse_rocm_smi(text):
    try:
        payload = json.loads(text)
    except (TypeError, ValueError):
        return []
    records = []
    for device, values in (payload.items() if isinstance(payload, dict) else []):
        if not isinstance(values, dict):
            continue
        total = next((value for key, value in values.items() if "vram total" in key.lower()), None)
        try:
            records.append(_record(f"AMD {device}", float(total) / (1024 ** 3), "rocm-smi", "dedicated", "high"))
        except (TypeError, ValueError):
            continue
    return records


def parse_xpu_smi(text):
    try:
        payload = json.loads(text)
    except (TypeError, ValueError):
        return []
    devices = payload.get("device_list", []) if isinstance(payload, dict) else payload
    records = []
    for device in devices:
        if not isinstance(device, dict):
            continue
        name = str(device.get("device_name") or device.get("name") or "Intel GPU")
        total = device.get("memory_physical_size_byte") or device.get("memory_size")
        try:
            amount = float(total)
        except (TypeError, ValueError):
            continue
        budget = amount / (1024 ** 3) if amount > 1024 ** 2 else amount / 1024
        records.append(_record(name, budget, "xpu-smi", confidence="high"))
    return records


def parse_windows_adapters(text):
    try:
        payload = json.loads(text)
    except (TypeError, ValueError):
        return []
    records = []
    for item in payload if isinstance(payload, list) else [payload]:
        if not isinstance(item, dict):
            continue
        name = str(item.get("Name") or item.get("AdapterCompatibility") or "Windows GPU")
        records.append(_record(name, None, "windows-cim", confidence="low"))
    return records


def _linux_drm_records():
    records = []
    for path in Path("/sys/class/drm").glob("card[0-9]*/device/mem_info_vram_total"):
        try:
            budget = int(path.read_text(encoding="utf-8").strip()) / (1024 ** 3)
            name = (path.parent / "vendor").read_text(encoding="utf-8").strip()
        except (OSError, ValueError):
            continue
        vendor = {"0x1002": "AMD", "0x8086": "Intel"}.get(name.lower(), name)
        records.append(_record(f"{vendor} DRM GPU", budget, "linux-drm", confidence="high"))
    return records


def detect_accelerators():
    records = parse_nvidia_smi(_run([
        "nvidia-smi", "--query-gpu=name,memory.total", "--format=csv,noheader,nounits",
    ]))
    records += parse_rocm_smi(_run(["rocm-smi", "--showproductname", "--showmeminfo", "vram", "--json"]))
    records += parse_xpu_smi(_run(["xpu-smi", "discovery", "-j"]))
    records += parse_llama_devices(_run(["llama-server", "--list-devices"]))
    if sys.platform.startswith("linux"):
        records += _linux_drm_records()
    if os.name == "nt":
        command = "Get-CimInstance Win32_VideoController | Select Name,AdapterCompatibility | ConvertTo-Json -Compress"
        records += parse_windows_adapters(_run(["powershell.exe", "-NoProfile", "-Command", command]))
    return records


def normalize_hardware(ram_gb, os_name, arch, accelerators):
    if os_name == "darwin" and arch.lower() in {"arm64", "aarch64"}:
        selected = _record(
            "Apple Silicon", ram_gb, "system-memory", "unified", "high" if ram_gb is not None else "low",
        )
    else:
        measured = [item for item in accelerators if (item.get("budget_gb") or 0) > 0]
        selected = max(measured, key=lambda item: item["budget_gb"]) if measured else None
        if selected is None and accelerators:
            selected = accelerators[0]
        if selected is None:
            selected = _record("CPU", ram_gb, "system-memory", "system", "medium")

    budget = selected.get("budget_gb")
    confidence = selected["confidence"]
    if selected["kind"] == "shared" and budget is None:
        budget, confidence = 4.0, "low"
    if selected["kind"] == "dedicated" and budget is not None and ram_gb is not None:
        budget = min(budget, ram_gb)
    if selected["kind"] in {"unified", "system"}:
        budget = ram_gb

    qualcomm = selected["vendor"] == "qualcomm"
    return {
        "os": os_name,
        "arch": arch,
        "ram_gb": ram_gb,
        "vram_gb": selected.get("budget_gb") if selected["kind"] == "dedicated" else None,
        "memory_kind": "snapdragon-shared" if qualcomm else selected["kind"],
        "effective_budget_gb": budget,
        "probe_source": selected["source"],
        "gpu_vendor": selected["vendor"],
        "gpu_device": selected["device"],
        "confidence": confidence,
        "runtime_acceleration": "experimental-opencl" if qualcomm else "standard",
        "accelerators": accelerators,
    }


def detect_hardware():
    return normalize_hardware(detect_total_ram_gb(), sys.platform, platform.machine(), detect_accelerators())


def detect_vram_gb():
    return detect_hardware()["vram_gb"]


def effective_memory_gb(hardware):
    if "effective_budget_gb" in hardware:
        return hardware["effective_budget_gb"]
    ram = hardware.get("ram_gb")
    vram = hardware.get("vram_gb")
    return vram if vram is not None and (ram is None or vram < ram) else ram
