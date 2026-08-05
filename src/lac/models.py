"""Model sync: download GGUF and MLX weights from Hugging Face."""

import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


PROFILE_MODELS = {
    "micro": {
        "gguf": [
            ('qwen3.5', 'Qwen3.5-4B-Q4_K_M.gguf', 'unsloth/Qwen3.5-4B-GGUF', 2500),
        ],
        "mlx": [],
    },
    "4gb": {
        "gguf": [
            ('qwen3.5', 'Qwen3.5-4B-Q4_K_M.gguf', 'unsloth/Qwen3.5-4B-GGUF', 2500),
        ],
        "mlx": [],
    },
    "6gb": {
        "gguf": [
            ('qwen3.5', 'Qwen3.5-9B-Q4_K_M.gguf', 'unsloth/Qwen3.5-9B-GGUF', 5000),
            ('qwen3.5', 'Qwen3.5-4B-Q4_K_M.gguf', 'unsloth/Qwen3.5-4B-GGUF', 2500),
        ],
        "mlx": [],
    },
    "8gb": {
        "gguf": [
            ('qwen3.5', 'Qwen3.5-9B-Q4_K_M.gguf', 'unsloth/Qwen3.5-9B-GGUF', 5000),
            ('qwen3.5', 'Qwen3.5-9B-Q6_K.gguf', 'unsloth/Qwen3.5-9B-GGUF', 7500),
            ('qwen3.5', 'Qwen3.5-4B-Q4_K_M.gguf', 'unsloth/Qwen3.5-4B-GGUF', 2500),
        ],
        "mlx": [],
    },
    "12gb": {
        "gguf": [
            ('qwen3.5', 'Qwen3.5-9B-Q8_0.gguf', 'unsloth/Qwen3.5-9B-GGUF', 9000),
            ('qwen3.5', 'Qwen3.5-9B-Q6_K.gguf', 'unsloth/Qwen3.5-9B-GGUF', 7500),
            ('qwen3.5', 'Qwen3.5-4B-Q4_K_M.gguf', 'unsloth/Qwen3.5-4B-GGUF', 2500),
        ],
        "mlx": [],
    },
    "16gb": {
        "gguf": [
            ('qwen3.6', 'Qwen3.6-27B-UD-IQ3_XXS.gguf', 'unsloth/Qwen3.6-27B-GGUF', 12000),
            ('qwen3.6', 'Qwen3.6-27B-UD-Q3_K_XL.gguf', 'unsloth/Qwen3.6-27B-GGUF', 14000),
            ('qwen3.5', 'Qwen3.5-4B-Q4_K_M.gguf', 'unsloth/Qwen3.5-4B-GGUF', 2500),
        ],
        "mlx": ['unsloth/Qwen3.6-27B-UD-MLX-6bit'],
    },
    "gemma-6gb": {
        "gguf": [
            ('gemma4', 'gemma-4-E4B-IT-Q8_0.gguf', 'unsloth/gemma-4-E4B-IT-GGUF', 4000),
        ],
        "mlx": [],
    },
    "gemma-8gb": {
        "gguf": [
            ('gemma4', 'gemma-4-12B-it-qat-UD-Q4_K_XL.gguf', 'unsloth/gemma-4-12B-it-qat-GGUF', 6000),
            ('gemma4', 'gemma-4-E4B-IT-Q8_0.gguf', 'unsloth/gemma-4-E4B-IT-GGUF', 4000),
        ],
        "mlx": [],
    },
    "macos-16gb": {
        "gguf": [
            ('gemma4', 'gemma-4-12B-it-qat-UD-Q4_K_XL.gguf', 'unsloth/gemma-4-12B-it-qat-GGUF', 6000),
            ('gemma4', 'gemma-4-12b-it-UD-Q4_K_XL.gguf', 'unsloth/gemma-4-12b-it-GGUF', 7500),
            ('qwen3.5', 'Qwen3.5-9B-Q4_K_M.gguf', 'unsloth/Qwen3.5-9B-GGUF', 5000),
            ('gemma4', 'gemma-4-E4B-IT-Q8_0.gguf', 'unsloth/gemma-4-E4B-IT-GGUF', 4000),
        ],
        "mlx": ['unsloth/gemma-4-E4B-it-MLX-8bit'],
    },
    "24gb": {
        "gguf": [
            ('qwen3.6', 'Qwen3.6-27B-UD-Q4_K_XL.gguf', 'unsloth/Qwen3.6-27B-GGUF', 17000),
            ('qwen3.6', 'Qwen3.6-27B-UD-Q3_K_XL.gguf', 'unsloth/Qwen3.6-27B-GGUF', 14000),
            ('qwen3.5', 'Qwen3.5-4B-Q4_K_M.gguf', 'unsloth/Qwen3.5-4B-GGUF', 2500),
        ],
        "mlx": ['unsloth/Qwen3.6-27B-UD-MLX-6bit'],
    },
    "32gb": {
        "gguf": [
            ('qwen3.6', 'Qwen3.6-27B-UD-Q4_K_XL.gguf', 'unsloth/Qwen3.6-27B-GGUF', 17000),
            ('qwen3.6-mtp', 'Qwen3.6-27B-MTP-UD-Q4_K_XL.gguf', 'unsloth/Qwen3.6-27B-MTP-GGUF', 19000),
            ('qwen3.5', 'Qwen3.5-4B-Q4_K_M.gguf', 'unsloth/Qwen3.5-4B-GGUF', 2500),
        ],
        "mlx": ['unsloth/Qwen3.6-27B-UD-MLX-6bit'],
    },
    "64gb": {
        "gguf": [
            ('qwen3.6', 'Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf', 'unsloth/Qwen3.6-35B-A3B-GGUF', 36000),
            ('qwen3.6', 'Qwen3.6-27B-UD-Q4_K_XL.gguf', 'unsloth/Qwen3.6-27B-GGUF', 17000),
            ('qwen3.6-mtp', 'Qwen3.6-35B-A3B-MTP-UD-Q6_K_XL.gguf', 'unsloth/Qwen3.6-35B-A3B-MTP-GGUF', 31000),
            ('qwen3.5', 'Qwen3.5-4B-Q4_K_M.gguf', 'unsloth/Qwen3.5-4B-GGUF', 2500),
        ],
        "mlx": ['unsloth/Qwen3.6-35B-A3B-MLX-8bit', 'unsloth/Qwen3.6-27B-UD-MLX-6bit'],
    },
    "128gb-qwen122b": {
        "gguf": [
            ('qwen3.5', 'Qwen3.5-122B-A10B-MXFP4_MOE-00001-of-00003.gguf', 'unsloth/Qwen3.5-122B-A10B-GGUF', 100),
            ('qwen3.5', 'Qwen3.5-122B-A10B-MXFP4_MOE-00002-of-00003.gguf', 'unsloth/Qwen3.5-122B-A10B-GGUF', 42000),
            ('qwen3.5', 'Qwen3.5-122B-A10B-MXFP4_MOE-00003-of-00003.gguf', 'unsloth/Qwen3.5-122B-A10B-GGUF', 15000),
            ('qwen3.6-mtp', 'Qwen3.6-27B-MTP-UD-Q4_K_XL.gguf', 'unsloth/Qwen3.6-27B-MTP-GGUF', 19000),
            ('qwen3.6-mtp', 'Qwen3.6-35B-A3B-MTP-UD-Q6_K_XL.gguf', 'unsloth/Qwen3.6-35B-A3B-MTP-GGUF', 31000),
            ('qwen3.5', 'Qwen3.5-4B-Q4_K_M.gguf', 'unsloth/Qwen3.5-4B-GGUF', 2500),
        ],
        "mlx": [],
    },
    "128gb-multi": {
        "gguf": [
            ('qwen3.6', 'Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf', 'unsloth/Qwen3.6-35B-A3B-GGUF', 36000),
            ('qwen3.6', 'Qwen3.6-27B-UD-Q4_K_XL.gguf', 'unsloth/Qwen3.6-27B-GGUF', 17000),
            ('qwen3.6-mtp', 'Qwen3.6-27B-MTP-UD-Q4_K_XL.gguf', 'unsloth/Qwen3.6-27B-MTP-GGUF', 19000),
            ('qwen3.6-mtp', 'Qwen3.6-35B-A3B-MTP-UD-Q6_K_XL.gguf', 'unsloth/Qwen3.6-35B-A3B-MTP-GGUF', 31000),
            ('qwen3.5', 'Qwen3.5-4B-Q4_K_M.gguf', 'unsloth/Qwen3.5-4B-GGUF', 2500),
        ],
        "mlx": ['unsloth/Qwen3.6-35B-A3B-MLX-8bit', 'unsloth/Qwen3.6-27B-UD-MLX-6bit'],
    },
    "128gb-minimax": {
        "gguf": [
            ('minimax', 'MiniMax-M2.7-UD-IQ4_XS-00001-of-00003.gguf', os.environ.get("MINIMAX_REPO", "unsloth/MiniMax-M2.7-GGUF"), 5),
            ('minimax', 'MiniMax-M2.7-UD-IQ4_XS-00002-of-00003.gguf', os.environ.get("MINIMAX_REPO", "unsloth/MiniMax-M2.7-GGUF"), 30000),
            ('minimax', 'MiniMax-M2.7-UD-IQ4_XS-00003-of-00003.gguf', os.environ.get("MINIMAX_REPO", "unsloth/MiniMax-M2.7-GGUF"), 30000),
            ('qwen3.6-mtp', 'Qwen3.6-27B-MTP-UD-Q4_K_XL.gguf', 'unsloth/Qwen3.6-27B-MTP-GGUF', 19000),
            ('qwen3.6-mtp', 'Qwen3.6-35B-A3B-MTP-UD-Q6_K_XL.gguf', 'unsloth/Qwen3.6-35B-A3B-MTP-GGUF', 31000),
            ('qwen3.5', 'Qwen3.5-4B-Q4_K_M.gguf', 'unsloth/Qwen3.5-4B-GGUF', 2500),
        ],
        "mlx": [],
    },
    "128gb-ds4-flash": {
        "gguf": [
            ('ds4', 'ds4flash.gguf', os.environ.get("DS4_REPO", "antirez/deepseek-v4-gguf"), 75000, 'DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf'),
            ('qwen3.5', 'Qwen3.5-4B-Q4_K_M.gguf', 'unsloth/Qwen3.5-4B-GGUF', 2500),
        ],
        "mlx": [],
    },
    "gemma-16gb": {
        "gguf": [
            ('gemma4', 'gemma-4-12b-it-UD-Q8_K_XL.gguf', 'unsloth/gemma-4-12b-it-GGUF', 13600),
            ('gemma4', 'gemma-4-12b-it-UD-Q4_K_XL.gguf', 'unsloth/gemma-4-12b-it-GGUF', 7500),
            ('gemma4', 'gemma-4-E4B-IT-Q8_0.gguf', 'unsloth/gemma-4-E4B-IT-GGUF', 4000),
        ],
        "mlx": ['unsloth/gemma-4-26b-a4b-it-UD-MLX-8bit', 'unsloth/gemma-4-E4B-it-MLX-8bit'],
    },
    "gemma-24gb": {
        "gguf": [
            ('gemma4', 'gemma-4-31B-IT-UD-Q4_K_XL.gguf', 'unsloth/gemma-4-31B-IT-GGUF', 16000),
            ('gemma4', 'gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf', 'unsloth/gemma-4-26B-A4B-IT-GGUF', 15000),
            ('gemma4', 'gemma-4-E4B-IT-Q8_0.gguf', 'unsloth/gemma-4-E4B-IT-GGUF', 4000),
        ],
        "mlx": ['unsloth/gemma-4-31b-it-UD-MLX-4bit', 'unsloth/gemma-4-26b-a4b-it-UD-MLX-8bit'],
    },
    "gemma-32gb": {
        "gguf": [
            ('gemma4', 'gemma-4-31B-IT-Q8_0.gguf', 'unsloth/gemma-4-31B-IT-GGUF', 32000),
            ('gemma4', 'gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf', 'unsloth/gemma-4-26B-A4B-IT-GGUF', 15000),
            ('gemma4', 'gemma-4-E4B-IT-Q8_0.gguf', 'unsloth/gemma-4-E4B-IT-GGUF', 4000),
        ],
        "mlx": ['unsloth/gemma-4-31b-it-UD-MLX-4bit', 'unsloth/gemma-4-26b-a4b-it-UD-MLX-8bit'],
    },
    "gemma-64gb": {
        "gguf": [
            ('gemma4', 'gemma-4-31B-IT-BF16.gguf', 'unsloth/gemma-4-31B-IT-GGUF', 60000),
            ('gemma4', 'gemma-4-31B-IT-Q8_0.gguf', 'unsloth/gemma-4-31B-IT-GGUF', 32000),
            ('gemma4', 'gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf', 'unsloth/gemma-4-26B-A4B-IT-GGUF', 15000),
            ('gemma4', 'gemma-4-E4B-IT-Q8_0.gguf', 'unsloth/gemma-4-E4B-IT-GGUF', 4000),
        ],
        "mlx": ['unsloth/gemma-4-31b-it-UD-MLX-4bit', 'unsloth/gemma-4-26b-a4b-it-UD-MLX-8bit'],
    },
}

