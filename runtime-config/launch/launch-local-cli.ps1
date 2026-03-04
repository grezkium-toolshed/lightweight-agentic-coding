$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
& (Join-Path $Root 'scripts/launch-llama.ps1')
& (Join-Path $Root 'scripts/launch-opencode.ps1')
