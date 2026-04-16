param(
  [Parameter(Mandatory=$true)][string]$Profile
)

$ErrorActionPreference = 'Stop'
$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$ModelsDir = if ($env:AI_MODELS_DIR) { $env:AI_MODELS_DIR } else { Join-Path $Root 'models' }
$ManifestPath = if ($env:PROFILE_MANIFEST_PATH) { $env:PROFILE_MANIFEST_PATH } else { Join-Path $Root 'runtime-config/profiles.json' }
$TemplateConfigPath = if ($env:OPENCODE_TEMPLATE_PATH) { $env:OPENCODE_TEMPLATE_PATH } else { Join-Path $Root 'opencode.jsonc' }
$ActivePresetPath = if ($env:ACTIVE_PRESET_PATH) { $env:ACTIVE_PRESET_PATH } else { Join-Path $Root 'runtime-config/presets.active.ini' }
$ActiveProfilePath = if ($env:ACTIVE_PROFILE_PATH) { $env:ACTIVE_PROFILE_PATH } else { Join-Path $Root 'runtime-config/active-profile.txt' }
$ActiveConfigPath = if ($env:ACTIVE_OPENCODE_CONFIG_PATH) { $env:ACTIVE_OPENCODE_CONFIG_PATH } else { Join-Path $Root 'runtime-config/opencode.active.json' }

if (-not (Test-Path $ManifestPath)) { throw "Profile manifest missing: $ManifestPath" }

$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
$profileData = $manifest.profiles.$Profile
if (-not $profileData) { throw "Unsupported profile: $Profile" }

$Template = Join-Path $Root $profileData.preset
if (-not (Test-Path $Template)) { throw "Preset template missing: $Template" }

$content = Get-Content $Template -Raw
$content = $content.Replace('__MODELS_DIR__', $ModelsDir.Replace('\','/'))
$content = $content.Replace('__CLUSTER_ROOT__', $Root.Replace('\','/'))
$content | Set-Content $ActivePresetPath -NoNewline
$Profile | Set-Content $ActiveProfilePath

$raw = Get-Content $TemplateConfigPath -Raw
$jsonLike = ($raw -split "`n" | Where-Object { -not ($_.TrimStart().StartsWith('//')) }) -join "`n"
$obj = $jsonLike | ConvertFrom-Json
$obj.model = $profileData.default_model
$obj.small_model = $profileData.small_model
$obj | ConvertTo-Json -Depth 20 | Set-Content $ActiveConfigPath

Write-Host "Wrote: $ActivePresetPath"
Write-Host "Set active profile: $Profile"
Write-Host "Generated OpenCode config: $ActiveConfigPath"
