$ErrorActionPreference = 'Stop'

# Repo-local dev wrapper: runs from source tree.
# After `pip install`, users can just run `lac` directly.
if (Get-Command python3 -ErrorAction SilentlyContinue) {
  & python3 -m lac @args
  exit $LASTEXITCODE
}

if (Get-Command python -ErrorAction SilentlyContinue) {
  & python -m lac @args
  exit $LASTEXITCODE
}

if (Get-Command py -ErrorAction SilentlyContinue) {
  & py -m lac @args
  exit $LASTEXITCODE
}

throw 'Python 3 is required to run lac'
