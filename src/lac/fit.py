"""lac context: fit and KV-cache math for local models.

Answers, for each local model in a profile: how much context each KV cache
type (f16 / q8_0 / q4_0) buys inside the measured memory budget, and a
memory-bandwidth-based decode estimate. Model geometry (layers, KV heads,
head dim, hybrid full/linear attention split) is read from the GGUF header
metadata; the preset stays the source of truth and this command is advisory.
"""

import configparser
import struct
import subprocess
import sys
from pathlib import Path

BYTES_PER_VALUE = {"f32": 4.0, "f16": 2.0, "q8_0": 1.0, "q4_0": 0.5}
CACHE_TYPES = ("f16", "q8_0", "q4_0")
COMPUTE_OVERHEAD_GIB = 2.0
MACOS_HEADROOM_GIB = 8.0
MAX_GGUF_META_BYTES = 16 * 1024 * 1024

# Apple Silicon unified-memory bandwidth (GB/s), keyed by marketing chip name.
BANDWIDTH_GBS = {
    "M1 Ultra": 800, "M1 Max": 400, "M1 Pro": 200, "M1": 68.25,
    "M2 Ultra": 800, "M2 Max": 400, "M2 Pro": 200, "M2": 100,
    "M3 Ultra": 800, "M3 Max": 400, "M3 Pro": 150, "M3": 100,
    "M4 Max": 546, "M4 Pro": 273, "M4": 120,
}


def _u32(buf, offset):
    return struct.unpack_from("<I", buf, offset)[0]


def _u64(buf, offset):
    return struct.unpack_from("<Q", buf, offset)[0]


def _read_string(buf, offset):
    length = _u64(buf, offset)
    offset += 8
    value = buf[offset:offset + length].decode("utf-8", "replace")
    return value, offset + length


def _read_value(buf, offset, vtype):
    if vtype == 8:
        return _read_string(buf, offset)
    if vtype == 9:
        elem_type = _u32(buf, offset)
        count = _u64(buf, offset + 4)
        offset += 12
        values = []
        for _ in range(count):
            value, offset = _read_value(buf, offset, elem_type)
            values.append(value)
        return values, offset
    if vtype in (0, 1, 7):
        return buf[offset], offset + 1
    if vtype in (2, 3):
        return struct.unpack_from("<H" if vtype == 2 else "<h", buf, offset)[0], offset + 2
    if vtype in (4, 5):
        return struct.unpack_from("<I" if vtype == 4 else "<i", buf, offset)[0], offset + 4
    if vtype == 6:
        return struct.unpack_from("<f", buf, offset)[0], offset + 4
    if vtype in (10, 11):
        return struct.unpack_from("<Q" if vtype == 10 else "<q", buf, offset)[0], offset + 8
    if vtype == 12:
        return struct.unpack_from("<d", buf, offset)[0], offset + 8
    raise ValueError(f"unsupported GGUF value type {vtype}")


def read_gguf_meta(path):
    """Read the metadata KV pairs from a GGUF header; None if not a GGUF."""
    try:
        with open(path, "rb") as handle:
            head = handle.read(24)
        if len(head) < 24 or head[:4] != b"GGUF":
            return None
        kv_count = _u64(head, 16)
        with open(path, "rb") as handle:
            handle.seek(24)
            buf = handle.read(MAX_GGUF_META_BYTES)
        offset = 0
        meta = {}
        for _ in range(kv_count):
            key, offset = _read_string(buf, offset)
            vtype = _u32(buf, offset)
            value, offset = _read_value(buf, offset + 4, vtype)
            meta[key] = value
        return meta
    except Exception:
        return None


def _find(meta, *suffixes):
    for key, value in meta.items():
        for suffix in suffixes:
            if key.endswith(suffix):
                return value
    return None


