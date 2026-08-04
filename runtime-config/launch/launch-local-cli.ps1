$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$Lac = if (Get-Command lac -ErrorAction SilentlyContinue) { 'lac' } else { Join-Path $Root 'bin/lac.ps1' }
if (-not (Get-Command $Lac -ErrorAction SilentlyContinue) -and -not (Test-Path $Lac)) {
  throw 'lac is not installed and the repo-local bin/lac.ps1 wrapper was not found.'
}
& $Lac runtime start
& $Lac client open opencode
