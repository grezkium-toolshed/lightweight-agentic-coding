#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$ROOT/state/release-evidence/security-pvr-$STAMP"
REPO=""
SCREENSHOT_REF=""
CONFIRM_ENABLED=0
ALLOW_UNAVAILABLE=0

usage() {
  cat <<'EOF'
Usage: scripts/release-security-pvr.sh [options]

Capture GitHub Private Vulnerability Reporting evidence for the public-beta
release gate. This helper can collect repo/security-policy metadata, but it
does not prove PVR is enabled unless the repo owner passes --confirm-enabled
with a screenshot/reference from repository Settings > Advanced Security.

Options:
  --repo <owner/name>      GitHub repository (default: parsed from origin)
  --evidence-dir <dir>    Directory for summary and evidence files
  --confirm-enabled       Repo owner/admin confirms Private vulnerability
                          reporting is enabled in GitHub settings
  --screenshot <ref>      Screenshot or settings-reference proving PVR enabled
  --allow-unavailable     Allow local rehearsal to pass if gh/network/auth is
                          unavailable or PVR confirmation is missing
  -h, --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      [[ -n "$REPO" ]] || { echo "--repo requires a value" >&2; exit 2; }
      shift 2
      ;;
    --evidence-dir)
      EVIDENCE_DIR="${2:-}"
      [[ -n "$EVIDENCE_DIR" ]] || { echo "--evidence-dir requires a value" >&2; exit 2; }
      shift 2
      ;;
    --confirm-enabled)
      CONFIRM_ENABLED=1
      shift
      ;;
    --screenshot)
      SCREENSHOT_REF="${2:-}"
      [[ -n "$SCREENSHOT_REF" ]] || { echo "--screenshot requires a value" >&2; exit 2; }
      shift 2
      ;;
    --allow-unavailable)
      ALLOW_UNAVAILABLE=1
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

mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/commands.log"
SUMMARY="$EVIDENCE_DIR/summary.md"

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

run_allow_failure() {
  local output="$1"
  shift
  log_cmd "$@" >/dev/null
  set +e
  "$@" >"$output" 2>>"$LOG"
  local status=$?
  set -e
  echo "$status"
}

parse_repo_from_remote() {
  local remote
  remote="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
  remote="${remote%.git}"
  case "$remote" in
    https://github.com/*/*)
      printf '%s\n' "${remote#https://github.com/}"
      ;;
    git@github.com:*)
      printf '%s\n' "${remote#git@github.com:}"
      ;;
    *)
      return 1
      ;;
  esac
}

if [[ -z "$REPO" ]]; then
  REPO="$(parse_repo_from_remote || true)"
fi
if [[ -z "$REPO" ]]; then
  echo "Unable to determine GitHub repo. Pass --repo owner/name." >&2
  exit 2
fi

if [[ "$CONFIRM_ENABLED" -eq 1 && -z "$SCREENSHOT_REF" ]]; then
  echo "--confirm-enabled requires --screenshot <reference>." >&2
  exit 2
fi

echo "GitHub Private Vulnerability Reporting release evidence"
echo "- Evidence directory: $EVIDENCE_DIR"
echo "- Repository: $REPO"
if [[ "$CONFIRM_ENABLED" -eq 1 ]]; then
  echo "- Repo owner/admin confirmation: enabled"
else
  echo "- Repo owner/admin confirmation: missing"
fi

run_text date -u
run_text uname -a
run_text git -C "$ROOT" rev-parse HEAD
run_text git -C "$ROOT" remote -v

security_md_status=0
if [[ -f "$ROOT/SECURITY.md" ]]; then
  cp "$ROOT/SECURITY.md" "$EVIDENCE_DIR/SECURITY.md"
  if ! grep -q "Private Vulnerability Reporting" "$ROOT/SECURITY.md"; then
    security_md_status=1
  fi
  if ! grep -q "security/advisories" "$ROOT/SECURITY.md"; then
    security_md_status=1
  fi
else
  security_md_status=1
  echo "SECURITY.md is missing" >"$EVIDENCE_DIR/SECURITY.md.missing.txt"
fi

gh_status=127
repo_view_status=127
auth_status=127
if command -v gh >/dev/null 2>&1; then
  gh_status="$(run_allow_failure "$EVIDENCE_DIR/gh-version.txt" gh --version)"
  auth_status="$(run_allow_failure "$EVIDENCE_DIR/gh-auth-status.txt" env GH_PROMPT_DISABLED=1 gh auth status)"
  repo_view_status="$(run_allow_failure "$EVIDENCE_DIR/gh-repo-view.json" env GH_PROMPT_DISABLED=1 gh repo view "$REPO" --json nameWithOwner,url,visibility,isPrivate,isSecurityPolicyEnabled,securityPolicyUrl,viewerPermission,viewerCanAdminister,defaultBranchRef)"
else
  cat >"$EVIDENCE_DIR/gh-missing.txt" <<'EOF'
The GitHub CLI (`gh`) was not found on PATH.

Install GitHub CLI and authenticate with a repo owner/admin account, then rerun:

  ./scripts/release-security-pvr.sh --confirm-enabled --screenshot <reference>
EOF
fi

cat >"$EVIDENCE_DIR/github-settings-instructions.md" <<'EOF'
# GitHub Private Vulnerability Reporting Settings Check