CLOUD_PROFILES = {"openrouter", "opencode-go"}


def command_exists(name):
    return shutil.which(name) is not None


def _hf_cli():
    if command_exists("hf"):
        return "hf"
    if command_exists("huggingface-cli"):
        return "huggingface-cli"
    return None


def _should_stage_mlx():
    value = os.environ.get("AI_INCLUDE_MLX", "auto").lower()
    if value in ("1", "true", "yes"):
        if sys.platform != "darwin":
            print("MLX is only supported on macOS. Ignoring AI_INCLUDE_MLX.", file=sys.stderr)
            return False
        return True
    if value in ("0", "false", "no"):
        return False
    if value == "auto":
        return sys.platform == "darwin"
    raise SystemExit(f"Unsupported AI_INCLUDE_MLX value: {value}")


def _load_known_checksums(models_dir, root=None):
    """Merge bundled checksums (catalog/checksums.json) with any local models_dir/checksums.json."""
    if root is None:
        from lac.context import ROOT as DEFAULT_ROOT
        root = DEFAULT_ROOT
    merged = {}
    for path in (Path(root) / "catalog" / "checksums.json", Path(models_dir) / "checksums.json"):
        if path.is_file():
            try:
                merged.update(json.loads(path.read_text(encoding="utf-8")).get("checksums", {}))
            except (ValueError, OSError):
                continue
    return merged


