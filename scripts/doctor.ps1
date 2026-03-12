$ErrorActionPreference = 'Continue'
$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$Port = if ($env:AI_CLUSTER_PORT) { $env:AI_CLUSTER_PORT } else { '8080' }
$err = $false
$LogFile = Join-Path $Root 'runtime-config/logs/llama-server.log'

$paths = @(
  (Join-Path $Root 'opencode.jsonc'),
  (Join-Path $Root 'runtime-config/presets.active.ini'),
  (Join-Path $Root '.opencode/agents/architecture-reviewer.md'),
  (Join-Path $Root '.opencode/skills/docx-workflow/SKILL.md')
)
foreach ($p in $paths) {
  if (Test-Path $p) { Write-Host "[ok] $p" } else { Write-Host "[!!] missing: $p"; $err = $true }
}

if (Get-Command llama-server -ErrorAction SilentlyContinue) { Write-Host '[ok] llama-server in PATH' } else { Write-Host '[!!] llama-server missing'; $err = $true }
if (Get-Command opencode -ErrorAction SilentlyContinue) { Write-Host '[ok] opencode in PATH' } else { Write-Host '[!!] opencode missing'; $err = $true }

$profilePath = Join-Path $Root 'runtime-config/active-profile.txt'
if (Test-Path $profilePath) {
  $profile = Get-Content $profilePath -Raw
  Write-Host "[ok] active profile: $profile"
  if ($profile -match '128gb') {
    Write-Host '[ok] 128GB profile selected; keep effective memory <=115GB policy'
  }
}

try {
  Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2 | Out-Null
  Write-Host '[ok] server health endpoint reachable'
} catch {
  Write-Host "[!!] server not reachable at http://127.0.0.1:$Port/health"
}

if (Test-Path $LogFile) {
  Write-Host "[ok] launch log file: $LogFile"
} else {
  Write-Host "[!!] launch log file missing: $LogFile"
}

if ($err) { exit 1 }
