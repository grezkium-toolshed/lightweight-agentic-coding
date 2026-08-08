"""Stage canonical top-level data into src/lac/data/ for packaging.

The top-level trees (runtime-config/, catalog/, opencode.template.jsonc, .opencode/,
and supported client templates) are the single source of truth. src/lac/data/ is a generated,
gitignored copy that ships inside the wheel so the installed `lac` can find its data.

This runs at build time (imported by setup.py) and can also be invoked directly:

    python3 scripts/stage_data.py

It is intentionally dependency-free (stdlib only) and does not shell out to git, so it
works inside pip's isolated build (which is not a git checkout) and on Windows.
"""

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / "src" / "lac" / "data"

# Names excluded anywhere in a path. Mirrors .gitignore intent so generated caches,
# opt-in binaries, and package manager cruft never ship in the wheel.
EXCLUDE_NAMES = {
    "node_modules", "__pycache__", ".DS_Store", "Thumbs.db",
    "package.json", "package-lock.json", "bun.lock", ".gitignore",
    "render-manifest.json", "plans",
    "msgraph",  # opt-in skill, downloaded on demand — never bundled
    "tenant-smith-workflow",  # internal skill, kept local — never bundled
    "assessment-analysis",  # internal skill, kept local — never bundled
}
EXCLUDE_SUFFIXES = (".downloading", ".pyc", ".swp", ".swo", ".log", ".tmp")


def _excluded(rel: Path) -> bool:
    if any(part in EXCLUDE_NAMES for part in rel.parts):
        return True
    return rel.suffix in EXCLUDE_SUFFIXES


def _copy_tree(src: Path, dst: Path) -> None:
    if not src.is_dir():
        return
    for path in sorted(src.rglob("*")):
        if path.is_dir():
            continue
        rel = path.relative_to(src)
        if _excluded(rel):
            continue
        target = dst / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)


def stage() -> bool:
    """Regenerate src/lac/data/ from the canonical top-level trees.

    Returns False (no-op) when the canonical trees are absent — e.g. building from an
    unpacked sdist, where src/lac/data/ is already present and must not be wiped.
    """
    if not (ROOT / "runtime-config" / "profiles.json").is_file():
        return False
    if DEST.exists():
        shutil.rmtree(DEST)
    DEST.mkdir(parents=True, exist_ok=True)

    shutil.copy2(ROOT / "THIRD_PARTY_NOTICES.md", DEST / "THIRD_PARTY_NOTICES.md")
    _copy_tree(ROOT / "catalog", DEST / "catalog")
    _copy_tree(ROOT / "runtime-config", DEST / "runtime-config")
    _copy_tree(ROOT / "templates" / "opencode", DEST / "templates" / "opencode")
    _copy_tree(ROOT / "templates" / "claude-code", DEST / "templates" / "claude-code")

    opencode_dest = DEST / "opencode"
    opencode_dest.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / "opencode.template.jsonc", opencode_dest / "opencode.template.jsonc")
    _copy_tree(ROOT / ".opencode", opencode_dest)
    return True


if __name__ == "__main__":
    staged = stage()
    if staged:
        count = sum(1 for p in DEST.rglob("*") if p.is_file())
        print(f"[stage-data] staged {count} files into {DEST.relative_to(ROOT)}")
    else:
        print("[stage-data] canonical trees absent; nothing to stage", file=sys.stderr)
