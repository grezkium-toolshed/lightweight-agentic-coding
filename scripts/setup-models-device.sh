#!/bin/bash
set -euo pipefail

PROFILE=""
AI_CLUSTER_ROOT="${AI_CLUSTER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
AI_MODELS_DIR="${AI_MODELS_DIR:-$AI_CLUSTER_ROOT/models}"

usage() {
  cat << USAGE
Usage: $0 --profile <16gb|macos-16gb|24gb|32gb|64gb|128gb-multi|128gb-qwen122b|128gb-minimax|gemma-16gb|gemma-24gb|gemma-32gb|gemma-64gb|openrouter|opencode-go>

Environment overrides:
  AI_CLUSTER_ROOT  Base repository path (default: script parent)
  AI_MODELS_DIR    Models folder (default: \$AI_CLUSTER_ROOT/models)
  AI_INCLUDE_MLX   On macOS, also stage Qwen 3.6 MLX repos when a Hugging Face CLI is installed (default: auto)
  MINIMAX_REPO     Hugging Face repo for MiniMax profile
  MINIMAX_FILES    Comma-separated MiniMax GGUF files for 128gb-minimax
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$PROFILE" ]]; then
  usage
  exit 1
fi

mkdir -p "$AI_MODELS_DIR"

declare -a MODELS
declare -a MLX_MODELS
MODELS+=("embeddings|nomic-embed-text-v1.5.Q4_K_M.gguf|nomic-ai/nomic-embed-text-v1.5-GGUF|nomic-embed-text-v1.5.Q4_K_M.gguf|60")

is_macos() {
  [[ "$(uname -s)" == "Darwin" ]]
}

# Verify file against models/checksums.json if an entry exists.
# Returns 0 if checksum matches or no checksum is recorded.
verify_checksum() {
  local file_path="$1"
  local checksums_file="$AI_MODELS_DIR/checksums.json"
  [[ -f "$checksums_file" ]] || return 0

  local rel_path
  rel_path="${file_path#$AI_MODELS_DIR/}"

  local expected
  expected="$(python3 -c "
import json, sys
from pathlib import Path
checksums = json.load(Path('$checksums_file').open())
print(checksums.get('checksums', {}).get('$rel_path', ''))
" 2>/dev/null)"

  [[ -n "$expected" ]] || return 0

  local actual
  actual="$(shasum -a 256 "$file_path" 2>/dev/null | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    echo "[warn] Checksum mismatch for $rel_path" >&2
    echo "       expected: $expected" >&2
    echo "       actual:   $actual" >&2
    return 1
  fi
  echo "[checksum ok] $rel_path"
}

should_stage_mlx() {
  case "${AI_INCLUDE_MLX:-auto}" in
    1|true|yes)
      if is_macos; then
        return 0
      else
        echo "MLX is only supported on macOS. Ignoring AI_INCLUDE_MLX=${AI_INCLUDE_MLX}." >&2
        return 1
      fi
      ;;
    0|false|no) return 1 ;;
    auto) is_macos ;;
    *)
      echo "Unsupported AI_INCLUDE_MLX value: ${AI_INCLUDE_MLX}" >&2
      exit 1
      ;;
  esac
}

add_mlx() {
  local repo="$1"
  MLX_MODELS+=("$repo")
}

