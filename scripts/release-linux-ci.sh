#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$ROOT/state/release-evidence/linux-ci-$STAMP"
REPO=""
WORKFLOW="ci.yml"
RUN_ID=""
BRANCH=""
LIMIT="10"
ALLOW_UNAVAILABLE=0

usage() {
  cat <<'EOF'
Usage: scripts/release-linux-ci.sh [options]

Capture Linux GitHub Actions CI evidence for the public-beta release gate.
Release mode expects GitHub CLI access to a completed successful CI run for
the current commit. Local rehearsal may use --allow-unavailable.

Options:
  --repo <owner/name>      GitHub repository (default: parsed from origin)
  --workflow <file/name>   Workflow selector (default: ci.yml)
  --run-id <id>            Specific GitHub Actions run to verify
  --branch <name>          Branch for gh run list (default: current branch)
  --limit <count>          Number of runs to inspect when --run-id is omitted
  --evidence-dir <dir>     Directory for summary and evidence files
  --allow-unavailable     Allow local rehearsal to pass if gh/network/auth or
                          CI evidence is unavailable
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
    --workflow)
      WORKFLOW="${2:-}"
      [[ -n "$WORKFLOW" ]] || { echo "--workflow requires a value" >&2; exit 2; }
      shift 2
      ;;
    --run-id)
      RUN_ID="${2:-}"
      [[ -n "$RUN_ID" ]] || { echo "--run-id requires a value" >&2; exit 2; }
      shift 2
      ;;
    --branch)
      BRANCH="${2:-}"
      [[ -n "$BRANCH" ]] || { echo "--branch requires a value" >&2; exit 2; }
      shift 2
      ;;
    --limit)
      LIMIT="${2:-}"
      [[ -n "$LIMIT" ]] || { echo "--limit requires a value" >&2; exit 2; }
      shift 2
      ;;
    --evidence-dir)
      EVIDENCE_DIR="${2:-}"
      [[ -n "$EVIDENCE_DIR" ]] || { echo "--evidence-dir requires a value" >&2; exit 2; }
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
HEAD_SHA="$(git -C "$ROOT" rev-parse HEAD)"

if [[ -z "$BRANCH" ]]; then
  BRANCH="$(git -C "$ROOT" branch --show-current 2>/dev/null || true)"
fi

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

echo "Linux CI release evidence"
echo "- Evidence directory: $EVIDENCE_DIR"
echo "- Repository: $REPO"
echo "- Workflow: $WORKFLOW"
echo "- Commit: $HEAD_SHA"
if [[ -n "$RUN_ID" ]]; then
  echo "- Run ID: $RUN_ID"
else
  echo "- Run ID: auto-detect from recent workflow runs"
fi
if [[ "$ALLOW_UNAVAILABLE" -eq 1 ]]; then
  echo "- Mode: local rehearsal; unavailable GitHub evidence is allowed"
else
  echo "- Mode: release evidence; current commit must have green Linux CI"
fi

run_text date -u
run_text uname -a
run_text git -C "$ROOT" rev-parse HEAD
run_text git -C "$ROOT" branch --show-current
run_text git -C "$ROOT" remote -v

workflow_status=0
if [[ -f "$ROOT/.github/workflows/ci.yml" ]]; then
  cp "$ROOT/.github/workflows/ci.yml" "$EVIDENCE_DIR/ci.yml"
  if ! grep -q "ubuntu-latest" "$ROOT/.github/workflows/ci.yml"; then
    workflow_status=1
  fi
  if ! grep -q "./scripts/integration-test.sh" "$ROOT/.github/workflows/ci.yml"; then
    workflow_status=1
  fi
  if ! grep -q "./scripts/verify-package-build.sh" "$ROOT/.github/workflows/ci.yml"; then
    workflow_status=1
  fi
  if ! grep -q "./verify-documentation.sh" "$ROOT/.github/workflows/ci.yml"; then
    workflow_status=1
  fi
  if ! grep -q "./scripts/verify-config-schema.sh" "$ROOT/.github/workflows/ci.yml"; then
    workflow_status=1
  fi
else
  workflow_status=1
  echo ".github/workflows/ci.yml is missing" >"$EVIDENCE_DIR/ci.yml.missing.txt"
fi

gh_status=127
auth_status=127
run_list_status=127
run_view_status=127
failed_log_status=127
if command -v gh >/dev/null 2>&1; then
  gh_status="$(run_allow_failure "$EVIDENCE_DIR/gh-version.txt" gh --version)"
  auth_status="$(run_allow_failure "$EVIDENCE_DIR/gh-auth-status.txt" env GH_PROMPT_DISABLED=1 gh auth status)"
  if [[ -n "$RUN_ID" ]]; then
    run_view_status="$(run_allow_failure "$EVIDENCE_DIR/gh-run-view.json" env GH_PROMPT_DISABLED=1 gh run view "$RUN_ID" --repo "$REPO" --json databaseId,displayTitle,event,headBranch,headSha,status,conclusion,url,workflowName,createdAt,updatedAt,jobs)"
    failed_log_status="$(run_allow_failure "$EVIDENCE_DIR/gh-run-failed.log" env GH_PROMPT_DISABLED=1 gh run view "$RUN_ID" --repo "$REPO" --log-failed)"
  else
    run_list_args=(env GH_PROMPT_DISABLED=1 gh run list --repo "$REPO" --workflow "$WORKFLOW" --limit "$LIMIT" --json databaseId,displayTitle,event,headBranch,headSha,status,conclusion,url,workflowName,createdAt,updatedAt)
    if [[ -n "$BRANCH" ]]; then
      run_list_args+=(--branch "$BRANCH")
    fi
    run_list_status="$(run_allow_failure "$EVIDENCE_DIR/gh-run-list.json" "${run_list_args[@]}")"
  fi
