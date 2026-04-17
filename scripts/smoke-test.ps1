$ErrorActionPreference = 'Stop'
$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$argsList = @('smoke')

if ($env:SMOKE_TIMEOUT) {
  $argsList += '--timeout'
  $argsList += $env:SMOKE_TIMEOUT
}

& (Join-Path $Root 'bin/lac.ps1') @argsList
exit $LASTEXITCODE
