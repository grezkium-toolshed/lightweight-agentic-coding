"""Catalog management: sync free models from upstream sources."""

import json
import re
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

FREE_MODELS_SOURCE_URL = "https://raw.githubusercontent.com/vava-nessa/free-coding-models/main/sources.js"

UPSTREAM_PROVIDERS = [
    "nvidiaNim", "groq", "cerebras", "sambanova", "openrouter",
    "googleai", "zai", "siliconflow", "together", "cloudflare", "perplexity",
]


def _fetch_source_js(url=None):
    source_url = url or FREE_MODELS_SOURCE_URL
    req = urllib.request.Request(source_url)
    with urllib.request.urlopen(req, timeout=15) as resp:
        return resp.read().decode("utf-8")


def _parse_source_js(src):
    out = {}
    lines = src.splitlines()
    for p in UPSTREAM_PROVIDERS:
        start = next((i for i, line in enumerate(lines) if re.match(rf"\s*export const {re.escape(p)}\s*=\s*\[", line)), None)
        if start is None:
            continue
        body_lines = []
        for line in lines[start + 1:]:
            if line.strip() == "]":
                break
            body_lines.append(line)
        body = "\n".join(body_lines)
        rows = []
        for mm in re.finditer(r"\['([^']+)'\s*,\s*'([^']+)'\s*,\s*'([^']+)'\s*,\s*'([^']+)'\s*,\s*'([^']+)'\]", body):
            rows.append({
                "id": mm.group(1),
                "label": mm.group(2),
                "tier": mm.group(3),
                "swe": mm.group(4),
                "context": mm.group(5),
            })
        out[p] = rows
    return out


def _render_markdown(data):
    meta = data.get("_meta", {})
    snapshot_date = meta.get("snapshot_date", "unknown")
    lines = [
        "# Free Cloud Coding Models Snapshot",
        "",
        "Source: [vava-nessa/free-coding-models](https://github.com/vava-nessa/free-coding-models)",
        "",
        f"**Last verified:** {snapshot_date} (upstream sync; regenerate with `lac catalog sync-free`).",
        "",
        "Kudos to **@vava-nessa** for the free model index and NIM helper tooling.",
        "",
    ]
    for provider, models in data.items():
        if provider == "_meta":
            continue
        lines.append(f"## {provider}")
        lines.append("")
        if not models:
            lines.append("No models parsed from upstream source.")
            lines.append("")
            continue
        lines.append("| Model ID | Label | Tier | SWE | Context |")
        lines.append("|---|---|---|---|---|")
        for m in models[:40]:
            lines.append(f"| `{m['id']}` | {m['label']} | {m['tier']} | {m['swe']} | {m['context']} |")
        if len(models) > 40:
            lines.append(f"| ... | ... and {len(models)-40} more |  |  |  |")
        lines.append("")
    return "\n".join(lines) + "\n"


def sync_free(root=None, out_json=None, out_md=None, source_url=None):
    from lac.context import CATALOG_CACHE_ROOT, ROOT as DEFAULT_ROOT
    root_was_provided = root is not None
    if root is None:
        root = DEFAULT_ROOT
    output_root = Path(root) / "docs" if root_was_provided else CATALOG_CACHE_ROOT
    if out_json is None:
        out_json = output_root / "free-coding-models.json"
    if out_md is None:
        out_md = output_root / "FREE_CLOUD_MODELS.md"
    print(f"Fetching upstream source: {source_url or FREE_MODELS_SOURCE_URL}")
    src = _fetch_source_js(source_url)
    parsed = _parse_source_js(src)
    snapshot_date = datetime.now(timezone.utc).date().isoformat()
    data = {
        "_meta": {
            "snapshot_date": snapshot_date,
            "source_url": source_url or FREE_MODELS_SOURCE_URL,
            "verification_method": "upstream-sync",
            "live_probe_command": "lac provider verify --all",
        },
        **parsed,
    }
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    md_content = _render_markdown(data)
    out_md.parent.mkdir(parents=True, exist_ok=True)
    out_md.write_text(md_content, encoding="utf-8")
    total = sum(len(v) for k, v in data.items() if k != "_meta")
    print(f"Wrote: {out_json}")
    print(f"Wrote: {out_md}")
    print(f"Total models: {total} across {len(parsed)} providers")
    return 0