case "$PROFILE" in
  16gb)
    MODELS+=("qwen3.6|Qwen3.6-27B-UD-Q3_K_XL.gguf|unsloth/Qwen3.6-27B-GGUF|Qwen3.6-27B-UD-Q3_K_XL.gguf|14000")
    add_mlx "unsloth/Qwen3.6-27B-UD-MLX-6bit"
    ;;
  macos-16gb)
    MODELS+=("qwen3.5|Qwen3.5-9B-Q4_K_M.gguf|unsloth/Qwen3.5-9B-GGUF|Qwen3.5-9B-Q4_K_M.gguf|5000")
    MODELS+=("gemma4|gemma-4-E4B-IT-Q8_0.gguf|unsloth/gemma-4-E4B-IT-GGUF|gemma-4-E4B-IT-Q8_0.gguf|4000")
    add_mlx "unsloth/gemma-4-E4B-it-MLX-8bit"
    ;;
  24gb)
    MODELS+=("qwen3.6|Qwen3.6-27B-UD-Q4_K_XL.gguf|unsloth/Qwen3.6-27B-GGUF|Qwen3.6-27B-UD-Q4_K_XL.gguf|17000")
    MODELS+=("qwen3.6|Qwen3.6-27B-UD-Q3_K_XL.gguf|unsloth/Qwen3.6-27B-GGUF|Qwen3.6-27B-UD-Q3_K_XL.gguf|14000")
    add_mlx "unsloth/Qwen3.6-27B-UD-MLX-6bit"
    ;;
  32gb)
    MODELS+=("qwen3.6|Qwen3.6-27B-UD-Q4_K_XL.gguf|unsloth/Qwen3.6-27B-GGUF|Qwen3.6-27B-UD-Q4_K_XL.gguf|17000")
    MODELS+=("qwen|Qwen3-Coder-Next-MXFP4_MOE.gguf|unsloth/Qwen3-Coder-Next-GGUF|Qwen3-Coder-Next-MXFP4_MOE.gguf|28000")
    add_mlx "unsloth/Qwen3.6-27B-UD-MLX-6bit"
    ;;
  64gb)
    MODELS+=("qwen3.6|Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf|unsloth/Qwen3.6-35B-A3B-GGUF|Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf|36000")
    MODELS+=("qwen3.6|Qwen3.6-27B-UD-Q4_K_XL.gguf|unsloth/Qwen3.6-27B-GGUF|Qwen3.6-27B-UD-Q4_K_XL.gguf|17000")
    MODELS+=("qwen|Qwen3-Coder-Next-MXFP4_MOE.gguf|unsloth/Qwen3-Coder-Next-GGUF|Qwen3-Coder-Next-MXFP4_MOE.gguf|28000")
    add_mlx "unsloth/Qwen3.6-35B-A3B-MLX-8bit"
    add_mlx "unsloth/Qwen3.6-27B-UD-MLX-6bit"
    ;;
  128gb-qwen122b)
    MODELS+=("qwen3.5|Qwen3.5-122B-A10B-MXFP4_MOE-00001-of-00003.gguf|unsloth/Qwen3.5-122B-A10B-GGUF|Qwen3.5-122B-A10B-MXFP4_MOE-00001-of-00003.gguf|100")
    MODELS+=("qwen3.5|Qwen3.5-122B-A10B-MXFP4_MOE-00002-of-00003.gguf|unsloth/Qwen3.5-122B-A10B-GGUF|Qwen3.5-122B-A10B-MXFP4_MOE-00002-of-00003.gguf|42000")
    MODELS+=("qwen3.5|Qwen3.5-122B-A10B-MXFP4_MOE-00003-of-00003.gguf|unsloth/Qwen3.5-122B-A10B-GGUF|Qwen3.5-122B-A10B-MXFP4_MOE-00003-of-00003.gguf|15000")
    MODELS+=("qwen|Qwen3-Coder-Next-MXFP4_MOE.gguf|unsloth/Qwen3-Coder-Next-GGUF|Qwen3-Coder-Next-MXFP4_MOE.gguf|28000")
    ;;
  128gb-multi)
    MODELS+=("qwen3.6|Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf|unsloth/Qwen3.6-35B-A3B-GGUF|Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf|36000")
    MODELS+=("qwen3.6|Qwen3.6-27B-UD-Q4_K_XL.gguf|unsloth/Qwen3.6-27B-GGUF|Qwen3.6-27B-UD-Q4_K_XL.gguf|17000")
    MODELS+=("qwen3.6|Qwen3.6-27B-UD-Q3_K_XL.gguf|unsloth/Qwen3.6-27B-GGUF|Qwen3.6-27B-UD-Q3_K_XL.gguf|14000")
    MODELS+=("qwen|Qwen3-Coder-Next-MXFP4_MOE.gguf|unsloth/Qwen3-Coder-Next-GGUF|Qwen3-Coder-Next-MXFP4_MOE.gguf|28000")
    add_mlx "unsloth/Qwen3.6-35B-A3B-MLX-8bit"
    add_mlx "unsloth/Qwen3.6-27B-UD-MLX-6bit"
    ;;
  128gb-minimax)
    MINIMAX_REPO="${MINIMAX_REPO:-unsloth/MiniMax-M2.7-GGUF}"
    MINIMAX_FILES="${MINIMAX_FILES:-MiniMax-M2.7-UD-IQ4_XS-00001-of-00003.gguf,MiniMax-M2.7-UD-IQ4_XS-00002-of-00003.gguf,MiniMax-M2.7-UD-IQ4_XS-00003-of-00003.gguf}"
    IFS=',' read -r -a MINI_FILES <<< "$MINIMAX_FILES"
    for mf in "${MINI_FILES[@]}"; do
      case "$mf" in
        *00001-of-00003.gguf) min_mb=5 ;;
        *00002-of-00003.gguf) min_mb=30000 ;;
        *00003-of-00003.gguf) min_mb=30000 ;;
        *) min_mb=1000 ;;
      esac
      MODELS+=("minimax|$mf|$MINIMAX_REPO|$mf|$min_mb")
    done
    MODELS+=("qwen|Qwen3-Coder-Next-MXFP4_MOE.gguf|unsloth/Qwen3-Coder-Next-GGUF|Qwen3-Coder-Next-MXFP4_MOE.gguf|28000")
    ;;
  gemma-16gb)
    MODELS+=("gemma4|gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf|unsloth/gemma-4-26B-A4B-IT-GGUF|gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf|15000")
    MODELS+=("gemma4|gemma-4-E4B-IT-Q8_0.gguf|unsloth/gemma-4-E4B-IT-GGUF|gemma-4-E4B-IT-Q8_0.gguf|4000")
    add_mlx "unsloth/gemma-4-26b-a4b-it-UD-MLX-8bit"
    add_mlx "unsloth/gemma-4-E4B-it-MLX-8bit"
    ;;
  gemma-24gb)
    MODELS+=("gemma4|gemma-4-31B-IT-UD-Q4_K_XL.gguf|unsloth/gemma-4-31B-IT-GGUF|gemma-4-31B-IT-UD-Q4_K_XL.gguf|16000")
    MODELS+=("gemma4|gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf|unsloth/gemma-4-26B-A4B-IT-GGUF|gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf|15000")
    add_mlx "unsloth/gemma-4-31b-it-UD-MLX-4bit"
    add_mlx "unsloth/gemma-4-26b-a4b-it-UD-MLX-8bit"
    ;;
  gemma-32gb)
    MODELS+=("gemma4|gemma-4-31B-IT-Q8_0.gguf|unsloth/gemma-4-31B-IT-GGUF|gemma-4-31B-IT-Q8_0.gguf|32000")
    MODELS+=("gemma4|gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf|unsloth/gemma-4-26B-A4B-IT-GGUF|gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf|15000")
    add_mlx "unsloth/gemma-4-31b-it-UD-MLX-4bit"
    add_mlx "unsloth/gemma-4-26b-a4b-it-UD-MLX-8bit"
    ;;
  gemma-64gb)
    MODELS+=("gemma4|gemma-4-31B-IT-BF16.gguf|unsloth/gemma-4-31B-IT-GGUF|gemma-4-31B-IT-BF16.gguf|60000")
    MODELS+=("gemma4|gemma-4-31B-IT-Q8_0.gguf|unsloth/gemma-4-31B-IT-GGUF|gemma-4-31B-IT-Q8_0.gguf|32000")
    MODELS+=("gemma4|gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf|unsloth/gemma-4-26B-A4B-IT-GGUF|gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf|15000")
    add_mlx "unsloth/gemma-4-31b-it-UD-MLX-4bit"
    add_mlx "unsloth/gemma-4-26b-a4b-it-UD-MLX-8bit"
    ;;
  openrouter)
    echo "Profile: openrouter"
    echo "No local model downloads are required for the cloud-only openrouter profile."
    exit 0
    ;;
  opencode-go)
    echo "Profile: opencode-go"
    echo "No local model downloads are required for the cloud-only opencode-go profile."
    exit 0
    ;;
  *)
    echo "Unsupported profile: $PROFILE" >&2
    exit 1
    ;;
