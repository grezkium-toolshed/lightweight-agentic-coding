$ErrorActionPreference = 'Stop'
$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$Config = if ($env:OPENCODE_CONFIG_PATH) { $env:OPENCODE_CONFIG_PATH } else { Join-Path $Root 'opencode.jsonc' }
$App = if ($env:OPENCODE_DESKTOP_APP) { $env:OPENCODE_DESKTOP_APP } else { 'OpenCode' }

$env:OPENCODE_CONFIG = $Config
Start-Process $App
Write-Host "Launched desktop app: $App"
Write-Host "Using OPENCODE_CONFIG=$Config"
