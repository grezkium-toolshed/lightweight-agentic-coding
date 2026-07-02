#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT" "$@" <<'PY'
import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
argv = sys.argv[2:]

parser = argparse.ArgumentParser(
    description="Warn when provider/free-model freshness docs are older than the allowed age."
)
parser.add_argument("--max-age-days", type=int, default=14, help="maximum accepted age before warning (default: 14)")
parser.add_argument("--strict", action="store_true", help="exit non-zero when any freshness record is stale or missing")
parser.add_argument("--json", action="store_true", dest="json_mode", help="print machine-readable JSON")
parser.add_argument("--as-of", help="override today's UTC date as YYYY-MM-DD, for deterministic checks")
args = parser.parse_args(argv)

if args.max_age_days < 0:
    raise SystemExit("--max-age-days must be >= 0")

if args.as_of:
    try:
        today = dt.date.fromisoformat(args.as_of)
    except ValueError as exc:
        raise SystemExit(f"--as-of must be YYYY-MM-DD: {exc}") from exc
else:
    today = dt.datetime.now(dt.timezone.utc).date()


def rel(path: Path) -> str:
    return path.relative_to(root).as_posix()


def line_for(path: Path, needle: str) -> int:
    try:
        for index, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            if needle in line:
                return index
    except FileNotFoundError:
        return 1
    return 1


def parse_date(value):
    if not value:
        return None
    try:
        return dt.date.fromisoformat(value)
    except ValueError:
        return None


def markdown_last_verified(path):
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return None, 1
    match = re.search(r"\*\*Last verified:\*\*\s*(\d{4}-\d{2}-\d{2})", text)
    if not match:
        return None, 1
    return match.group(1), line_for(path, match.group(1))


def free_models_snapshot(path):
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None, 1
    value = payload.get("_meta", {}).get("snapshot_date")
    return value, line_for(path, "snapshot_date")


def catalog_provider(path, provider_id):
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None, 1
    for provider in payload.get("providers", []):
        if provider.get("id") == provider_id:
            value = provider.get("last_verified_at")
            return value, line_for(path, f'"id": "{provider_id}"')
    return None, 1


sources = [
    {
        "id": "openrouter-doc",
        "label": "OpenRouter free-tier doc",
        "path": root / "docs/providers/OPENROUTER_FREE.md",
        "date": markdown_last_verified(root / "docs/providers/OPENROUTER_FREE.md"),
        "refresh": "./bin/lac provider verify openrouter --refresh-catalog",
    },
    {
        "id": "free-cloud-models-doc",
        "label": "Free cloud models doc",
        "path": root / "docs/FREE_CLOUD_MODELS.md",
        "date": markdown_last_verified(root / "docs/FREE_CLOUD_MODELS.md"),
        "refresh": "lac catalog sync-free",
    },
    {
        "id": "free-coding-models-json",
        "label": "Free coding models snapshot JSON",
        "path": root / "docs/free-coding-models.json",
        "date": free_models_snapshot(root / "docs/free-coding-models.json"),
        "refresh": "lac catalog sync-free",
    },
    {
        "id": "openrouter-provider-catalog",
        "label": "OpenRouter provider catalog",
        "path": root / "catalog/providers.json",
        "date": catalog_provider(root / "catalog/providers.json", "openrouter"),
        "refresh": "./bin/lac provider verify openrouter --refresh-catalog",
    },
]

records = []
for source in sources:
    date_text, line = source["date"]
    parsed = parse_date(date_text)
    age_days = (today - parsed).days if parsed else None
    status = "ok"
    if parsed is None:
        status = "missing"
    elif age_days is not None and age_days > args.max_age_days:
        status = "stale"
    records.append({
        "id": source["id"],
        "label": source["label"],
        "path": rel(source["path"]),
        "line": line,
        "date": date_text,
        "age_days": age_days,
        "max_age_days": args.max_age_days,
        "status": status,
        "refresh": source["refresh"],
    })

stale_or_missing = [record for record in records if record["status"] != "ok"]
payload = {
    "ok": not stale_or_missing,
    "strict": args.strict,
    "as_of": today.isoformat(),
    "max_age_days": args.max_age_days,
    "records": records,
}

if args.json_mode:
    print(json.dumps(payload, indent=2))
else:
    print("Provider/free-model freshness age check")
    print(f"- As of: {today.isoformat()}")
    print(f"- Warning threshold: {args.max_age_days} days")
    for record in records:
        age = "unknown" if record["age_days"] is None else f"{record['age_days']} days"
        print(f"- {record['label']}: {record['status']} | {record['date'] or 'missing'} | age {age}")
        if record["status"] != "ok":
            message = (
                f"{record['label']} freshness is {record['status']}; "
                f"refresh with `{record['refresh']}` before closing provider-live-freshness."
            )
            print(f"::warning file={record['path']},line={record['line']}::{message}")

if stale_or_missing and args.strict:
    raise SystemExit(1)
PY