esac

download_one() {
  local subdir="$1"
  local filename="$2"
  local repo="$3"
  local remote="$4"
  local min_mb="$5"

  local target_dir="$AI_MODELS_DIR/$subdir"
  local target_file="$target_dir/$filename"
  local tmp_file="$target_file.downloading"
  local url="https://huggingface.co/$repo/resolve/main/$remote"

  mkdir -p "$target_dir"

  # Fetch expected file size from Hugging Face for validation. This is more
  # reliable than profile-era minimum sizes because upstream artifacts can be
  # smaller than our conservative estimates.
  local expected_bytes
  expected_bytes="$(curl -sI -L --max-redirs 5 "$url" 2>/dev/null | grep -i 'content-length' | tail -1 | awk '{print $2}' | tr -d '\r')"
  local expected_mb=0
  if [[ -n "$expected_bytes" && "$expected_bytes" -gt 0 ]] 2>/dev/null; then
    expected_mb=$(( expected_bytes / 1048576 ))
  else
    expected_bytes=0
  fi

  if [[ -f "$target_file" ]]; then
    local size_bytes size_mb
    size_bytes="$(wc -c < "$target_file" | tr -d ' ')"
    size_mb=$(( size_bytes / 1048576 ))
    if [[ "$expected_bytes" -gt 0 && "$size_bytes" -ge "$expected_bytes" ]]; then
      echo "[skip] $target_file (${size_mb}MB of ~${expected_mb}MB)"
      return
    fi
    if [[ "$expected_bytes" -eq 0 && "$size_mb" -ge "$min_mb" ]]; then
      echo "[skip] $target_file (${size_mb}MB)"
      return
    fi
    echo "[warn] $target_file incomplete (${size_mb}MB${expected_mb:+ of ~${expected_mb}MB}); preserving for resume"
    mv "$target_file" "$tmp_file"
  fi

  if [[ ! -f "$target_file" && -f "$tmp_file" ]]; then
    local tmp_bytes tmp_mb
    tmp_bytes="$(wc -c < "$tmp_file" | tr -d ' ')"
    tmp_mb=$(( tmp_bytes / 1048576 ))
    if [[ "$expected_bytes" -gt 0 && "$tmp_bytes" -ge "$expected_bytes" ]]; then
      echo "[resume] Promoting completed partial file: $tmp_file"
      mv "$tmp_file" "$target_file"
    elif [[ "$expected_bytes" -eq 0 && "$tmp_mb" -ge "$min_mb" ]]; then
      echo "[resume] Promoting completed partial file: $tmp_file"
      mv "$tmp_file" "$target_file"
    fi
  fi
  if [[ -f "$target_file" ]]; then
    local promoted_bytes promoted_mb
    promoted_bytes="$(wc -c < "$target_file" | tr -d ' ')"
    promoted_mb=$(( promoted_bytes / 1048576 ))
    if [[ "$expected_bytes" -gt 0 && "$promoted_bytes" -ge "$expected_bytes" ]]; then
      echo "[skip] $target_file (${promoted_mb}MB of ~${expected_mb}MB)"
      return
    elif [[ "$expected_bytes" -eq 0 && "$promoted_mb" -ge "$min_mb" ]]; then
      echo "[skip] $target_file (${promoted_mb}MB)"
      return
    fi
  fi

  if command -v hf >/dev/null 2>&1; then
    echo "[hf  ] $repo/$remote -> $target_dir"
    if ! hf download "$repo" "$remote" --local-dir "$target_dir"; then
      echo "[fail] Hugging Face CLI download failed: $repo/$remote" >&2
      return 1
    fi
  elif command -v huggingface-cli >/dev/null 2>&1; then
    echo "[hf  ] $repo/$remote -> $target_dir"
    if ! huggingface-cli download "$repo" "$remote" --local-dir "$target_dir"; then
      echo "[fail] Hugging Face CLI download failed: $repo/$remote" >&2
      return 1
    fi
  else
    echo "[get ] $url"
    if ! curl -fL --retry 3 --retry-delay 3 --retry-max-time 300 -C - -o "$tmp_file" "$url"; then
      echo "[fail] Download failed, partial file preserved for resume: $tmp_file" >&2
      return 1
    fi
    mv "$tmp_file" "$target_file"
  fi

  if [[ ! -f "$target_file" ]]; then
    echo "[fail] Expected downloaded file missing: $target_file" >&2
    return 1
  fi

  local new_bytes new_mb
  new_bytes="$(wc -c < "$target_file" | tr -d ' ')"
  new_mb=$(( new_bytes / 1048576 ))
  if [[ "$expected_bytes" -gt 0 ]]; then
    if [[ "$new_bytes" -lt "$expected_bytes" ]]; then
      echo "[fail] Download incomplete for $filename (${new_mb}MB vs expected ~${expected_mb}MB); keeping file for resume" >&2
      mv "$target_file" "$tmp_file"
      return 1
    fi
  elif [[ "$new_mb" -lt "$min_mb" ]]; then
    echo "[fail] Download too small for $filename (${new_mb}MB < ${min_mb}MB); keeping file for inspection/resume" >&2
    return 1
  fi

  verify_checksum "$target_file" || true

  echo "[ ok ] $target_file (${new_mb}MB${expected_mb:+ of ~${expected_mb}MB})"
}

