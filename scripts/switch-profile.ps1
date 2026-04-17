# Usage: ./switch-profile.ps1 -Profile <16gb|24gb|32gb|64gb|128gb-multi|128gb-qwen122b|128gb-minimax|gemma-16gb|gemma-24gb|gemma-32gb|gemma-64gb|openrouter>
param(
  [Parameter(Mandatory=$true)][string]$Profile
)

$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
& (Join-Path $Root 'bin/lac.ps1') profile apply $Profile
exit $LASTEXITCODE