def _verify_checksum(file_path, models_dir, known_checksums=None):
    if known_checksums is None:
        known_checksums = _load_known_checksums(models_dir)
    rel_path = str(Path(file_path).relative_to(models_dir))
    expected = known_checksums.get(rel_path, "")
    if not expected:
        return True
    actual = hashlib.sha256(Path(file_path).read_bytes()).hexdigest()
    if actual != expected:
        print(f"[warn] Checksum mismatch for {rel_path}", file=sys.stderr)
        print(f"       expected: {expected}", file=sys.stderr)
        print(f"       actual:   {actual}", file=sys.stderr)
        return False
    print(f"[checksum ok] {rel_path}")
    return True


def _quarantine_checksum_mismatch(file_path):
    path = Path(file_path)
    candidate = path.with_name(path.name + ".checksum-mismatch")
    counter = 1
    while candidate.exists():
        candidate = path.with_name(path.name + f".checksum-mismatch.{counter}")
        counter += 1
    shutil.move(str(path), str(candidate))
    print(f"[fail] Quarantined checksum mismatch: {candidate}", file=sys.stderr)


def _get_expected_bytes(url):
    import urllib.request
    try:
        req = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(req, timeout=10) as resp:
            cl = resp.headers.get("Content-Length")
            if cl:
                return int(cl)
    except Exception:
        pass
    return 0


