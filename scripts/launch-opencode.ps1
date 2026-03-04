$ErrorActionPreference = 'Stop'
$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$Config = Join-Path $Root 'opencode.jsonc'
$env:OPENCODE_CONFIG = $Config
opencode
