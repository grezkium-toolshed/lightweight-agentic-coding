param(
  [switch]$ShowLogs,
  [switch]$NoTailHint
)

$ErrorActionPreference = 'Stop'
$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$Port = if ($env:AI_CLUSTER_PORT) { $env:AI_CLUSTER_PORT } else { '8080' }
$Preset = Join-Path $Root 'runtime-config/presets.active.ini'
$ManifestPath = Join-Path $Root 'runtime-config/profiles.json'
$ActiveProfilePath = Join-Path $Root 'runtime-config/active-profile.txt'
$LlamaBin = if ($env:LLAMA_SERVER_BIN) { $env:LLAMA_SERVER_BIN } else { 'llama-server.exe' }
$LogDir = Join-Path $Root 'runtime-config/logs'
$LogFile = Join-Path $LogDir 'llama-server.log'
$TailHint = -not $NoTailHint

if (-not (Test-Path $Preset)) { throw "Missing preset file: $Preset" }
if ((Test-Path $ActiveProfilePath) -and (Test-Path $ManifestPath)) {
  $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
  $activeProfile = (Get-Content $ActiveProfilePath -Raw).Trim()
  $profileData = $manifest.profiles.$activeProfile
  if ($profileData -and $profileData.runtime_mode -eq 'cloud') {
    Write-Host "Active profile '$activeProfile' is cloud-only; no local llama-server launch is required."
    Write-Host 'Use scripts/launch-opencode.ps1 after setup-config-device.'
    exit 0
  }
}
if (-not (Get-Command $LlamaBin -ErrorAction SilentlyContinue)) {
  throw "llama-server executable not found: $LlamaBin"
}
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
if (Test-Path $LogFile) {
  Move-Item -Force $LogFile "$LogFile.1"
}

$existing = Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue
if ($existing) {
  Write-Host "llama-server appears to be already running."
  Write-Host "Log file: $LogFile"
  if ($TailHint) {
    Write-Host "Tail logs: Get-Content `"$LogFile`" -Wait -Tail 50"
  }
  exit 0
}

$llamaCmd = "`"$LlamaBin`" --models-preset `"$Preset`" --host 127.0.0.1 --port $Port >> `"$LogFile`" 2>&1"
Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', $llamaCmd) -WindowStyle Hidden | Out-Null

for ($i=0; $i -lt 60; $i++) {
  try {
    Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2 | Out-Null
    Write-Host "llama-server ready at http://127.0.0.1:$Port"
    Write-Host "Log file: $LogFile"
    if ($TailHint) {
      Write-Host "Tail logs: Get-Content `"$LogFile`" -Wait -Tail 50"
    }
    if ($ShowLogs) {
      Get-Content $LogFile -Wait -Tail 50
    }
    exit 0
  } catch {
    Start-Sleep -Seconds 1
  }
}

Write-Host 'llama-server failed to start within timeout'
if (Test-Path $LogFile) {
  Write-Host 'Recent logs:'
  Get-Content $LogFile -Tail 40
  Write-Host "Full log: $LogFile"
}
exit 1