def _download_one(subdir, filename, repo, remote, min_mb, models_dir, known_checksums=None):
    target_dir = Path(models_dir) / subdir
    target_file = target_dir / filename
    tmp_file = target_file.with_name(filename + ".downloading")
    rel_path = str(target_file.relative_to(models_dir))
    has_checksum = bool((known_checksums or {}).get(rel_path))
    url = f"https://huggingface.co/{repo}/resolve/main/{remote}"
    target_dir.mkdir(parents=True, exist_ok=True)
    expected_bytes = _get_expected_bytes(url)
    expected_mb = expected_bytes // (1024 * 1024) if expected_bytes else 0
    if target_file.is_file() and has_checksum:
        if _verify_checksum(target_file, models_dir, known_checksums):
            print(f"[skip] {target_file} (verified)")
            return True
        _quarantine_checksum_mismatch(target_file)
    if target_file.is_file():
        size_bytes = target_file.stat().st_size
        size_mb = size_bytes // (1024 * 1024)
        if expected_bytes > 0 and size_bytes >= expected_bytes:
            print(f"[skip] {target_file} ({size_mb}MB of ~{expected_mb}MB)")
            return True
        if expected_bytes == 0 and size_mb >= min_mb:
            print(f"[skip] {target_file} ({size_mb}MB)")
            return True
        print(f"[warn] {target_file} incomplete ({size_mb}MB{' of ~' + str(expected_mb) + 'MB' if expected_mb else ''}); preserving for resume")
        shutil.move(str(target_file), str(tmp_file))
    if not target_file.is_file() and tmp_file.is_file():
        tmp_bytes = tmp_file.stat().st_size
        tmp_mb = tmp_bytes // (1024 * 1024)
        if expected_bytes > 0 and tmp_bytes >= expected_bytes:
            print(f"[resume] Promoting completed partial file: {tmp_file}")
            shutil.move(str(tmp_file), str(target_file))
        elif expected_bytes == 0 and tmp_mb >= min_mb:
            print(f"[resume] Promoting completed partial file: {tmp_file}")
            shutil.move(str(tmp_file), str(target_file))
    if target_file.is_file() and has_checksum:
        if _verify_checksum(target_file, models_dir, known_checksums):
            print(f"[skip] {target_file} (verified resumed download)")
            return True
        _quarantine_checksum_mismatch(target_file)
    if target_file.is_file():
        promoted_bytes = target_file.stat().st_size
        promoted_mb = promoted_bytes // (1024 * 1024)
        if expected_bytes > 0 and promoted_bytes >= expected_bytes:
            print(f"[skip] {target_file} ({promoted_mb}MB of ~{expected_mb}MB)")
            return True
        elif expected_bytes == 0 and promoted_mb >= min_mb:
            print(f"[skip] {target_file} ({promoted_mb}MB)")
            return True
    hf = _hf_cli()
    if hf:
        print(f"[hf  ] {repo}/{remote} -> {target_dir}")
        result = subprocess.run([hf, "download", repo, remote, "--local-dir", str(target_dir)], check=False)
        if result.returncode != 0:
            print(f"[fail] Hugging Face CLI download failed: {repo}/{remote}", file=sys.stderr)
            return False
    else:
        print(f"[get ] {url}")
        result = subprocess.run(
            ["curl", "-fL", "--retry", "3", "--retry-delay", "3", "--retry-max-time", "300", "-C", "-", "-o", str(tmp_file), url],
            check=False,
        )
        if result.returncode != 0:
            print(f"[fail] Download failed, partial file preserved for resume: {tmp_file}", file=sys.stderr)
            return False
        shutil.move(str(tmp_file), str(target_file))
    if not target_file.is_file():
        print(f"[fail] Expected downloaded file missing: {target_file}", file=sys.stderr)
        return False
    new_bytes = target_file.stat().st_size
    new_mb = new_bytes // (1024 * 1024)
    if expected_bytes > 0:
        if new_bytes < expected_bytes:
            print(f"[fail] Download incomplete for {filename} ({new_mb}MB vs expected ~{expected_mb}MB); keeping file for resume", file=sys.stderr)
            shutil.move(str(target_file), str(tmp_file))
            return False
    elif new_mb < min_mb:
        print(f"[fail] Download too small for {filename} ({new_mb}MB < {min_mb}MB); keeping file for inspection/resume", file=sys.stderr)
        return False
    if not _verify_checksum(str(target_file), models_dir, known_checksums):
        _quarantine_checksum_mismatch(target_file)
        return False
    print(f"[ ok ] {target_file} ({new_mb}MB{' of ~' + str(expected_mb) + 'MB' if expected_mb else ''})")
    return True


