param(
  [switch]$Foreground,
  [switch]$ShowLogs,
  [switch]$NoTailHint
)

$ErrorActionPreference = 'Stop'
$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$forward = @('runtime', 'start')
if ($Foreground) { $forward += '--foreground' }
if ($ShowLogs) { $forward += '--show-logs' }
if ($NoTailHint) { $forward += '--no-tail-hint' }
$forward += $args
& (Join-Path $Root 'bin/lac.ps1') @forward
exit $LASTEXITCODE
