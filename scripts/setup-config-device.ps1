param(
  [Parameter(Mandatory=$true)][string]$Profile
)

$ErrorActionPreference = 'Stop'
$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$ModelsDir = if ($env:AI_MODELS_DIR) { $env:AI_MODELS_DIR } else { Join-Path $Root 'models' }
$Template = Join-Path $Root "runtime-config/presets/$Profile.ini"
$Active = Join-Path $Root 'runtime-config/presets.active.ini'
$ConfigPath = Join-Path $Root 'opencode.jsonc'

if (-not (Test-Path $Template)) { throw "Preset template missing: $Template" }

$content = Get-Content $Template -Raw
$content = $content.Replace('__MODELS_DIR__', $ModelsDir.Replace('\\','/'))
$content = $content.Replace('__CLUSTER_ROOT__', $Root.Replace('\\','/'))
$content | Set-Content $Active
$Profile | Set-Content (Join-Path $Root 'runtime-config/active-profile.txt')

switch ($Profile) {
  '16gb' { $model = 'qwen3.5-9b-q4' }
  '24gb' { $model = 'qwen3.5-27b-q4' }
  '32gb' { $model = 'qwen3.5-35b-a3b-q4' }
  '64gb' { $model = 'qwen3.5-35b-a3b-q4' }
  '128gb-multi' { $model = 'qwen3.5-35b-a3b-q4' }
  '128gb-qwen122b' { $model = 'qwen3.5-122b-a10b' }
  '128gb-minimax' { $model = 'minimax-m2.5' }
  'gemma-16gb' { $model = 'gemma-4-26b-a4b-q4' }
  'gemma-24gb' { $model = 'gemma-4-31b-q4' }
  'gemma-32gb' { $model = 'gemma-4-31b-q8' }
  'gemma-64gb' { $model = 'gemma-4-31b-bf16' }
  'openrouter' { $model = 'openrouter/qwen/qwen3-coder:480b-free' }
  default { throw "Unsupported profile: $Profile" }
}

$raw = Get-Content $ConfigPath -Raw
$jsonLike = ($raw -split "`n" | Where-Object { -not ($_.TrimStart().StartsWith('//')) }) -join "`n"
$obj = $jsonLike | ConvertFrom-Json
$obj.model = $model
if ($Profile -eq 'openrouter') {
  $obj.provider.openrouter.options.baseURL = 'https://openrouter.ai/api/v1'
} else {
  $obj.model = "local-cluster/$model"
  $obj.provider.'local-cluster'.options.baseURL = 'http://127.0.0.1:8080/v1'
}
$obj | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath

Write-Host "Wrote: $Active"
Write-Host "Set active profile: $Profile"