def _download_mlx_repo(repo, models_dir):
    target_dir = Path(models_dir) / "mlx" / repo.split("/", 1)[1]
    if target_dir.is_dir():
        print(f"[skip] {target_dir}")
        return True
    hf = _hf_cli()
    if hf:
        print(f"[mlx ] {repo} -> {target_dir}")
        result = subprocess.run([hf, "download", repo, "--local-dir", str(target_dir)], check=False)
        if result.returncode != 0:
            print(f"[fail] MLX download failed: {repo}", file=sys.stderr)
            return False
        return True
    print(f"[warn] Skipping MLX repo {repo}: install the Hugging Face CLI ('hf' or 'huggingface-cli') to stage macOS MLX weights.", file=sys.stderr)
    return False


def models_sync(profile_id, models_dir=None, root=None):
    from lac.context import MODELS_ROOT, ROOT as DEFAULT_ROOT
    root_was_provided = root is not None
    if root is None:
        root = DEFAULT_ROOT
    if models_dir is None:
        models_dir = Path(root) / "models" if root_was_provided else MODELS_ROOT
    if profile_id in CLOUD_PROFILES:
        print(f"Profile: {profile_id}")
        print(f"No local model downloads are required for the cloud-only {profile_id} profile.")
        return 0
    if profile_id not in PROFILE_MODELS:
        print(f"Unsupported profile: {profile_id}", file=sys.stderr)
        return 1
    profile = PROFILE_MODELS[profile_id]
    Path(models_dir).mkdir(parents=True, exist_ok=True)
    print(f"Profile: {profile_id}")
    print(f"Models dir: {models_dir}")
    stage_mlx = _should_stage_mlx()
    if stage_mlx and profile["mlx"]:
        print("MLX staging: enabled for macOS")
    known_checksums = _load_known_checksums(models_dir, root)
    failures = 0
    for item in profile["gguf"]:
        if len(item) == 4:
            subdir, filename, repo, min_mb = item
            remote = filename
        else:
            subdir, filename, repo, min_mb, remote = item
        if not _download_one(subdir, filename, repo, remote, min_mb, models_dir, known_checksums):
            failures += 1
    if stage_mlx:
        for repo in profile["mlx"]:
            if not _download_mlx_repo(repo, models_dir):
                failures += 1
    if failures > 0:
        print(f"Done with {failures} failed download(s). Re-run the same command to resume.", file=sys.stderr)
        return 1
    print("Done.")
    return 0
