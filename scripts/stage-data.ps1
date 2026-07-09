#requires -version 5
$ErrorActionPreference = "Stop"

# Regenerate src/lac/data/ from the canonical top-level trees.
# Thin wrapper over the portable Python stager (see scripts/stage_data.py).
$Root = Split-Path -Parent $PSScriptRoot
if ($env:PYTHON) {
  & $env:PYTHON "$Root/scripts/stage_data.py"
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
  & py -3 "$Root/scripts/stage_data.py"
} else {
  & python "$Root/scripts/stage_data.py"
}
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
