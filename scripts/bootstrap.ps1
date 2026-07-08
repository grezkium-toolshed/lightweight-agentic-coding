#requires -version 5
$ErrorActionPreference = "Continue"

# lac bootstrap (Windows) — best-effort. Windows is a SECONDARY platform for lac; macOS
# (Apple Silicon) is the primary, tested target. Some steps below may need WSL or manual
# follow-up. Idempotent: re-running skips anything already installed.
#
# Install commands mirror src/lac/doctor.py `_install_hint()` (windows entries).

$Root = Split-Path -Parent $PSScriptRoot
function Have($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Info($msg) { Write-Host "[bootstrap] $msg" -ForegroundColor Blue }
function Warn($msg) { Write-Host "[bootstrap] $msg" -ForegroundColor Yellow }

Warn "Windows is a secondary platform for lac. If this stalls, WSL2 + the shell bootstrap"
Warn "(./scripts/bootstrap.sh) is the smoother path. macOS/Apple Silicon is where lac runs best."

# 1. Python 3.10+
if ((Have "py") -or (Have "python")) {
  Info "Python present - skipping (ensure it is 3.10+)."
} else {
  Info "Installing Python via winget..."
  winget install --id Python.Python.3.12 -e --source winget
}

# 2. llama.cpp
if (Have "llama-server") {
  Info "llama.cpp present - skipping."
} else {
  Info "Installing llama.cpp via winget (or download a release and add llama-server.exe to PATH)..."
  winget install llama.cpp 2>$null
}

# 3. OpenCode
if (Have "opencode") {
  Info "OpenCode present - skipping."
} elseif (Have "npm") {
  Info "Installing OpenCode via npm..."
  npm install -g opencode-ai
} else {
  Warn "npm not found - install Node.js 18+, then: npm install -g opencode-ai"
}

# 4. OpenChamber (best-effort; its installer is a bash script - needs WSL/Git Bash on Windows)
if (Have "openchamber") {
  Info "OpenChamber present - skipping."
} else {
  Warn "OpenChamber's installer is a bash script. Install it via WSL/Git Bash, or use the"
  Warn "OpenCode CLI instead. See https://github.com/openchamber/openchamber"
}

# 5. Install lac
if (Have "pipx") {
  Info "Installing lac via pipx..."
  pipx install --force "$Root"
} else {
  Info "Installing lac via pip (consider pipx for isolation)..."
  py -3 -m pip install "$Root"
}

# 6. First run
Info "Starting your private local assistant (downloads a ~2.5 GB model on first run)..."
& "$Root/bin/lac.ps1" demo --local --yes

Write-Host ""
Info "If OpenChamber isn't available, open the coding agent instead: lac client open opencode"
Info "For a hardware-matched setup: lac init  ->  lac models sync <profile>  ->  lac runtime start"
