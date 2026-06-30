$ErrorActionPreference = 'Stop'

# Repo-local dev wrapper: runs from source tree.
# After `pip install`, users can just run `lac` directly.
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Src = Join-Path $Root 'src'
if ($env:PYTHONPATH) {
  $env:PYTHONPATH = "$Src;$env:PYTHONPATH"
} else {
  $env:PYTHONPATH = $Src
}

function Test-LacPython {
  param([string]$Command)
  if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
    return $false
  }
  & $Command -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)" *> $null
  return $LASTEXITCODE -eq 0
}

if ($env:PYTHON -and (Test-LacPython $env:PYTHON)) {
  & $env:PYTHON -m lac @args
  exit $LASTEXITCODE
}

foreach ($Candidate in @('python3.14', 'python3.13', 'python3.12', 'python3.11', 'python3.10', 'python3', 'python')) {
  if (Test-LacPython $Candidate) {
    & $Candidate -m lac @args
    exit $LASTEXITCODE
  }
}

if (Get-Command py -ErrorAction SilentlyContinue) {
  & py -3 -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)" *> $null
  if ($LASTEXITCODE -eq 0) {
    & py -3 -m lac @args
    exit $LASTEXITCODE
  }
}

throw 'Python 3.10+ is required to run lac. Install Python 3.10 or newer, or set PYTHON to a compatible interpreter.'