else
  cat >"$EVIDENCE_DIR/gh-missing.txt" <<'EOF'
The GitHub CLI (`gh`) was not found on PATH.

Install GitHub CLI, authenticate, and rerun after the release branch CI run
finishes:

  ./scripts/release-linux-ci.sh --run-id <run-id>
EOF
fi

python3 - "$EVIDENCE_DIR" "$REPO" "$WORKFLOW" "$HEAD_SHA" "$BRANCH" "$RUN_ID" "$workflow_status" "$gh_status" "$auth_status" "$run_list_status" "$run_view_status" "$failed_log_status" "$ALLOW_UNAVAILABLE" <<'PY'
import json
import sys
from pathlib import Path

evidence_dir = Path(sys.argv[1])
repo = sys.argv[2]
workflow = sys.argv[3]
head_sha = sys.argv[4]
branch = sys.argv[5] or "unknown"
run_id = sys.argv[6]
workflow_status = int(sys.argv[7])
gh_status = int(sys.argv[8])
auth_status = int(sys.argv[9])
run_list_status = int(sys.argv[10])
run_view_status = int(sys.argv[11])
failed_log_status = int(sys.argv[12])
allow_unavailable = sys.argv[13] == "1"


def load_json(path: Path, fallback):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return {"_parse_error": str(exc), "_path": path.name, "_fallback": fallback}


def select_run():
    if run_id:
        payload = load_json(evidence_dir / "gh-run-view.json", {})
        return payload if isinstance(payload, dict) else {}
    payload = load_json(evidence_dir / "gh-run-list.json", [])
    if isinstance(payload, list):
        for run in payload:
            if run.get("headSha") == head_sha:
                return run
        return payload[0] if payload else {}
    return payload


run = select_run()
run_head_sha = run.get("headSha") or "unknown"
run_status = run.get("status") or "unknown"
run_conclusion = run.get("conclusion") or "unknown"
run_url = run.get("url") or "unknown"
run_workflow = run.get("workflowName") or "unknown"
run_database_id = run.get("databaseId") or run_id or "unknown"
run_branch = run.get("headBranch") or "unknown"

metadata_ok = (
    workflow_status == 0
    and gh_status == 0
    and auth_status == 0
    and (run_view_status == 0 if run_id else run_list_status == 0)
)
commit_matches = run_head_sha == head_sha
green = run_status == "completed" and run_conclusion == "success"
release_ready = metadata_ok and commit_matches and green
rehearsal_accepted = allow_unavailable and workflow_status == 0

lines = [
    "# Linux CI Evidence Summary",
    "",
    "- Status: open",
    f"- Repository: {repo}",
    f"- Workflow selector: {workflow}",
    f"- Local commit SHA: {head_sha}",
    f"- Local branch: {branch}",
    f"- Workflow file check: {'ok' if workflow_status == 0 else 'needs review'}",
    f"- gh version exit code: {gh_status}",
    f"- gh auth status exit code: {auth_status}",
    f"- gh run list exit code: {run_list_status}",
    f"- gh run view exit code: {run_view_status}",
    f"- gh failed-log exit code: {failed_log_status}",
    f"- Selected run ID: {run_database_id}",
    f"- Selected run workflow: {run_workflow}",
    f"- Selected run branch: {run_branch}",
    f"- Selected run URL: {run_url}",
    f"- Selected run status: {run_status}",
    f"- Selected run conclusion: {run_conclusion}",
    f"- Selected run head SHA: {run_head_sha}",
    f"- Selected run matches local commit: {commit_matches}",
    f"- CI release evidence complete: {release_ready}",
    f"- Local rehearsal accepted: {rehearsal_accepted}",
    "",
    "## Files",
    "",
    "- commands.log",
    "- ci.yml",
    "- gh-version.txt or gh-missing.txt",
    "- gh-auth-status.txt",
    "- gh-run-list.json or gh-run-view.json",
    "- gh-run-failed.log when --run-id is used",
    "",
]

if release_ready:
    lines.extend([
        "A completed successful Linux CI run was found for the current commit.",
        "Paste this evidence into `docs/release/MANUAL_VALIDATION.md` before",
        "closing the `linux-ci` gate.",
        "",
    ])
elif allow_unavailable:
    lines.extend([
        "This was a local rehearsal with `--allow-unavailable`. Keep the",
        "`linux-ci` gate open until a maintainer reruns the helper with GitHub",
        "Actions evidence for a completed successful CI run on the release commit.",
        "",
    ])
else:
    lines.extend([
        "Linux CI release evidence is incomplete. Keep the manual `linux-ci`",
        "gate open and inspect the captured files above.",
        "",
    ])

(evidence_dir / "summary.md").write_text("\n".join(lines), encoding="utf-8")

if not release_ready and not allow_unavailable:
    raise SystemExit(1)
PY

echo
echo "Linux CI evidence captured."
echo "Evidence summary: $SUMMARY"
echo "Keep linux-ci open until a completed successful CI run is recorded for the release commit."
