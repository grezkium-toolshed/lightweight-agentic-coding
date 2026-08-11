#!/bin/bash
set -uo pipefail

# lac bootstrap — a clean-checkout path to a running private, on-device AI assistant.
#
# macOS-first (Apple Silicon is the primary target). Re-running is safe: valid prerequisites and
# model weights are reused, while lac itself and validation may run again. YOU run this yourself — it installs developer tools (Homebrew,
# llama.cpp, OpenCode, OpenChamber) and downloads a small model. With the generated local profile,
# prompts and work content stay local; installation and first plugin use require network access.
#
# Keep install guidance aligned with the read-only hints in src/lac/cli.py.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCODE_VERSION="1.17.18"
OPENCHAMBER_VERSION="1.16.3"

info() { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[bootstrap]\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }
check_version() {
  local command="$1"
  local expected="$2"
  local align_command="$3"
  local actual
  actual="$("$command" --version 2>/dev/null || true)"
  if [[ "$actual" == *"$expected"* ]]; then
    info "$command $expected matches the v0.3 validation set."
  else
    warn "$command is installed but reports '${actual:-unknown}', not the v0.3-tested $expected."
    warn "lac will not replace it automatically. To align manually: $align_command"
  fi
}
find_python() {
  local candidate
  for candidate in "${PYTHON:-}" python3.14 python3.13 python3.12 python3.11 python3.10 python3; do
    [[ -n "$candidate" ]] || continue
    have "$candidate" || continue
    if "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}
node_22_plus() {
  have node && node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 22 ? 0 : 1)' >/dev/null 2>&1
}
configure_pnpm_path() {
  have pnpm || return 0
  if [[ -z "${PNPM_HOME:-}" ]]; then
    if [[ "$OS" == "Darwin" ]]; then
      PNPM_HOME="$HOME/Library/pnpm"
    else
      PNPM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm"
    fi
  fi
  export PNPM_HOME
  mkdir -p "$PNPM_HOME" "$PNPM_HOME/bin" || return 1
  export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH"
}

# Upstream installers commonly place commands here, but a newly installed shell has not
# reloaded its profile yet.
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.openchamber/bin:$PATH"

OS="$(uname -s)"
if [[ "$OS" != "Darwin" ]]; then
  warn "This bootstrap is tuned for macOS (Apple Silicon), where lac runs best."
  warn "Linux is experimental and test-at-your-own-risk. Install llama.cpp + opencode + python 3.10+ yourself, then run:"
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
PYTHON_BIN="$(find_python || true)"
if [[ -n "$PYTHON_BIN" ]]; then
  info "Python 3.10+ present ($PYTHON_BIN) — skipping."
elif [[ "$OS" == "Darwin" ]] && have brew; then
  info "Installing Python via Homebrew..."
  brew install python || warn "Python install failed."
  hash -r
  PYTHON_BIN="$(find_python || true)"
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
  check_version opencode "$OPENCODE_VERSION" \
    "curl -fsSL https://opencode.ai/install | bash -s -- --version $OPENCODE_VERSION"
else
  info "Installing OpenCode $OPENCODE_VERSION..."
  curl -fsSL https://opencode.ai/install | bash -s -- --version "$OPENCODE_VERSION" \
    || warn "OpenCode install failed."
fi

# The upstream project recommends its Homebrew tap on macOS. If the hosted
# installer cannot resolve a release, use that independent official path before
# falling back to npm later in this script.
if ! have opencode && [[ "$OS" == "Darwin" ]] && have brew; then
  info "Retrying OpenCode installation through the official Homebrew tap..."
  brew install anomalyco/tap/opencode || brew install opencode || warn "OpenCode Homebrew fallback failed."
  hash -r
fi

# 5. OpenChamber prerequisites and chat UI. OpenCode remains the supported fallback.
if ! node_22_plus || ! have pnpm; then
  if [[ "$OS" == "Darwin" ]] && have brew; then
    info "Installing Node.js 22+ and pnpm for OpenChamber..."
    node_22_plus || brew install node || warn "Node.js install failed."
    have pnpm || brew install pnpm || warn "pnpm install failed."
    hash -r
  else
    warn "OpenChamber needs Node.js 22+ and pnpm; install them to use the chat UI."
  fi
fi
configure_pnpm_path || warn "Could not initialize pnpm's global bin directory."

# The upstream OpenCode installer occasionally fails before downloading a binary. Once npm is
# available for OpenChamber, use the same package fallback as the Windows bootstrap.
if ! have opencode && have npm; then
  info "Retrying OpenCode installation via npm..."
  npm install -g "opencode-ai@$OPENCODE_VERSION" || warn "OpenCode npm fallback failed."
  hash -r
fi

if have openchamber; then
  check_version openchamber "$OPENCHAMBER_VERSION" \
    "pnpm add -g @openchamber/web@$OPENCHAMBER_VERSION"
