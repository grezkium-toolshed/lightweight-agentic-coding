#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USAGE="Usage: $0 <user@host> [remote_port] [local_port]

Create a persistent SSH tunnel to a remote llama-server instance.
This forwards remote_port (default 8080) to localhost:local_port (default 8080),
making a cloud GPU's llama-server appear as a local runtime.

Prerequisites: autossh (brew install autossh / apt install autossh)

Examples:
  $0 ubuntu@123.456.78.90
  $0 ubuntu@my-runpod-instance 8080 8080
  $0 --setup ubuntu@my-runpod-instance    # one-time: install llama-server on remote
"

SETUP=false
if [[ "${1:-}" == "--setup" ]]; then
  SETUP=true
  shift
fi

HOST="${1:?$USAGE}"
REMOTE_PORT="${2:-8080}"
LOCAL_PORT="${3:-8080}"

if ! command -v autossh &>/dev/null; then
  echo "[!] autossh is required for reliable tunnels."
  echo "    Install it:"
  echo "      macOS: brew install autossh"
  echo "      Linux: sudo apt install autossh"
  exit 1
fi

if $SETUP; then
  echo "[setup] Installing llama-server on $HOST..."
  ssh "$HOST" bash -s <<'REMOTE'
    set -e
    if ! command -v llama-server &>/dev/null; then
      if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y build-essential cmake curl
      fi
      cd /tmp
      git clone --depth 1 https://github.com/ggml-org/llama.cpp
      cmake -B llama.cpp/build -S llama.cpp -DLLAMA_CURL=ON -DLLAMA_CUDA=ON
      cmake --build llama.cpp/build --config Release -j "$(nproc)"
      sudo cp llama.cpp/build/bin/llama-server /usr/local/bin/
      rm -rf /tmp/llama.cpp
    fi
    echo "llama-server ready: $(llama-server --version 2>&1 || true)"
REMOTE
  echo "[setup] Done. Start llama-server on the remote:"
  echo "  ssh $HOST 'llama-server -m /path/to/model.gguf --host 0.0.0.0 --port $REMOTE_PORT'"
  exit 0
fi

echo "[tunnel] Establishing tunnel: localhost:$LOCAL_PORT → $HOST:$REMOTE_PORT"
echo "[tunnel] Use this in another terminal:"
echo "  curl http://127.0.0.1:$LOCAL_PORT/health"
echo "  cd $ROOT && ./bin/lac smoke"

# Start the autossh tunnel
exec autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" \
  -o "ExitOnForwardFailure yes" -o "StrictHostKeyChecking accept-new" \
  -L "$LOCAL_PORT:127.0.0.1:$REMOTE_PORT" "$HOST"
