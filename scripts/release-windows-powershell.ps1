param(
  [string]$Profile = '24gb',
  [string]$EvidenceDir = '',
  [string]$StateRoot = '',
  [string]$ModelsDir = '',
  [string]$Python = '',
  [switch]$NoRuntime,
  [switch]$FullRuntime,
  [switch]$KeepTemp
)

$ErrorActionPreference = 'Stop'

function Get-UtcStamp {
  return (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
}

function Test-IsWindows {
  if (Get-Variable IsWindows -Scope Global -ErrorAction SilentlyContinue) {
    return $IsWindows
  }
  return $env:OS -eq 'Windows_NT'
}

function Invoke-Captured {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][scriptblock]$ScriptBlock,
    [switch]$AllowFailure
  )

  Add-Content -LiteralPath $script:CommandLog -Value "+ $Label"
  $global:LASTEXITCODE = 0
  $status = 0
  try {
    $output = & $ScriptBlock 2>&1
    $status = if ($null -ne $global:LASTEXITCODE) { [int]$global:LASTEXITCODE } else { 0 }
    $output | Out-File -LiteralPath $OutputPath -Encoding utf8
  } catch {
    $status = 1
    $_ | Out-String | Out-File -LiteralPath $OutputPath -Encoding utf8
  }
  Add-Content -LiteralPath $script:CommandLog -Value "exit $status"
  if ($status -ne 0 -and -not $AllowFailure) {
    throw "Command failed ($status): $Label"
  }
  return $status
}

if ($NoRuntime -and $FullRuntime) {
  throw 'Use either -NoRuntime or -FullRuntime, not both.'
}
if (-not $NoRuntime -and -not $FullRuntime) {
  $NoRuntime = $true
}
if (-not (Test-IsWindows)) {
  throw 'Windows release evidence must be captured on Windows. Use PowerShell on a fresh Windows clone.'
}

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Lac = Join-Path $Root 'bin/lac.ps1'
if (-not (Test-Path -LiteralPath $Lac)) {
  throw "Missing repo-local PowerShell wrapper: $Lac"
}

$Stamp = Get-UtcStamp
if (-not $EvidenceDir) {
  $EvidenceDir = Join-Path $Root "state/release-evidence/windows-powershell-$Stamp"
}
New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null

$script:CommandLog = Join-Path $EvidenceDir 'commands.log'
$Summary = Join-Path $EvidenceDir 'summary.md'
$Transcript = Join-Path $EvidenceDir 'transcript.txt'
$Scratch = Join-Path ([System.IO.Path]::GetTempPath()) "lac-windows-powershell-$Stamp"
New-Item -ItemType Directory -Force -Path $Scratch | Out-Null
if (-not $StateRoot) {
  $StateRoot = Join-Path $Scratch 'state'
}
if (-not $ModelsDir) {
  $ModelsDir = Join-Path $Scratch 'models'
}
New-Item -ItemType Directory -Force -Path $StateRoot | Out-Null
New-Item -ItemType Directory -Force -Path $ModelsDir | Out-Null

if ($Python) {
  $env:PYTHON = $Python
}
$env:LAC_STATE_ROOT = $StateRoot
$env:AI_MODELS_DIR = $ModelsDir

$Mode = if ($FullRuntime) { 'full runtime' } else { 'no-runtime rehearsal' }
Write-Host 'Windows PowerShell release evidence'
Write-Host "- Evidence directory: $EvidenceDir"
Write-Host "- State root: $StateRoot"
Write-Host "- Models dir: $ModelsDir"
Write-Host "- Profile: $Profile"
Write-Host "- Mode: $Mode"

