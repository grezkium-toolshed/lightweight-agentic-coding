$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

if (Get-Command python3 -ErrorAction SilentlyContinue) {
  & python3 (Join-Path $Root 'scripts/lac.py') @args
  exit $LASTEXITCODE
}

if (Get-Command python -ErrorAction SilentlyContinue) {
  & python (Join-Path $Root 'scripts/lac.py') @args
  exit $LASTEXITCODE
}

if (Get-Command py -ErrorAction SilentlyContinue) {
  & py -3 (Join-Path $Root 'scripts/lac.py') @args
  exit $LASTEXITCODE
}

throw 'Python 3 is required to run bin/lac.ps1'