def model_geometry(meta):
    """Extract layers, KV heads, head dim, and full-attention layer count.

    Architecture-agnostic: GGUF metadata keys carry arch-specific prefixes
    (llama.*, qwen35.*, ...), so keys are matched by suffix. Hybrid models
    expose either per-layer attention.layer_types or full_attention_interval.
    """
    if not meta:
        return None
    layers = _find(meta, ".block_count")
    kv_heads = _find(meta, ".attention.head_count_kv")
    if layers is None or kv_heads is None:
        return None
    head_dim = _find(
        meta, ".attention.head_dim", ".attention.key_length", ".attention.value_length"
    )
    if head_dim is None:
        heads = _find(meta, ".attention.head_count")
        hidden = _find(meta, ".embedding_length")
        if not heads or not hidden:
            return None
        head_dim = hidden // heads
    full_layers = layers
    layer_types = _find(meta, ".attention.layer_types")
    if isinstance(layer_types, list):
        counted = sum(1 for t in layer_types if "full" in str(t).lower())
        if counted > 0:
            full_layers = counted
    else:
        interval = _find(meta, ".full_attention_interval")
        if isinstance(interval, int) and interval > 1:
            full_layers = (layers + interval - 1) // interval
    return {
        "layers": layers,
        "kv_heads": kv_heads,
        "head_dim": head_dim,
        "full_layers": full_layers,
        "context_length": _find(meta, ".context_length"),
    }


def kv_bytes_per_token(geometry, cache_type):
    """Bytes of KV cache per context token (K + V, full-attention layers only)."""
    if not geometry:
        return None
    bytes_per_value = BYTES_PER_VALUE.get(cache_type)
    if bytes_per_value is None:
        return None
    return geometry["full_layers"] * geometry["kv_heads"] * geometry["head_dim"] * 2 * bytes_per_value


def chip_bandwidth_gbs():
    """Return (chip name, GB/s) from macOS sysctl; None elsewhere or unknown."""
    if sys.platform != "darwin":
        return None
    try:
        brand = subprocess.run(
            ["sysctl", "-n", "machdep.cpu.brand_string"],
            capture_output=True, text=True, timeout=5,
        ).stdout.strip()
    except Exception:
        return None
    lowered = brand.lower()
    for name, gbs in BANDWIDTH_GBS.items():
        if name.lower() in lowered:
            return name, gbs
    return None


def _gib(bytes_value):
    return bytes_value / (2 ** 30)


def _fmt_gib(value):
    return f"{_gib(value):.1f} GiB"


def _fmt_bytes(value):
    if value >= 2 ** 20:
        return f"{value / 2 ** 20:.1f} MiB"
    if value >= 2 ** 10:
        return f"{value / 2 ** 10:.1f} KiB"
    return f"{value} B"