download_mlx_repo() {
  local repo="$1"
  local target_dir="$AI_MODELS_DIR/mlx/${repo#*/}"

  if [[ -d "$target_dir" ]]; then
    echo "[skip] $target_dir"
    return
  fi

  if command -v hf >/dev/null 2>&1; then
    echo "[mlx ] $repo -> $target_dir"
    if ! hf download "$repo" --local-dir "$target_dir"; then
      echo "[fail] MLX download failed: $repo" >&2
      return 1
    fi
    return
  fi

  if command -v huggingface-cli >/dev/null 2>&1; then
    echo "[mlx ] $repo -> $target_dir"
    if ! huggingface-cli download "$repo" --local-dir "$target_dir"; then
      echo "[fail] MLX download failed: $repo" >&2
      return 1
    fi
    return
  fi

  echo "[warn] Skipping MLX repo $repo: install the Hugging Face CLI ('hf' or 'huggingface-cli') to stage macOS MLX weights." >&2
}

echo "Profile: $PROFILE"
echo "Models dir: $AI_MODELS_DIR"
if should_stage_mlx && [[ "${#MLX_MODELS[@]}" -gt 0 ]]; then
  echo "MLX staging: enabled for macOS"
fi

failures=0
for item in "${MODELS[@]}"; do
  IFS='|' read -r subdir filename repo remote min_mb <<< "$item"
  if ! download_one "$subdir" "$filename" "$repo" "$remote" "$min_mb"; then
    failures=$((failures + 1))
  fi
done

if should_stage_mlx; then
  for repo in "${MLX_MODELS[@]}"; do
    if ! download_mlx_repo "$repo"; then
      failures=$((failures + 1))
    fi
  done
fi

if [[ "$failures" -gt 0 ]]; then
  echo "Done with $failures failed download(s). Re-run the same command to resume." >&2
  exit 1
fi

echo "Done."
