#!/bin/bash
set -euo pipefail

PROFILE=""
AI_CLUSTER_ROOT="${AI_CLUSTER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
AI_MODELS_DIR="${AI_MODELS_DIR:-$AI_CLUSTER_ROOT/models}"

usage() {
  cat << USAGE
Usage: $0 --profile <16gb|24gb|32gb|64gb|128gb-multi|128gb-qwen122b|128gb-minimax|gemma-16gb|gemma-24gb|gemma-32gb|gemma-64gb|openrouter>

Environment overrides:
  AI_CLUSTER_ROOT  Base repository path (default: script parent)
  AI_MODELS_DIR    Models folder (default: \$AI_CLUSTER_ROOT/models)
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
MODELS+=("embeddings|nomic-embed-text-v1.5.Q4_K_M.gguf|nomic-ai/nomic-embed-text-v1.5-GGUF|nomic-embed-text-v1.5.Q4_K_M.gguf|60")

case "$PROFILE" in
  16gb)
    MODELS+=("qwen3.5|Qwen3.5-9B-UD-Q4_K_XL.gguf|unsloth/Qwen3.5-9B-GGUF|Qwen3.5-9B-UD-Q4_K_XL.gguf|5000")
    ;;
  24gb)
    MODELS+=("qwen3.5|Qwen3.5-27B-UD-Q4_K_XL.gguf|unsloth/Qwen3.5-27B-GGUF|Qwen3.5-27B-UD-Q4_K_XL.gguf|12000")
    MODELS+=("qwen3.5|Qwen3.5-9B-UD-Q4_K_XL.gguf|unsloth/Qwen3.5-9B-GGUF|Qwen3.5-9B-UD-Q4_K_XL.gguf|5000")
    ;;
  32gb)
    MODELS+=("qwen3.5|Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf|unsloth/Qwen3.5-35B-A3B-GGUF|Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf|15000")
    MODELS+=("qwen3.5|Qwen3.5-27B-UD-Q4_K_XL.gguf|unsloth/Qwen3.5-27B-GGUF|Qwen3.5-27B-UD-Q4_K_XL.gguf|12000")
    MODELS+=("qwen|Qwen3-Coder-Next-MXFP4_MOE.gguf|unsloth/Qwen3-Coder-Next-GGUF|Qwen3-Coder-Next-MXFP4_MOE.gguf|28000")
    ;;
  64gb)
    MODELS+=("qwen3.5|Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf|unsloth/Qwen3.5-35B-A3B-GGUF|Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf|15000")
    MODELS+=("qwen3.5|Qwen3.5-27B-UD-Q4_K_XL.gguf|unsloth/Qwen3.5-27B-GGUF|Qwen3.5-27B-UD-Q4_K_XL.gguf|12000")
    MODELS+=("qwen|Qwen3-Coder-Next-MXFP4_MOE.gguf|unsloth/Qwen3-Coder-Next-GGUF|Qwen3-Coder-Next-MXFP4_MOE.gguf|28000")
    ;;
  128gb-qwen122b)
    MODELS+=("qwen3.5|Qwen3.5-122B-A10B-MXFP4_MOE-00001-of-00003.gguf|unsloth/Qwen3.5-122B-A10B-GGUF|Qwen3.5-122B-A10B-MXFP4_MOE-00001-of-00003.gguf|100")
    MODELS+=("qwen3.5|Qwen3.5-122B-A10B-MXFP4_MOE-00002-of-00003.gguf|unsloth/Qwen3.5-122B-A10B-GGUF|Qwen3.5-122B-A10B-MXFP4_MOE-00002-of-00003.gguf|42000")
    MODELS+=("qwen3.5|Qwen3.5-122B-A10B-MXFP4_MOE-00003-of-00003.gguf|unsloth/Qwen3.5-122B-A10B-GGUF|Qwen3.5-122B-A10B-MXFP4_MOE-00003-of-00003.gguf|15000")
    MODELS+=("qwen|Qwen3-Coder-Next-MXFP4_MOE.gguf|unsloth/Qwen3-Coder-Next-GGUF|Qwen3-Coder-Next-MXFP4_MOE.gguf|28000")
    ;;
  128gb-multi)
    MODELS+=("qwen3.5|Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf|unsloth/Qwen3.5-35B-A3B-GGUF|Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf|15000")
    MODELS+=("qwen3.5|Qwen3.5-27B-UD-Q4_K_XL.gguf|unsloth/Qwen3.5-27B-GGUF|Qwen3.5-27B-UD-Q4_K_XL.gguf|12000")
    MODELS+=("qwen3.5|Qwen3.5-9B-UD-Q4_K_XL.gguf|unsloth/Qwen3.5-9B-GGUF|Qwen3.5-9B-UD-Q4_K_XL.gguf|5000")
    MODELS+=("qwen|Qwen3-Coder-Next-MXFP4_MOE.gguf|unsloth/Qwen3-Coder-Next-GGUF|Qwen3-Coder-Next-MXFP4_MOE.gguf|28000")
    ;;
  128gb-minimax)
    MINIMAX_REPO="${MINIMAX_REPO:-unsloth/MiniMax-M2.5-GGUF}"
    MINIMAX_FILES="${MINIMAX_FILES:-MiniMax-M2.5-UD-Q3_K_XL-00001-of-00004.gguf,MiniMax-M2.5-UD-Q3_K_XL-00002-of-00004.gguf,MiniMax-M2.5-UD-Q3_K_XL-00003-of-00004.gguf,MiniMax-M2.5-UD-Q3_K_XL-00004-of-00004.gguf}"
    IFS=',' read -r -a MINI_FILES <<< "$MINIMAX_FILES"
    for mf in "${MINI_FILES[@]}"; do
      case "$mf" in
        *00001-of-00004.gguf) min_mb=5 ;;
        *00002-of-00004.gguf) min_mb=42000 ;;
        *00003-of-00004.gguf) min_mb=42000 ;;
        *00004-of-00004.gguf) min_mb=1000 ;;
        *) min_mb=1000 ;;
      esac
      MODELS+=("minimax|$mf|$MINIMAX_REPO|$mf|$min_mb")
    done
    MODELS+=("qwen|Qwen3-Coder-Next-MXFP4_MOE.gguf|unsloth/Qwen3-Coder-Next-GGUF|Qwen3-Coder-Next-MXFP4_MOE.gguf|28000")
    ;;
  gemma-16gb)
    MODELS+=("gemma4|gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf|unsloth/gemma-4-26B-A4B-IT-GGUF|gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf|15000")
    MODELS+=("gemma4|gemma-4-E4B-IT-Q8_0.gguf|unsloth/gemma-4-E4B-IT-GGUF|gemma-4-E4B-IT-Q8_0.gguf|4000")
    ;;
  gemma-24gb)
    MODELS+=("gemma4|gemma-4-31B-IT-UD-Q4_K_XL.gguf|unsloth/gemma-4-31B-IT-GGUF|gemma-4-31B-IT-UD-Q4_K_XL.gguf|16000")
    MODELS+=("gemma4|gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf|unsloth/gemma-4-26B-A4B-IT-GGUF|gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf|15000")
    ;;
  gemma-32gb)
    MODELS+=("gemma4|gemma-4-31B-IT-Q8_0.gguf|unsloth/gemma-4-31B-IT-GGUF|gemma-4-31B-IT-Q8_0.gguf|32000")
    MODELS+=("gemma4|gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf|unsloth/gemma-4-26B-A4B-IT-GGUF|gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf|15000")
    ;;
  gemma-64gb)
    MODELS+=("gemma4|gemma-4-31B-IT-BF16.gguf|unsloth/gemma-4-31B-IT-GGUF|gemma-4-31B-IT-BF16.gguf|60000")
    MODELS+=("gemma4|gemma-4-31B-IT-Q8_0.gguf|unsloth/gemma-4-31B-IT-GGUF|gemma-4-31B-IT-Q8_0.gguf|32000")
    MODELS+=("gemma4|gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf|unsloth/gemma-4-26B-A4B-IT-GGUF|gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf|15000")
    ;;
  openrouter)
    echo "Profile: openrouter"
    echo "No local model downloads are required for the cloud-only openrouter profile."
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

  if [[ -f "$target_file" ]]; then
    local size_mb
    size_mb="$(du -m "$target_file" | awk '{print $1}')"
    if [[ "$size_mb" -ge "$min_mb" ]]; then
      echo "[skip] $target_file (${size_mb}MB)"
      return
    fi
    echo "[warn] $target_file too small (${size_mb}MB < ${min_mb}MB), re-downloading"
    rm -f "$target_file"
  fi

  # Fetch expected file size from Hugging Face for validation
  local expected_bytes
  expected_bytes="$(curl -sI -L --max-redirs 3 "$url" 2>/dev/null | grep -i 'content-length' | tail -1 | awk '{print $2}' | tr -d '\r')"
  local expected_mb=0
  if [[ -n "$expected_bytes" && "$expected_bytes" -gt 0 ]] 2>/dev/null; then
    expected_mb=$(( expected_bytes / 1048576 ))
  fi

  echo "[get ] $url"
  if ! curl -fL --retry 3 --retry-delay 3 --retry-max-time 300 -C - -o "$tmp_file" "$url"; then
    echo "[fail] Download failed: $url" >&2
    rm -f "$tmp_file"
    exit 1
  fi
  mv "$tmp_file" "$target_file"

  local new_mb
  new_mb="$(du -m "$target_file" | awk '{print $1}')"
  if [[ "$new_mb" -lt "$min_mb" ]]; then
    echo "Download too small for $filename (${new_mb}MB < ${min_mb}MB)" >&2
    rm -f "$target_file"
    exit 1
  fi
  if [[ "$expected_mb" -gt 0 && "$new_mb" -lt $(( expected_mb * 95 / 100 )) ]]; then
    echo "Download incomplete for $filename (${new_mb}MB vs expected ~${expected_mb}MB)" >&2
    rm -f "$target_file"
    exit 1
  fi
  echo "[ ok ] $target_file (${new_mb}MB${expected_mb:+ of ~${expected_mb}MB})"
}

echo "Profile: $PROFILE"
echo "Models dir: $AI_MODELS_DIR"

for item in "${MODELS[@]}"; do
  IFS='|' read -r subdir filename repo remote min_mb <<< "$item"
  download_one "$subdir" "$filename" "$repo" "$remote" "$min_mb"
done

echo "Done."