Use a repo owner/admin account.

1. Open the repository on GitHub.
2. Go to Settings.
3. In the Security section, open Advanced Security.
4. Confirm "Private vulnerability reporting" is enabled.
5. Capture a screenshot/reference for the release evidence.
6. Rerun:

   ./scripts/release-security-pvr.sh --confirm-enabled --screenshot <reference>

GitHub Docs: https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting/configure-for-a-repository
EOF

if [[ -n "$SCREENSHOT_REF" ]]; then
  printf '%s\n' "$SCREENSHOT_REF" >"$EVIDENCE_DIR/screenshot-reference.txt"
else
  cat >"$EVIDENCE_DIR/screenshot-reference-missing.txt" <<'EOF'
No screenshot/reference was provided.

The security-pvr gate remains open until a repo owner/admin attaches a
repository Settings > Advanced Security screenshot/reference showing Private
vulnerability reporting enabled.
EOF
fi

python3 - "$EVIDENCE_DIR" "$REPO" "$security_md_status" "$gh_status" "$auth_status" "$repo_view_status" "$CONFIRM_ENABLED" "$ALLOW_UNAVAILABLE" <<'PY'
import json
import sys
from pathlib import Path

evidence_dir = Path(sys.argv[1])
repo = sys.argv[2]
security_md_status = int(sys.argv[3])
gh_status = int(sys.argv[4])
auth_status = int(sys.argv[5])
repo_view_status = int(sys.argv[6])
confirm_enabled = sys.argv[7] == "1"
allow_unavailable = sys.argv[8] == "1"


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return {"_parse_error": str(exc), "_path": path.name}


def first_line(path: Path, default: str = "missing") -> str:
    try:
        text = path.read_text(encoding="utf-8", errors="replace").strip()
    except FileNotFoundError:
        return default
    return text.splitlines()[0] if text else "empty"


repo_view = load_json(evidence_dir / "gh-repo-view.json")
security_policy_enabled = repo_view.get("isSecurityPolicyEnabled")
security_policy_url = repo_view.get("securityPolicyUrl") or "unknown"
viewer_permission = repo_view.get("viewerPermission") or "unknown"
viewer_admin = repo_view.get("viewerCanAdminister")
screenshot = first_line(evidence_dir / "screenshot-reference.txt", "")

metadata_ok = (
    security_md_status == 0
    and gh_status == 0
    and auth_status == 0
    and repo_view_status == 0
)
owner_admin_ok = viewer_admin is True
rehearsal_accepted = allow_unavailable and security_md_status == 0
release_ready = (
    metadata_ok
    and owner_admin_ok
    and confirm_enabled
    and bool(screenshot)
)

lines = [
    "# Security PVR Evidence Summary",
    "",
    "- Status: open",
    f"- Repository: {repo}",
    f"- gh version exit code: {gh_status}",
    f"- gh auth status exit code: {auth_status}",
    f"- gh repo view exit code: {repo_view_status}",
    f"- SECURITY.md wording check: {'ok' if security_md_status == 0 else 'needs review'}",
    f"- GitHub security policy enabled: {security_policy_enabled}",
    f"- GitHub security policy URL: {security_policy_url}",
    f"- Viewer permission: {viewer_permission}",
    f"- Viewer can administer: {viewer_admin}",
    f"- Viewer owner/admin evidence: {owner_admin_ok}",
    f"- Repo owner/admin PVR confirmation: {confirm_enabled}",
    f"- Settings screenshot/reference: {screenshot or 'missing'}",
    f"- Metadata evidence complete: {metadata_ok}",
    f"- Local rehearsal accepted: {rehearsal_accepted}",
    f"- PVR release evidence complete: {release_ready}",
    "",
    "## Files",
    "",
    "- commands.log",
    "- SECURITY.md",
    "- gh-version.txt or gh-missing.txt",
    "- gh-auth-status.txt",
    "- gh-repo-view.json",
    "- github-settings-instructions.md",
    "- screenshot-reference.txt or screenshot-reference-missing.txt",
    "",
]

if release_ready:
    lines.extend([
        "A repo owner/admin confirmed Private Vulnerability Reporting is enabled.",
        "Paste this evidence into `docs/release/MANUAL_VALIDATION.md` before",
        "closing the `security-pvr` gate.",
        "",
    ])
elif allow_unavailable:
    lines.extend([
        "This was a local rehearsal with `--allow-unavailable`. Keep the",
        "`security-pvr` gate open until a repo owner/admin reruns the helper",
        "with `--confirm-enabled --screenshot <reference>` after enabling PVR.",
        "",
    ])
else:
    lines.extend([
        "Security PVR release evidence is incomplete. Keep the manual",
        "`security-pvr` gate open and inspect the captured files above.",
        "",
    ])

(evidence_dir / "summary.md").write_text("\n".join(lines), encoding="utf-8")

if not release_ready and not allow_unavailable:
    raise SystemExit(1)
PY

echo
echo "Security PVR evidence captured."
echo "Evidence summary: $SUMMARY"
if [[ "$CONFIRM_ENABLED" -eq 0 ]]; then
  echo "Keep security-pvr open until a repo owner/admin confirms PVR is enabled."
fi
