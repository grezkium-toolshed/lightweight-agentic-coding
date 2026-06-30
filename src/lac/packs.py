"""Workflow packs and asset catalog."""

import copy
import json
import os
import sys


def _env_or_deprecated(new_key, old_key, default=None):
    val = os.environ.get(new_key)
    if val is not None:
        return val
    val = os.environ.get(old_key)
    if val is not None:
        print(f"Warning: {old_key} is deprecated, use {new_key} instead", file=sys.stderr)
        return val
    return default


def load_asset_catalog(ctx):
    return json.loads(ctx.paths["asset_catalog"].read_text(encoding="utf-8"))


def load_workflow_catalog(ctx):
    return json.loads(ctx.paths["workflow_catalog"].read_text(encoding="utf-8"))


def optional_skill_root(ctx):
    import os
    from pathlib import Path
    env_dir = _env_or_deprecated("LAC_OPENCODE_SKILLS_DIR", "AI_CLUSTER_OPENCODE_SKILLS_DIR")
    if env_dir:
        return Path(env_dir)
    if ctx._is_repo:
        return ctx.root / ".opencode/skills"
    return Path.home() / ".local/share/lac/skills"


def optional_skill_path(ctx, skill_id):
    return optional_skill_root(ctx) / skill_id


def OPTIONAL_SKILLS():
    return {
        "msgraph": {
            "label": "Microsoft Graph Skill",
            "install_url": "https://github.com/merill/msgraph/releases/latest/download/msgraph.zip",
            "docs": "docs/providers/MICROSOFT_GRAPH.md",
            "required_help_terms": ["auth", "graph-call", "openapi-search"],
        }
    }


def optional_skill_status(ctx, skill_id):
    opt_skills = OPTIONAL_SKILLS()
    if skill_id not in opt_skills:
        raise SystemExit(f"Unsupported optional skill: {skill_id}")
    path = optional_skill_path(ctx, skill_id)
    return {
        "id": skill_id,
        "label": opt_skills[skill_id]["label"],
        "installed": (path / "SKILL.md").is_file(),
        "path": str(path),
        "docs": opt_skills[skill_id]["docs"],
    }


def _copy_optional_skill_from_dir(source, target):
    import shutil
    candidate = source
    if not (candidate / "SKILL.md").is_file() and (source / "msgraph" / "SKILL.md").is_file():
        candidate = source / "msgraph"
    if not (candidate / "SKILL.md").is_file():
        raise SystemExit(f"Source does not contain an msgraph SKILL.md: {source}")
    shutil.copytree(candidate, target)


def _extract_zip_safely(archive, extract_root):
    root = extract_root.resolve()
    for member in archive.infolist():
        destination = (extract_root / member.filename).resolve()
        if root != destination and root not in destination.parents:
            raise SystemExit(f"Unsafe path in skill archive: {member.filename}")
    archive.extractall(extract_root)


def _copy_optional_skill_from_zip(source, target):
    import tempfile
    from pathlib import Path
    with tempfile.TemporaryDirectory(prefix="lac-msgraph-") as tmp:
        extract_root = Path(tmp)
        import zipfile
        with zipfile.ZipFile(source) as archive:
            _extract_zip_safely(archive, extract_root)
        _copy_optional_skill_from_dir(extract_root, target)


def install_optional_skill(ctx, skill_id, source=None, force=False):
    import shutil
    import tempfile
    import urllib.error
    import urllib.request
    from pathlib import Path
    opt_skills = OPTIONAL_SKILLS()
    if skill_id not in opt_skills:
        raise SystemExit(f"Unsupported optional skill: {skill_id}")
    target = optional_skill_path(ctx, skill_id)
    if target.exists():
        if not force:
            status = optional_skill_status(ctx, skill_id)
            status["changed"] = False
            status["message"] = f"{skill_id} is already installed"
            return status
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="lac-msgraph-stage-", dir=target.parent) as stage:
        staged_target = Path(stage) / skill_id
        if source:
            source_path = Path(source).expanduser()
            if not source_path.exists():
                raise SystemExit(f"Skill source not found: {source_path}")
            if source_path.is_dir():
                _copy_optional_skill_from_dir(source_path, staged_target)
            else:
                _copy_optional_skill_from_zip(source_path, staged_target)
        else:
            archive_path = Path(stage) / "msgraph.zip"
            try:
                urllib.request.urlretrieve(opt_skills[skill_id]["install_url"], archive_path)
            except urllib.error.URLError as exc:
                raise SystemExit(f"Failed to download {skill_id}: {exc}") from exc
            _copy_optional_skill_from_zip(archive_path, staged_target)
        if target.exists():
            shutil.rmtree(target)
        shutil.move(str(staged_target), str(target))
    status = optional_skill_status(ctx, skill_id)
    status["changed"] = True
    status["source"] = source or opt_skills[skill_id]["install_url"]
    return status


