param(
  [Parameter(Mandatory=$true)][string]$Profile
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir 'setup-config-device.ps1') -Profile $Profile
