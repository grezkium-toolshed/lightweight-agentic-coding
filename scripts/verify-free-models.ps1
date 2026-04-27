# Verify that free cloud models in opencode.template.jsonc are still accessible.
# Usage: ./scripts/verify-free-models.ps1
# Prerequisites: OPENROUTER_API_KEY and/or NVIDIA_API_KEY set in environment.
$ErrorActionPreference = 'Stop'

$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$Config = Join-Path $Root 'opencode.template.jsonc'
$Timeout = if ($env:MODEL_VERIFY_TIMEOUT) { [int]$env:MODEL_VERIFY_TIMEOUT } else { 10 }
$Err = 0

if (-not (Test-Path $Config)) {
  Write-Host "Config not found: $Config"
  exit 1
}

function Extract-Models {
  param([string]$Provider)
  $raw = Get-Content $Config -Raw
  $jsonLike = ($raw -split "`n" | Where-Object { -not ($_.TrimStart().StartsWith('//')) }) -join "`n"
  $obj = $jsonLike | ConvertFrom-Json
  $models = $obj.provider.$Provider.models
  return @($models.PSObject.Properties | ForEach-Object { $_.Name })
}

function Check-Model {
  param([string]$Provider, [string]$ModelId)

  $baseUrl = ''
  $apiKey = ''

  switch ($Provider) {
    'openrouter' {
      $baseUrl = 'https://openrouter.ai/api/v1'
      $apiKey = $env:OPENROUTER_API_KEY
    }
    'nvidia-nim' {
      $baseUrl = 'https://integrate.api.nvidia.com/v1'
      $apiKey = $env:NVIDIA_API_KEY
    }
  }

  if (-not $apiKey) {
    switch ($Provider) {
      'openrouter' { Write-Host "  [?] $ModelId — no API key set (set OPENROUTER_API_KEY)" }
      'nvidia-nim' { Write-Host "  [?] $ModelId — no API key set (set NVIDIA_API_KEY)" }
      default { Write-Host "  [?] $ModelId — no API key set" }
    }
    return
  }

  $body = @{
    model = $ModelId
    messages = @(@{role = 'user'; content = 'hi' })
    max_tokens = 4
  } | ConvertTo-Json -Compress

  try {
    $resp = Invoke-RestMethod -Uri "$baseUrl/chat/completions" -Method Post `
      -Headers @{ 'Authorization' = "Bearer $apiKey"; 'Content-Type' = 'application/json' } `
      -Body $body -TimeoutSec $Timeout -ErrorAction Stop
    Write-Host "  [ok] $ModelId"
  } catch {
    $statusCode = $_.Exception.Response.StatusCode
    if ($statusCode) {
      $code = [int]$statusCode
    } else {
      $code = 0
    }
    switch ($code) {
      404 {
        Write-Host "  [!!] $ModelId — REMOVED (404)"
        $script:Err = 1
      }
      429 { Write-Host "  [--] $ModelId — rate-limited (429)" }
      401 {
        Write-Host "  [!!] $ModelId — auth error ($code)"
        $script:Err = 1
      }
      403 {
        Write-Host "  [!!] $ModelId — auth error ($code)"
        $script:Err = 1
      }
      default { Write-Host "  [??] $ModelId — unexpected status $code" }
    }
  }
}

Write-Host "=== Free Model Verification ==="
Write-Host "Timeout per model: ${Timeout}s"
Write-Host ""

# OpenRouter free tier
Write-Host "[openrouter] Free models:"
$orModels = Extract-Models 'openrouter'
if ($orModels.Count -eq 0) {
  Write-Host "  [warn] No models found in openrouter provider block"
} else {
  foreach ($model in $orModels) {
    Check-Model 'openrouter' $model
  }
}
Write-Host ""

# NVIDIA NIM
Write-Host "[nvidia-nim] Free/trial models:"
$nimModels = Extract-Models 'nvidia-nim'
if ($nimModels.Count -eq 0) {
  Write-Host "  [warn] No models found in nvidia-nim provider block"
} else {
  foreach ($model in $nimModels) {
    Check-Model 'nvidia-nim' $model
  }
}
Write-Host ""

# Summary
if ($Err -ne 0) {
  Write-Host "=== Verification complete — some models are broken ==="
  Write-Host "Update opencode.template.jsonc and docs/providers/OPENROUTER_FREE.md"
  Write-Host "to remove removed models."
  exit 1
} else {
  Write-Host "=== Verification complete — no broken models ==="
}
