$ErrorActionPreference = 'Stop'
$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$Config = if ($env:OPENCODE_CONFIG_PATH) { $env:OPENCODE_CONFIG_PATH } else { Join-Path $Root 'runtime-config/opencode.active.json' }
$App = if ($env:OPENCODE_DESKTOP_APP) { $env:OPENCODE_DESKTOP_APP } else { 'OpenCode' }

if (-not (Test-Path $Config)) {
  throw "Missing generated OpenCode config: $Config`nRun scripts/setup-config-device.ps1 -Profile <profile> first."
}

$env:OPENCODE_CONFIG = $Config
Start-Process $App
Write-Host "Launched desktop app: $App"
Write-Host "Using OPENCODE_CONFIG=$Config"
