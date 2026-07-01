#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAC="$ROOT/bin/lac"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$ROOT/state/release-evidence/opencode-discovery-$STAMP"
SKIP_OPEN=1
ALLOW_MISSING_OPENCODE=0

usage() {
  cat <<'EOF'
Usage: scripts/release-opencode-discovery.sh [options]

Capture OpenCode discovery preflight evidence for the public-beta release gate.
The manual gate remains open until a real OpenCode session confirms that the
generated config discovers repo/package agents and skills.

Options:
  --evidence-dir <dir>    Directory for summary and evidence files
  --open                  Launch OpenCode through `lac client open opencode`
                          after preflight evidence capture
  --skip-open             Do not launch OpenCode; useful for automated rehearsal
                          and the default behavior
  --allow-missing-opencode
                          Allow rehearsal to pass when the opencode binary is
                          not installed
  -h, --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --evidence-dir)
      EVIDENCE_DIR="${2:-}"
      [[ -n "$EVIDENCE_DIR" ]] || { echo "--evidence-dir requires a value" >&2; exit 2; }
      shift 2
      ;;
    --open)
      SKIP_OPEN=0
      shift
      ;;
    --skip-open)
      SKIP_OPEN=1
      shift
      ;;
    --allow-missing-opencode)
      ALLOW_MISSING_OPENCODE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -x "$LAC" ]]; then
  echo "Missing lac wrapper: $LAC" >&2
  exit 2
fi

mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/commands.log"
OPENCODE_VERSION="$EVIDENCE_DIR/opencode-version.txt"
OPENCODE_MISSING="$EVIDENCE_DIR/opencode-missing.txt"
RENDER_JSON="$EVIDENCE_DIR/render-opencode.json"
REPO_AGENTS="$EVIDENCE_DIR/repo-agents.txt"
REPO_SKILLS="$EVIDENCE_DIR/repo-skills.txt"
PACKAGE_AGENTS="$EVIDENCE_DIR/package-agents.txt"
PACKAGE_SKILLS="$EVIDENCE_DIR/package-skills.txt"
OPEN_SESSION="$EVIDENCE_DIR/open-session.txt"

log_cmd() {
  {
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  } | tee -a "$LOG"
}

run_text() {
  log_cmd "$@"
  "$@" 2>&1 | tee -a "$LOG"
}

run_text_allow_failure() {
  local output="$1"
  shift
  log_cmd "$@" >/dev/null
  set +e
  "$@" >"$output" 2>>"$LOG"
  local status=$?
  set -e
  echo "$status"
}

find_assets() {
  local base="$1"
  local pattern="$2"
  local output="$3"

  if [[ -d "$base" ]]; then
    find "$base" -name "$pattern" | sort >"$output"
  else
    : >"$output"
  fi
}

echo "OpenCode discovery release evidence"
echo "- Evidence directory: $EVIDENCE_DIR"
if [[ "$SKIP_OPEN" -eq 1 ]]; then
  echo "- OpenCode launch: skipped"
else
  echo "- OpenCode launch: enabled"
fi

run_text date -u
run_text uname -a
run_text "$LAC" --version
run_text git -C "$ROOT" rev-parse HEAD

if command -v opencode >/dev/null 2>&1; then
  opencode_status="$(run_text_allow_failure "$OPENCODE_VERSION" opencode --version)"
else
  opencode_status=127
  cat >"$OPENCODE_MISSING" <<'EOF'
The opencode binary was not found on PATH.

Install OpenCode, then rerun:

  ./scripts/release-opencode-discovery.sh --open
EOF
  if [[ "$ALLOW_MISSING_OPENCODE" -eq 0 ]]; then
    cat "$OPENCODE_MISSING" >&2
    exit 127
  fi
fi

render_status="$(run_text_allow_failure "$RENDER_JSON" "$LAC" client render opencode --json)"
find_assets "$ROOT/.opencode/agents" "*.md" "$REPO_AGENTS"
find_assets "$ROOT/.opencode/skills" "SKILL.md" "$REPO_SKILLS"
find_assets "$ROOT/src/lac/data/opencode/agents" "*.md" "$PACKAGE_AGENTS"
find_assets "$ROOT/src/lac/data/opencode/skills" "SKILL.md" "$PACKAGE_SKILLS"

open_status=0
if [[ "$SKIP_OPEN" -eq 1 ]]; then
  cat >"$OPEN_SESSION" <<'EOF'
OpenCode launch was skipped for automated rehearsal.

For release evidence, rerun:

  ./scripts/release-opencode-discovery.sh --open

Then confirm in a real OpenCode session that generated agents and skills are
discoverable, and attach a screenshot reference or transcript summary.
EOF
else
  cat >"$OPEN_SESSION" <<'EOF'
OpenCode was launched through `lac client open opencode`.

After launch, confirm the generated config discovers:
- .opencode/agents/*.md
- .opencode/skills/*/SKILL.md

