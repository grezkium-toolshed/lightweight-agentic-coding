param(
  [switch]$Strict,
  [switch]$BootstrapHint
)

$ErrorActionPreference = 'Stop'
$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$argsList = @('doctor')
if ($Strict) { $argsList += '--strict' }
if ($BootstrapHint) { $argsList += '--bootstrap-hint' }

& (Join-Path $Root 'bin/lac.ps1') @argsList
exit $LASTEXITCODE
