#!/bin/bash
set -uo pipefail

# lac bootstrap — one command from nothing to a running private, on-device AI assistant.
#
# macOS-first (Apple Silicon is the primary target). Idempotent: re-running is safe and skips
# anything already installed. YOU run this yourself — it installs developer tools (Homebrew,
# llama.cpp, OpenCode, OpenChamber) and downloads a small model. Nothing leaves your machine.
#
# Install commands here mirror src/lac/doctor.py `_install_hint()` (the one source of truth).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

info() { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[bootstrap]\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

OS="$(uname -s)"
if [[ "$OS" != "Darwin" ]]; then
  warn "This bootstrap is tuned for macOS (Apple Silicon), where lac runs best."
  warn "On Linux, install llama.cpp + opencode + python 3.10+ yourself, then run:"
  warn "    ./bin/lac demo --local"
  warn "Continuing best-effort; some steps below may be skipped."
fi

# 1. Homebrew — the macOS package manager the other installs rely on.
if [[ "$OS" == "Darwin" ]]; then
  if have brew; then
    info "Homebrew present — skipping."
  else
    info "Installing Homebrew (you may be prompted for your password)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || warn "Homebrew install failed."
    [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
    [[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# 2. Python 3.10+ (needed to run lac).
if have python3 && python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)'; then
  info "Python 3.10+ present — skipping."
elif [[ "$OS" == "Darwin" ]] && have brew; then
  info "Installing Python via Homebrew..."
  brew install python || warn "Python install failed."
else
  warn "Python 3.10+ not found and can't auto-install on this platform. Install it, then re-run."
fi

# 3. llama.cpp (the local inference runtime).
if have llama-server; then
  info "llama.cpp present — skipping."
elif [[ "$OS" == "Darwin" ]] && have brew; then
  info "Installing llama.cpp via Homebrew..."
  brew install llama.cpp || warn "llama.cpp install failed."
else
  warn "llama-server not found. See README for building llama.cpp on your platform."
fi

# 4. OpenCode (the agent runtime OpenChamber talks to).
if have opencode; then
  info "OpenCode present — skipping."
else
  info "Installing OpenCode..."
  curl -fsSL https://opencode.ai/install | bash || warn "OpenCode install failed."
fi

# 5. OpenChamber (the chat UI — your front door). Best-effort; OpenCode alone still works.
if have openchamber; then
  info "OpenChamber present — skipping."
else
  info "Installing OpenChamber..."
  curl -fsSL https://raw.githubusercontent.com/openchamber/openchamber/main/scripts/install.sh | bash \
    || warn "OpenChamber install failed — you can still use the OpenCode CLI (see next steps)."
fi

# 6. Install lac itself as a global command (isolated via pipx; falls back to ./bin/lac).
if ! have pipx; then
  info "Installing pipx (isolated Python-CLI installer)..."
  if [[ "$OS" == "Darwin" ]] && have brew; then
    brew install pipx >/dev/null 2>&1 || python3 -m pip install --user pipx >/dev/null 2>&1 || true
  else
    python3 -m pip install --user pipx >/dev/null 2>&1 || true
  fi
  have pipx && pipx ensurepath >/dev/null 2>&1 || true
fi
if have pipx; then
  info "Installing lac (global 'lac' command)..."
  pipx install --force "$ROOT" >/dev/null 2>&1 || warn "pipx install of lac failed — using ./bin/lac instead."
else
  warn "pipx unavailable — lac is still runnable from this checkout as ./bin/lac."
fi

# 7. Instant first run: small 4B model, local runtime, open the chat UI.
info "Starting your private local assistant (downloads a ~2.5 GB model on first run)..."
"$ROOT/bin/lac" demo --local --yes
RUN_STATUS=$?

# 8. What next.
echo ""
if [[ "$RUN_STATUS" -eq 0 ]]; then
  info "Done. OpenChamber should be open at http://localhost:3000"
else
  warn "First run didn't complete cleanly. Diagnose with: ./bin/lac doctor"
fi
cat <<'NEXT'

You're running a small 4B model — instant, and enough to try proofreading, drafting, and
small edits privately on your own machine. For a setup matched to your hardware:

    lac init                     # detects your RAM and recommends a profile
    lac models sync <profile>    # e.g. macos-16gb, 24gb
    lac runtime start
    lac client open openchamber  # the chat UI  (or: lac client open opencode)

On Apple Silicon this is genuinely fast. On a CPU-only laptop it works but is slower — best
for short single-shot tasks, not heavy multi-step automation. See the README for what to expect.
NEXT
