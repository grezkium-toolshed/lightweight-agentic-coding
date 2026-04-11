# Usage: ./switch-profile.ps1 -Profile <16gb|24gb|32gb|64gb|128gb-multi|128gb-qwen122b|128gb-minimax|gemma-16gb|gemma-24gb|gemma-32gb|gemma-64gb>
param(
  [Parameter(Mandatory=$true)][string]$Profile
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'setup-config-device.ps1') -Profile $Profile
