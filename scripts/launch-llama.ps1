$ErrorActionPreference = 'Stop'
$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$Port = if ($env:AI_CLUSTER_PORT) { $env:AI_CLUSTER_PORT } else { '8080' }
$Preset = Join-Path $Root 'runtime-config/presets.active.ini'
$LlamaBin = if ($env:LLAMA_SERVER_BIN) { $env:LLAMA_SERVER_BIN } else { 'llama-server.exe' }

if (-not (Test-Path $Preset)) { throw "Missing preset file: $Preset" }
Start-Process -FilePath $LlamaBin -ArgumentList @('--models-preset', $Preset, '--host', '127.0.0.1', '--port', $Port)

for ($i=0; $i -lt 60; $i++) {
  try {
    Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2 | Out-Null
    Write-Host "llama-server ready at http://127.0.0.1:$Port"
    exit 0
  } catch {
    Start-Sleep -Seconds 1
  }
}
throw 'llama-server failed to start within timeout'
