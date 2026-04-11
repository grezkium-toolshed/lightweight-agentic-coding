$ErrorActionPreference = 'Stop'

$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$Port = if ($env:AI_CLUSTER_PORT) { $env:AI_CLUSTER_PORT } else { 8080 }
$Timeout = if ($env:SMOKE_TIMEOUT) { [int]$env:SMOKE_TIMEOUT } else { 30 }
$BaseUrl = "http://127.0.0.1:$Port"

Write-Host "=== Smoke Test ==="
Write-Host "Server: $BaseUrl"
Write-Host "Timeout: ${Timeout}s"
Write-Host ""

# 1. Check server health
Write-Host "[1/4] Checking health endpoint..."
try {
  $health = Invoke-RestMethod -Uri "$BaseUrl/health" -Method Get -TimeoutSec $Timeout -ErrorAction Stop
  Write-Host "[ok]  Health: $($health | ConvertTo-Json -Compress)"
} catch {
  Write-Host "[fail] Server is not reachable at $BaseUrl/health"
  Write-Host "  Start llama-server first: ./scripts/launch-llama.ps1"
  exit 1
}

# 2. Check available models
Write-Host "[2/4] Checking available models..."
try {
  $modelsResp = Invoke-RestMethod -Uri "$BaseUrl/v1/models" -Method Get -TimeoutSec $Timeout -ErrorAction Stop
  $modelCount = @($modelsResp.data).Count
  if ($modelCount -eq 0) {
    Write-Host "[fail] No models loaded"
    exit 1
  }
  Write-Host "[ok]  $modelCount model(s) available"
} catch {
  Write-Host "[fail] /v1/models request failed: $_"
  exit 1
}

# 3. Send a minimal chat completion request
Write-Host "[3/4] Sending test chat completion..."
$body = @{
  model = "default"
  messages = @(@{role = "user"; content = "Say hello in one word."})
  max_tokens = 16
  temperature = 0.1
} | ConvertTo-Json -Depth 3

try {
  $chatResp = Invoke-RestMethod -Uri "$BaseUrl/v1/chat/completions" -Method Post -Body $body -ContentType "application/json" -TimeoutSec $Timeout -ErrorAction Stop
  $choices = @($chatResp.choices)
  if ($choices.Count -eq 0 -or -not $choices[0].message.content) {
    Write-Host "[warn] Chat completion returned no/empty content (model may still be loading)"
  } else {
    Write-Host "[ok]  Chat completion returned content"
  }
} catch {
  Write-Host "[fail] Chat completion request failed: $_"
  exit 1
}

# 4. Report profile info if available
Write-Host "[4/4] Checking active profile..."
$profilePath = Join-Path $Root 'runtime-config/active-profile.txt'
if (Test-Path $profilePath) {
  $profile = Get-Content $profilePath
  Write-Host "[ok]  Active profile: $profile"
} else {
  Write-Host "[warn] No active profile found (run setup-config-device.ps1 first)"
}

Write-Host ""
Write-Host "=== Smoke test PASSED ==="