Attach a screenshot reference or transcript summary before closing the
opencode-discovery manual gate.
EOF
  open_status="$(run_text_allow_failure "$OPEN_SESSION.run.log" "$LAC" client open opencode)"
fi

python3 - "$EVIDENCE_DIR" "$opencode_status" "$render_status" "$open_status" "$SKIP_OPEN" "$ALLOW_MISSING_OPENCODE" <<'PY'
import json
import sys
from pathlib import Path

evidence_dir = Path(sys.argv[1])
opencode_status = int(sys.argv[2])
render_status = int(sys.argv[3])
open_status = int(sys.argv[4])
skip_open = sys.argv[5] == "1"
allow_missing_opencode = sys.argv[6] == "1"


def line_count(path: Path) -> int:
    try:
        return len([line for line in path.read_text(encoding="utf-8").splitlines() if line.strip()])
    except FileNotFoundError:
        return 0


def read_first(path: Path) -> str:
    try:
        text = path.read_text(encoding="utf-8", errors="replace").strip()
    except FileNotFoundError:
        return "missing"
    return text.splitlines()[0] if text else "empty"


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return {"_parse_error": str(exc), "_path": path.name}


render = load_json(evidence_dir / "render-opencode.json")
runtime_asset_root = render.get("runtime_asset_root", "unknown")
manifest_path = render.get("manifest_path", "unknown")
pack_count = render.get("pack_count", "unknown")
assets = []
for pack in render.get("packs", []) if isinstance(render.get("packs"), list) else []:
    assets.extend(pack.get("assets", []))

installed_assets = [asset for asset in assets if asset.get("installed")]
render_agent_count = len({asset.get("path") for asset in installed_assets if asset.get("type") == "agent"})
render_skill_count = len({asset.get("path") for asset in installed_assets if asset.get("type") == "skill"})
repo_agent_count = line_count(evidence_dir / "repo-agents.txt")
repo_skill_count = line_count(evidence_dir / "repo-skills.txt")
package_agent_count = line_count(evidence_dir / "package-agents.txt")
package_skill_count = line_count(evidence_dir / "package-skills.txt")
opencode_version = read_first(evidence_dir / "opencode-version.txt")
opencode_missing_allowed = opencode_status == 127 and allow_missing_opencode

preflight_ok = (
    render_status == 0
    and repo_agent_count > 0
    and repo_skill_count > 0
    and package_agent_count == repo_agent_count
    and package_skill_count == repo_skill_count
    and (opencode_status == 0 or opencode_missing_allowed)
    and (skip_open or open_status == 0)
)

lines = [
    "# OpenCode Discovery Evidence Summary",
    "",
    "- Status: open",
    f"- OpenCode version/status: {opencode_version} (exit {opencode_status})",
    f"- lac client render exit code: {render_status}",
    f"- lac client open exit code: {open_status if not skip_open else 'skipped'}",
    f"- Rendered manifest path: {manifest_path}",
    f"- Runtime asset root: {runtime_asset_root}",
    f"- Rendered pack count: {pack_count}",
    f"- Rendered installed agents: {render_agent_count}",
    f"- Rendered installed skills: {render_skill_count}",
    f"- Repo agents: {repo_agent_count}",
    f"- Repo skills: {repo_skill_count}",
    f"- Package agents: {package_agent_count}",
    f"- Package skills: {package_skill_count}",
    f"- Preflight evidence complete: {preflight_ok}",
    "",
    "## Files",
    "",
    "- commands.log",
    "- opencode-version.txt or opencode-missing.txt",
    "- render-opencode.json",
    "- repo-agents.txt",
    "- repo-skills.txt",
    "- package-agents.txt",
    "- package-skills.txt",
    "- open-session.txt",
    "",
]

if skip_open:
    lines.extend([
        "This was an automated rehearsal with `--skip-open`; the manual",
        "`opencode-discovery` gate remains open until a release tester reruns",
        "the helper with `--open` and attaches a screenshot reference or",
        "transcript summary from a real OpenCode session.",
        "",
    ])
else:
    lines.extend([
        "OpenCode launch was requested. Keep `opencode-discovery` open until",
        "the tester records a screenshot reference or transcript summary showing",
        "that the real OpenCode session discovers generated agents and skills.",
        "",
    ])

if opencode_status == 127:
    lines.extend([
        "OpenCode was not found on PATH. This is acceptable only for local",
        "automated rehearsal with `--allow-missing-opencode`; it is not release",
        "evidence for the manual gate.",
        "",
    ])

(evidence_dir / "summary.md").write_text("\n".join(lines), encoding="utf-8")

if not preflight_ok:
    raise SystemExit(1)
PY

echo
echo "OpenCode discovery evidence captured."
echo "Evidence summary: $EVIDENCE_DIR/summary.md"
echo "Keep opencode-discovery open until real OpenCode session discovery is documented."