def build_report(ctx, profile_id=None, headroom_gib=None, effective_gib=None):
    """Compute per-model context/KV math for a profile."""
    from lac.hardware import detect_hardware, effective_memory_gb

    profile_id = profile_id or ctx.active_profile_id()
    if not profile_id:
        raise SystemExit("No active profile. Run `lac profile apply <profile>` or pass --profile.")
    profile = ctx.get_profile(profile_id)
    preset_path = Path(profile["preset"])
    if not preset_path.is_absolute():
        preset_path = ctx.root / preset_path
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.read_string("[global]\n" + preset_path.read_text(encoding="utf-8"))

    if effective_gib is None:
        hardware = detect_hardware()
        effective_gib = effective_memory_gb(hardware)
    if headroom_gib is None:
        headroom_gib = MACOS_HEADROOM_GIB if sys.platform == "darwin" else 0.0
    budget_gib = (effective_gib - headroom_gib) if effective_gib is not None else None
    bandwidth = chip_bandwidth_gbs()

    models = []
    for model_id in parser.sections():
        if model_id in {"global", "*"} or not parser.has_option(model_id, "model"):
            continue
        raw = parser.get(model_id, "model")
        gguf_path = Path(raw.replace("__MODELS_DIR__", str(ctx.models_root)))
        meta = read_gguf_meta(gguf_path) if gguf_path.is_file() else None
        geometry = model_geometry(meta)
        entry = {"id": model_id, "present": gguf_path.is_file()}
        if geometry is None:
            entry["note"] = "GGUF metadata unavailable" if not entry["present"] else "GGUF geometry unknown (missing keys)"
            models.append(entry)
            continue
        weight_bytes = gguf_path.stat().st_size
        kv_rows = []
        for cache_type in CACHE_TYPES:
            per_token = kv_bytes_per_token(geometry, cache_type)
            kv_at_preset = None
            max_ctx = None
            if parser.has_option(model_id, "ctx-size"):
                kv_at_preset = per_token * parser.getint(model_id, "ctx-size")
            if budget_gib is not None:
                kv_budget = (budget_gib - _gib(weight_bytes) - COMPUTE_OVERHEAD_GIB) * 2 ** 30
                if kv_budget > 0 and per_token:
                    max_ctx = int(kv_budget // per_token)
                    if geometry.get("context_length"):
                        max_ctx = min(max_ctx, geometry["context_length"])
            kv_rows.append({
                "cache_type": cache_type,
                "per_token_bytes": per_token,
                "kv_at_preset_bytes": kv_at_preset,
                "max_ctx": max_ctx,
            })
        decode_toks = None
        if bandwidth:
            decode_toks = bandwidth[1] * 2 ** 30 / weight_bytes
        entry.update({
            "geometry": geometry,
            "weight_bytes": weight_bytes,
            "kv_rows": kv_rows,
            "preset_cache_type": parser.get(model_id, "cache-type-k")
            if parser.has_option(model_id, "cache-type-k") else None,
            "decode_toks_per_sec": decode_toks,
        })
        models.append(entry)

    return {
        "profile_id": profile_id,
        "chip": bandwidth[0] if bandwidth else None,
        "bandwidth_gbs": bandwidth[1] if bandwidth else None,
        "effective_memory_gib": effective_gib,
        "headroom_gib": headroom_gib,
        "budget_gib": budget_gib,
        "models": models,
    }


def _fit_label(max_ctx):
    if max_ctx is None:
        return "unfit"
    return str(max_ctx)


def render_report(report):
    lines = [f"Profile: {report['profile_id']}"]
    if report.get("chip"):
        lines.append(f"Device: {report['chip']} — ~{report['bandwidth_gbs']:.0f} GB/s memory bandwidth")
    if report.get("effective_memory_gib") is not None:
        headroom = report.get("headroom_gib") or 0.0
        lines.append(
            f"Memory budget: {report['budget_gib']:.1f} GiB "
            f"({report['effective_memory_gib']:.1f} GiB effective"
            + (f" − {headroom:.0f} GiB macOS headroom" if headroom else "")
            + f" − {COMPUTE_OVERHEAD_GIB:.0f} GiB compute overhead)"
        )
    for entry in report["models"]:
        lines.append("")
        lines.append(f"{entry['id']}  {'file missing' if not entry['present'] else ''}".rstrip())
        if entry.get("note"):
            lines.append(f"  {entry['note']}")
            continue
        geo = entry["geometry"]
        lines.append(
            f"  weights {_fmt_gib(entry['weight_bytes'])} | "
            f"{geo['layers']} layers, {geo['kv_heads']} KV heads × {geo['head_dim']} dim | "
            f"{geo['full_layers']} full-attention layers (hybrid)"
        )
        if entry.get("decode_toks_per_sec"):
            lines.append(
                f"  decode estimate ~{entry['decode_toks_per_sec']:.0f} t/s "
                f"(bandwidth ÷ weights)"
            )
        lines.append("  cache | KV/token | max ctx in budget | KV at preset ctx")
        for row in entry["kv_rows"]:
            kv_at_preset = _fmt_bytes(row["kv_at_preset_bytes"]) if row["kv_at_preset_bytes"] is not None else "-"
            lines.append(
                f"  {row['cache_type']:<5} | {_fmt_bytes(row['per_token_bytes']):<9} | "
                f"{_fit_label(row['max_ctx']):<18} | {kv_at_preset}"
            )
        preset_cache = entry.get("preset_cache_type")
        if preset_cache:
            lines.append(
                f"  preset: cache-type {preset_cache} (q8_0 halves f16 KV; q4_0 halves q8_0)"
            )
    return "\n".join(lines)


def context_cmd(ctx, profile_id=None, json_output=False):
    import json

    report = build_report(ctx, profile_id=profile_id)
    if json_output:
        print(json.dumps(report, indent=2))
    else:
        print(render_report(report))
    return 0


if __name__ == "__main__":
    # Self-check: synthetic GGUF header with hybrid layer types + KV math.
    import tempfile

    synthetic = bytearray(b"GGUF")
    synthetic += struct.pack("<I", 3)
    synthetic += struct.pack("<Q", 1)  # tensor count
    synthetic += struct.pack("<Q", 5)  # metadata KV count

    def _push_string(value):
        encoded = value.encode("utf-8")
        synthetic.extend(struct.pack("<Q", len(encoded)))
        synthetic.extend(encoded)

    def _push_uint32(value):
        synthetic.extend(struct.pack("<I", 4))
        synthetic.extend(struct.pack("<I", value))

    _push_string("llama.block_count")
    _push_uint32(64)
    _push_string("llama.attention.head_count_kv")
    _push_uint32(4)
    _push_string("llama.attention.head_dim")
    _push_uint32(256)
    _push_string("llama.context_length")
    _push_uint32(262144)
    _push_string("llama.attention.layer_types")
    synthetic.extend(struct.pack("<I", 9))  # array
    synthetic.extend(struct.pack("<I", 8))  # element type: string
    synthetic.extend(struct.pack("<Q", 64))
    for i in range(64):
        _push_string("full" if i % 4 == 0 else "linear")

    with tempfile.NamedTemporaryFile(suffix=".gguf", delete=False) as handle:
        handle.write(synthetic)
        temp_path = handle.name
    meta = read_gguf_meta(temp_path)
    assert meta and meta["llama.block_count"] == 64
    geo = model_geometry(meta)
    assert geo["full_layers"] == 16, geo
    assert kv_bytes_per_token(geo, "f16") == 16 * 4 * 256 * 2 * 2
    assert kv_bytes_per_token(geo, "q8_0") == 16 * 4 * 256 * 2
    assert kv_bytes_per_token(geo, "q4_0") == 16 * 4 * 256
    assert geo["context_length"] == 262144

    # Arch-specific prefix + full_attention_interval path (qwen35 style).
    synthetic2 = bytearray(b"GGUF")
    synthetic2 += struct.pack("<I", 3)
    synthetic2 += struct.pack("<Q", 1)
    synthetic2 += struct.pack("<Q", 4)

    def _push2_string(value):
        encoded = value.encode("utf-8")
        synthetic2.extend(struct.pack("<Q", len(encoded)))
        synthetic2.extend(encoded)

    def _push2_uint32(value):
        synthetic2.extend(struct.pack("<I", 4))
        synthetic2.extend(struct.pack("<I", value))

    _push2_string("qwen35.block_count")
    _push2_uint32(32)
    _push2_string("qwen35.attention.head_count_kv")
    _push2_uint32(4)
    _push2_string("qwen35.attention.key_length")
    _push2_uint32(256)
    _push2_string("qwen35.full_attention_interval")
    _push2_uint32(4)

    with tempfile.NamedTemporaryFile(suffix=".gguf", delete=False) as handle:
        handle.write(synthetic2)
        temp_path2 = handle.name
    geo2 = model_geometry(read_gguf_meta(temp_path2))
    assert geo2["full_layers"] == 8, geo2
    assert kv_bytes_per_token(geo2, "q8_0") == 8 * 4 * 256 * 2
    print("fit self-check ok: GGUF parse + hybrid KV math (layer_types and interval)")