elif ! node_22_plus || ! have pnpm; then
  warn "Skipping OpenChamber because Node.js 22+ or pnpm is unavailable. OpenCode will be used."
else
  info "Installing OpenChamber $OPENCHAMBER_VERSION..."
  pnpm add -g "@openchamber/web@$OPENCHAMBER_VERSION" \
    || warn "OpenChamber install failed — you can still use the OpenCode CLI (see next steps)."
fi

# 6. Install lac itself as a global command (isolated via pipx; falls back to ./bin/lac).
if ! have pipx; then
  info "Installing pipx (isolated Python-CLI installer)..."
  if [[ "$OS" == "Darwin" ]] && have brew; then
    if ! brew install pipx >/dev/null 2>&1 && [[ -n "$PYTHON_BIN" ]]; then
      "$PYTHON_BIN" -m pip install --user pipx >/dev/null 2>&1 || true
    fi
  elif [[ -n "$PYTHON_BIN" ]]; then
    "$PYTHON_BIN" -m pip install --user pipx >/dev/null 2>&1 || true
  fi
  have pipx && pipx ensurepath >/dev/null 2>&1 || true
fi
LAC_INSTALLED=0
if have pipx; then
  info "Installing lac (global 'lac' command)..."
  if pipx install --force "$ROOT" >/dev/null 2>&1; then
    LAC_INSTALLED=1
    hash -r
  else
    warn "pipx install of lac failed — using ./bin/lac instead."
  fi
else
  warn "pipx unavailable — lac is still runnable from this checkout as ./bin/lac."
fi

if [[ "$LAC_INSTALLED" -eq 1 ]] && have lac; then
  LAC_COMMAND=(lac)
  info "Using the installed lac command for setup and first run."
else
  LAC_COMMAND=("$ROOT/bin/lac")
  warn "Using the checkout wrapper for setup and first run."
fi

# Both command paths must resolve the same per-user mutable roots. Print them before
# downloading or starting anything so recovery instructions have an exact location.
LAC_BOOTSTRAP_DOCTOR_JSON="$("${LAC_COMMAND[@]}" doctor --json 2>/dev/null || true)"
if [[ -n "$LAC_BOOTSTRAP_DOCTOR_JSON" && -n "$PYTHON_BIN" ]]; then
  export LAC_BOOTSTRAP_DOCTOR_JSON
  LAC_BOOTSTRAP_ROOTS="$("$PYTHON_BIN" -c 'import json, os; p=json.loads(os.environ["LAC_BOOTSTRAP_DOCTOR_JSON"])["paths"]; print(p["state_root"] + "\n" + p["models_root"])' 2>/dev/null || true)"
  if [[ -n "$LAC_BOOTSTRAP_ROOTS" ]]; then
    info "Resolved state root: $(printf '%s\n' "$LAC_BOOTSTRAP_ROOTS" | sed -n '1p')"
    info "Resolved models root: $(printf '%s\n' "$LAC_BOOTSTRAP_ROOTS" | sed -n '2p')"
  fi
  unset LAC_BOOTSTRAP_DOCTOR_JSON
fi

if [[ -f "$ROOT/state/active/profile.txt" ]]; then
  warn "Legacy checkout-local state exists at $ROOT/state; it is no longer selected automatically."
  warn "Reapply the profile with 'lac profile apply <profile>', or set LAC_STATE_ROOT deliberately to reuse it."
fi
if find "$ROOT/models" -type f -name '*.gguf' -print -quit 2>/dev/null | grep -q .; then
  warn "Legacy checkout-local model weights exist at $ROOT/models; they are not moved automatically."
  warn "Set AI_MODELS_DIR='$ROOT/models' to reuse them, or sync into the resolved models root."
fi

# 7. Instant first run: small 4B model, local runtime, open the chat UI.
if [[ -n "${LAC_BOOTSTRAP_SKIP_DEMO:-}" ]]; then
  info "LAC_BOOTSTRAP_SKIP_DEMO set — skipping the first run (install-only mode for CI)."
  RUN_STATUS=0
else
  info "Starting your private local assistant (downloads a ~2.5 GB model on first run)..."
  "${LAC_COMMAND[@]}" demo --local --yes
  RUN_STATUS=$?
fi

# 8. What next.
echo ""
if [[ "$RUN_STATUS" -eq 0 ]] && have openchamber; then
  info "Done. OpenChamber is available. Reruns reuse a healthy lac-managed web session."
  info "Run 'lac ports show --json' for the effective local URL."
elif [[ "$RUN_STATUS" -eq 0 ]] && have opencode; then
  info "Done. OpenCode was launched because OpenChamber is unavailable."
else
  warn "First run didn't complete cleanly. Diagnose with: ${LAC_COMMAND[*]} doctor"
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
