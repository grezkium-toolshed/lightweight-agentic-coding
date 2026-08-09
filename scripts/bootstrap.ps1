#requires -version 5
$ErrorActionPreference = 'Stop'

# Native Windows is an experimental, manually provisioned preview. This script deliberately
# does not install GPU runtimes or clients: those choices are hardware- and privacy-sensitive.

$Root = Split-Path -Parent $PSScriptRoot
$OpenCodeVersion = '1.17.18'

function Have($Command) {
  return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Info($Message) {
  Write-Host "[bootstrap] $Message" -ForegroundColor Blue
}

function Warn($Message) {
  Write-Host "[bootstrap] $Message" -ForegroundColor Yellow
}

function Test-Python310($Command) {
  if (-not (Have $Command)) { return $false }
  if ($Command -eq 'py') {
    & py -3 -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)" *> $null
  } else {
    & $Command -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)" *> $null
  }
  return $LASTEXITCODE -eq 0
}

Warn 'Native Windows is experimental and has no physical-runtime support guarantee.'
Warn 'For local models, WSL2 is the preferred experimental Windows route.'

$Python = @('py', 'python', 'python3') | Where-Object { Test-Python310 $_ } | Select-Object -First 1
$Missing = @()
if (-not $Python) { $Missing += 'Python 3.10+' }
if (-not (Have 'llama-server')) { $Missing += 'llama-server.exe on PATH' }
if (-not (Have 'opencode')) { $Missing += 'OpenCode on PATH' }

if ($Missing.Count -gt 0) {
  Warn "Native local preview cannot start; missing: $($Missing -join ', ')."
  Write-Host ''
  Info 'Local models (preferred Windows route): install WSL2, keep the repo in the WSL filesystem, and follow docs/WINDOWS.md.'
  Info 'Native local preview: install Python, an official llama.cpp Windows build, and OpenCode, then re-run this script.'
  Info 'Cloud alternative: install OpenChamber Desktop and connect OpenCode Go or Zen. This sends work to a hosted provider.'
  Info 'Guide: docs/WINDOWS.md'
  exit 1
}

$InstalledOpenCode = (& opencode --version 2>$null | Out-String).Trim()
if ($InstalledOpenCode -notlike "*$OpenCodeVersion*") {
  Warn "OpenCode reports '$InstalledOpenCode', not the v0.3-tested $OpenCodeVersion."
  Warn "lac will not replace it automatically. To align manually: npm install -g opencode-ai@$OpenCodeVersion"
}

if (Have 'pipx') {
  Info 'Installing or updating lac with pipx...'
  & pipx install --force $Root
  if ($LASTEXITCODE -ne 0) {
    throw "pipx install failed with exit code $LASTEXITCODE"
  }
} else {
  Warn 'pipx is unavailable; using the repo-local bin/lac.ps1 wrapper without a global install.'
}

Info 'All native-local prerequisites are visible. Starting the micro-profile demo...'
& "$Root/bin/lac.ps1" demo --local --yes
if ($LASTEXITCODE -ne 0) {
  throw "lac demo failed with exit code $LASTEXITCODE"
}

Info 'Done. Native Windows remains experimental; report reproducible results with lac doctor --json.'