$results = [ordered]@{}
Start-Transcript -Path $Transcript -Force | Out-Null
try {
  $results['date'] = Invoke-Captured 'Get-Date -AsUTC' (Join-Path $EvidenceDir 'date.txt') { Get-Date -AsUTC }
  $results['powershell-version'] = Invoke-Captured '$PSVersionTable' (Join-Path $EvidenceDir 'powershell-version.txt') { $PSVersionTable | Format-List * }
  $results['windows-version'] = Invoke-Captured 'Get-CimInstance Win32_OperatingSystem' (Join-Path $EvidenceDir 'windows-version.txt') { Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, OSArchitecture | Format-List * }
  $results['computer-system'] = Invoke-Captured 'Get-CimInstance Win32_ComputerSystem' (Join-Path $EvidenceDir 'computer-system.txt') { Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model, TotalPhysicalMemory | Format-List * }
  $results['python-version'] = Invoke-Captured 'py -3 --version' (Join-Path $EvidenceDir 'python-version.txt') { py -3 --version }
  $results['python-path'] = Invoke-Captured 'py -3 -c "import sys; print(sys.executable)"' (Join-Path $EvidenceDir 'python-path.txt') { py -3 -c 'import sys; print(sys.executable)' }
  $results['git-commit'] = Invoke-Captured 'git rev-parse HEAD' (Join-Path $EvidenceDir 'git-commit.txt') { git -C $Root rev-parse HEAD }
  $results['lac-version'] = Invoke-Captured '.\bin\lac.ps1 --version' (Join-Path $EvidenceDir 'lac-version.txt') { & $Lac --version }
  $results['lac-init'] = Invoke-Captured '.\bin\lac.ps1 init --yes --profile <profile> --no-cloud --json' (Join-Path $EvidenceDir 'init.json') { & $Lac init --yes --profile $Profile --no-cloud --json }
  $results['lac-doctor'] = Invoke-Captured '.\bin\lac.ps1 doctor --bootstrap-hint --json' (Join-Path $EvidenceDir 'doctor.json') { & $Lac doctor --bootstrap-hint --json }
  $results['lac-render-opencode'] = Invoke-Captured '.\bin\lac.ps1 client render opencode --json' (Join-Path $EvidenceDir 'render-opencode.json') { & $Lac client render opencode --json }

  if ($FullRuntime) {
    $results['lac-models-sync'] = Invoke-Captured '.\bin\lac.ps1 models sync <profile>' (Join-Path $EvidenceDir 'models-sync.log') { & $Lac models sync $Profile }
    $results['lac-runtime-start'] = Invoke-Captured '.\bin\lac.ps1 runtime start --json' (Join-Path $EvidenceDir 'runtime-start.json') { & $Lac runtime start --json }
    $results['lac-runtime-status'] = Invoke-Captured '.\bin\lac.ps1 runtime status --json' (Join-Path $EvidenceDir 'runtime-status.json') { & $Lac runtime status --json }
    $results['lac-smoke'] = Invoke-Captured '.\bin\lac.ps1 smoke --json' (Join-Path $EvidenceDir 'smoke.json') { & $Lac smoke --json }
  } else {
    @'
Full runtime validation was skipped.

Re-run on a fresh Windows clone with:

  pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/release-windows-powershell.ps1 -FullRuntime

That mode runs model sync, runtime start/status, and lac smoke.
'@ | Out-File -LiteralPath (Join-Path $EvidenceDir 'full-runtime-skipped.txt') -Encoding utf8
    $results['lac-smoke'] = Invoke-Captured '.\bin\lac.ps1 smoke --json' (Join-Path $EvidenceDir 'smoke.json') { & $Lac smoke --json } -AllowFailure
  }

  $resultLines = $results.GetEnumerator() | ForEach-Object { "- $($_.Key): exit $($_.Value)" }
  $capturedFiles = @(
    'commands.log',
    'transcript.txt',
    'date.txt',
    'powershell-version.txt',
    'windows-version.txt',
    'computer-system.txt',
    'python-version.txt',
    'python-path.txt',
    'git-commit.txt',
    'lac-version.txt',
    'init.json',
    'doctor.json',
    'render-opencode.json',
    'smoke.json'
  )
  if ($FullRuntime) {
    $capturedFiles += @('models-sync.log', 'runtime-start.json', 'runtime-status.json')
  } else {
    $capturedFiles += 'full-runtime-skipped.txt'
  }

  $body = @(
    '# Windows PowerShell Evidence Summary',
    '',
    '- Status: open',
    "- Mode: $Mode",
    "- Profile: $Profile",
    "- Evidence directory: $EvidenceDir",
    "- Transcript: $Transcript",
    "- State root: $StateRoot",
    "- Models dir: $ModelsDir",
    '',
    '## Command Results',
    ''
  ) + $resultLines + @(
    '',
    '## Captured Files',
    ''
  ) + ($capturedFiles | ForEach-Object { "- $_" }) + @(
    '',
    'Keep the `windows-powershell` manual gate open until this summary comes',
    'from a fresh Windows clone and the release tester records the evidence in',
    '`docs/release/MANUAL_VALIDATION.md`.',
    ''
  )
  $body | Out-File -LiteralPath $Summary -Encoding utf8
} finally {
  Stop-Transcript | Out-Null
  if (-not $KeepTemp) {
    Remove-Item -Recurse -Force -LiteralPath $Scratch -ErrorAction SilentlyContinue
  } else {
    Write-Host "Kept temp directory: $Scratch"
  }
}

Write-Host ''
Write-Host 'Windows PowerShell evidence captured.'
Write-Host "Evidence summary: $Summary"
Write-Host 'Keep windows-powershell open until the summary comes from a fresh Windows clone.'
