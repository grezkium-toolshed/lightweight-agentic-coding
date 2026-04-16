param(
  [switch]$Strict,
  [switch]$BootstrapHint
)

$ErrorActionPreference = 'Continue'
$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$Port = if ($env:AI_CLUSTER_PORT) { $env:AI_CLUSTER_PORT } else { '8080' }
$ManifestPath = if ($env:PROFILE_MANIFEST_PATH) { $env:PROFILE_MANIFEST_PATH } else { Join-Path $Root 'runtime-config/profiles.json' }
$ActivePresetPath = if ($env:ACTIVE_PRESET_PATH) { $env:ACTIVE_PRESET_PATH } else { Join-Path $Root 'runtime-config/presets.active.ini' }
$ActiveProfilePath = if ($env:ACTIVE_PROFILE_PATH) { $env:ACTIVE_PROFILE_PATH } else { Join-Path $Root 'runtime-config/active-profile.txt' }
$ActiveConfigPath = if ($env:ACTIVE_OPENCODE_CONFIG_PATH) { $env:ACTIVE_OPENCODE_CONFIG_PATH } else { Join-Path $Root 'runtime-config/opencode.active.json' }
$LogFile = Join-Path $Root 'runtime-config/logs/llama-server.log'
$err = $false

function Show-BootstrapHint {
  if ($BootstrapHint) {
    Write-Host '  hint: run ./scripts/setup-config-device.ps1 -Profile <profile> to regenerate runtime-config state'
  }
}

function Check-File {
  param(
    [string]$Path,
    [switch]$Generated
  )

  if (Test-Path $Path) {
    Write-Host "[ok] $Path"
    return
  }

  if ($Generated) {
    Write-Host "[warn] missing generated file: $Path"
    Show-BootstrapHint
    if ($Strict) { $script:err = $true }
    return
  }

  Write-Host "[!!] missing: $Path"
  $script:err = $true
}

Check-File (Join-Path $Root 'opencode.jsonc')
Check-File $ManifestPath
Check-File $ActivePresetPath -Generated
Check-File $ActiveProfilePath -Generated
Check-File $ActiveConfigPath -Generated
Check-File (Join-Path $Root '.opencode/agents/architecture-reviewer.md')
Check-File (Join-Path $Root '.opencode/skills/docx-workflow/SKILL.md')

$runtimeMode = 'local'
$profile = ''
if (Test-Path $ActiveProfilePath) {
  $profile = (Get-Content $ActiveProfilePath -Raw).Trim()
  Write-Host "[ok] active profile: $profile"
  if ((Test-Path $ManifestPath) -and $profile) {
    $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    $profileData = $manifest.profiles.$profile
    if ($profileData -and $profileData.runtime_mode) {
      $runtimeMode = $profileData.runtime_mode
    }
  }
} else {
  Write-Host '[warn] active profile is not configured yet'
}

if ($profile -match '^128gb') {
  Write-Host '[ok] 128GB profile selected; keep effective memory <=115GB policy'
}

if (Get-Command opencode -ErrorAction SilentlyContinue) {
  Write-Host '[ok] opencode in PATH'
} else {
  Write-Host '[!!] opencode missing'
  $err = $true
}

if ($runtimeMode -eq 'cloud') {
  Write-Host '[ok] active profile does not require local llama-server'
} else {
  if (Get-Command llama-server -ErrorAction SilentlyContinue) {
    Write-Host '[ok] llama-server in PATH'
  } else {
    Write-Host '[!!] llama-server missing'
    $err = $true
  }

  try {
    Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2 | Out-Null
    Write-Host '[ok] server health endpoint reachable'
  } catch {
    Write-Host "[warn] server not reachable at http://127.0.0.1:$Port/health"
    if ($Strict) { $err = $true }
  }

  if (Test-Path $LogFile) {
    Write-Host "[ok] launch log file: $LogFile"
  } else {
    Write-Host "[warn] launch log file missing: $LogFile"
    if ($Strict) { $err = $true }
  }
}

if ($err) { exit 1 }
