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

python3 - "$TMP" "$OUT_JSON" << 'PY'
import json, re, sys
from pathlib import Path
src = Path(sys.argv[1]).read_text(encoding="utf-8")
out_json = Path(sys.argv[2])
providers = [
    "nvidiaNim", "groq", "cerebras", "sambanova", "openrouter",
    "googleai", "zai", "siliconflow", "together", "cloudflare", "perplexity"
]
out = {}
for p in providers:
    m = re.search(rf"export const {re.escape(p)} = \\[(.*?)\\n\\]", src, re.S)
    if not m:
        continue
    body = m.group(1)
    rows = []
    for mm in re.finditer(r"\\['([^']+)'\\s*,\\s*'([^']+)'\\s*,\\s*'([^']+)'\\s*,\\s*'([^']+)'\\s*,\\s*'([^']+)'\\]", body):
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
lines = [
    "# Free Cloud Coding Models Snapshot",
    "",
    "Source: [vava-nessa/free-coding-models](https://github.com/vava-nessa/free-coding-models)",
    "",
    "Kudos to **@vava-nessa** for the free model index and NIM helper tooling.",
    "",
]
for provider, models in data.items():
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
