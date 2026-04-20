#!/bin/bash
set -euo pipefail

ROOT="${AI_CLUSTER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUT_JSON="$ROOT/docs/free-coding-models.json"
OUT_MD="$ROOT/docs/FREE_CLOUD_MODELS.md"
URL="https://raw.githubusercontent.com/vava-nessa/free-coding-models/main/sources.js"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! curl -fsSL "$URL" -o "$TMP"; then
  echo "Failed to fetch source list from: $URL" >&2
  exit 1
fi

SNAPSHOT_DATE="$(date -u +%Y-%m-%d)"
python3 - "$TMP" "$OUT_JSON" "$URL" "$SNAPSHOT_DATE" << 'PY'
import json, re, sys
from pathlib import Path
src = Path(sys.argv[1]).read_text(encoding="utf-8")
out_json = Path(sys.argv[2])
source_url = sys.argv[3]
snapshot_date = sys.argv[4]
providers = [
    "nvidiaNim", "groq", "cerebras", "sambanova", "openrouter",
    "googleai", "zai", "siliconflow", "together", "cloudflare", "perplexity"
]
out = {
    "_meta": {
        "snapshot_date": snapshot_date,
        "source_url": source_url,
        "verification_method": "upstream-sync",
        "live_probe_command": "./bin/lac provider verify --all",
    }
}
lines = src.splitlines()
for p in providers:
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
out_json.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
PY

python3 - "$OUT_JSON" "$OUT_MD" << 'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
out_md = Path(sys.argv[2])
data = json.loads(p.read_text(encoding="utf-8"))
meta = data.get("_meta", {})
snapshot_date = meta.get("snapshot_date", "unknown")
lines = [
    "# Free Cloud Coding Models Snapshot",
    "",
    "Source: [vava-nessa/free-coding-models](https://github.com/vava-nessa/free-coding-models)",
    "",
    f"**Last verified:** {snapshot_date} (upstream sync; regenerate with `./scripts/sync-free-cloud-models.sh` or `.ps1`).",
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
out_md.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

echo "Wrote: $OUT_JSON"
echo "Wrote: $OUT_MD"
