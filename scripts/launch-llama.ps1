param(
  [switch]$ShowLogs,
  [switch]$NoTailHint
)

$ErrorActionPreference = 'Stop'
$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
& (Join-Path $Root 'bin/lac.ps1') runtime start @args
exit $LASTEXITCODE