def remove_optional_skill(ctx, skill_id):
    import shutil
    opt_skills = OPTIONAL_SKILLS()
    if skill_id not in opt_skills:
        raise SystemExit(f"Unsupported optional skill: {skill_id}")
    target = optional_skill_path(ctx, skill_id)
    if not target.exists():
        status = optional_skill_status(ctx, skill_id)
        status["changed"] = False
        status["message"] = f"{skill_id} is not installed"
        return status
    shutil.rmtree(target)
    status = optional_skill_status(ctx, skill_id)
    status["changed"] = True
    return status


def verify_optional_skill(ctx, skill_id, timeout=10):
    import os
    import subprocess
    from pathlib import Path
    status = optional_skill_status(ctx, skill_id)
    checks = []
    def add_check(name, ok, detail=""):
        checks.append({"name": name, "ok": ok, "detail": detail})
    skill_path = Path(status["path"])
    add_check("skill-directory", skill_path.is_dir(), str(skill_path))
    add_check("skill-md", (skill_path / "SKILL.md").is_file(), str(skill_path / "SKILL.md"))
    if os.name == "nt":
        run_script = skill_path / "scripts/run.ps1"
        command = ["pwsh", "-NoLogo", "-NoProfile", "-File", str(run_script), "--help"]
        auth_command = ["pwsh", "-NoLogo", "-NoProfile", "-File", str(run_script), "auth", "status"]
    else:
        run_script = skill_path / "scripts/run.sh"
        command = ["bash", str(run_script), "--help"]
        auth_command = ["bash", str(run_script), "auth", "status"]
    add_check("launcher", run_script.is_file(), str(run_script))
    help_output = ""
    if run_script.is_file():
        try:
            completed = subprocess.run(command, check=False, capture_output=True, text=True, timeout=timeout)
            help_output = (completed.stdout or "") + (completed.stderr or "")
            add_check("help-command", completed.returncode == 0, f"exit={completed.returncode}")
        except subprocess.TimeoutExpired:
            add_check("help-command", False, "timeout")
        for term in OPTIONAL_SKILLS()[skill_id]["required_help_terms"]:
            add_check(f"help-term:{term}", term in help_output, term)
        try:
            auth_completed = subprocess.run(auth_command, check=False, capture_output=True, text=True, timeout=timeout)
            add_check("auth-status", auth_completed.returncode == 0, f"exit={auth_completed.returncode}")
        except subprocess.TimeoutExpired:
            add_check("auth-status", False, "timeout")
    else:
        add_check("help-command", False, "launcher missing")
        for term in OPTIONAL_SKILLS()[skill_id]["required_help_terms"]:
            add_check(f"help-term:{term}", False, "launcher missing")
        add_check("auth-status", False, "launcher missing")
    return {
        "id": skill_id,
        "ok": all(check["ok"] for check in checks),
        "installed": status["installed"],
        "path": status["path"],
        "checks": checks,
    }


def build_pack_summary(ctx):
    asset_catalog = load_asset_catalog(ctx)
    workflow_catalog = load_workflow_catalog(ctx)
    asset_by_id = {asset["id"]: asset for asset in asset_catalog["assets"]}

    def bundled_asset_path(asset):
        asset_path = asset["path"]
        if ctx._is_repo or not asset_path.startswith(".opencode/"):
            return ctx.root / asset_path
        return ctx.root / "opencode" / asset_path.removeprefix(".opencode/")

    packs = []
    for pack in workflow_catalog["packs"]:
        pack_assets = []
        for asset_id in pack["assets"]:
            asset = copy.deepcopy(asset_by_id[asset_id])
            asset_path = bundled_asset_path(asset)
            if asset_id == "skill:msgraph":
                asset_path = optional_skill_path(ctx, "msgraph") / "SKILL.md"
            asset["installed"] = asset_path.is_file()
            pack_assets.append(asset)
        packs.append({
            "id": pack["id"],
            "label": pack["label"],
            "description": pack["description"],
            "supported_clients": pack["supported_clients"],
            "required_tools": pack["required_tools"],
            "trust_level": pack["trust_level"],
            "support_tier": pack.get("support_tier", "supported"),
            "installed": all(asset["installed"] for asset in pack_assets),
            "asset_count": len(pack_assets),
            "assets": pack_assets,
        })
    return packs


def pack_list(ctx):
    packs = build_pack_summary(ctx)
    return [
        {
            "id": pack["id"],
            "label": pack["label"],
            "trust_level": pack["trust_level"],
            "asset_count": pack["asset_count"],
            "supported_clients": pack["supported_clients"],
            "required_tools": pack["required_tools"],
        }
        for pack in packs
    ]


def pack_show(ctx, pack_id):
    for pack in build_pack_summary(ctx):
        if pack["id"] == pack_id:
            return pack
    raise SystemExit(f"Unknown pack: {pack_id}")
