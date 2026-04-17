param(
  [Parameter(Mandatory=$true)][string]$Profile
)

$ErrorActionPreference = 'Stop'
$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$ModelsDir = if ($env:AI_MODELS_DIR) { $env:AI_MODELS_DIR } else { Join-Path $Root 'models' }
New-Item -ItemType Directory -Force -Path $ModelsDir | Out-Null

$models = @(
  @{Dir='embeddings'; File='nomic-embed-text-v1.5.Q4_K_M.gguf'; Repo='nomic-ai/nomic-embed-text-v1.5-GGUF'; Remote='nomic-embed-text-v1.5.Q4_K_M.gguf'; MinMB=60}
)

switch ($Profile) {
  '16gb' { $models += @{Dir='qwen3'; File='Qwen3-8B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3-8B-GGUF'; Remote='Qwen3-8B-UD-Q4_K_XL.gguf'; MinMB=5000} }
  '24gb' {
    $models += @{Dir='qwen3'; File='Qwen3-14B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3-14B-GGUF'; Remote='Qwen3-14B-UD-Q4_K_XL.gguf'; MinMB=9000}
    $models += @{Dir='qwen3'; File='Qwen3-8B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3-8B-GGUF'; Remote='Qwen3-8B-UD-Q4_K_XL.gguf'; MinMB=5000}
  }
  '32gb' {
    $models += @{Dir='qwen3'; File='Qwen3-30B-A3B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3-30B-A3B-GGUF'; Remote='Qwen3-30B-A3B-UD-Q4_K_XL.gguf'; MinMB=18000}
    $models += @{Dir='qwen3'; File='Qwen3-14B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3-14B-GGUF'; Remote='Qwen3-14B-UD-Q4_K_XL.gguf'; MinMB=9000}
    $models += @{Dir='qwen'; File='Qwen3-Coder-Next-MXFP4_MOE.gguf'; Repo='unsloth/Qwen3-Coder-Next-GGUF'; Remote='Qwen3-Coder-Next-MXFP4_MOE.gguf'; MinMB=28000}
  }
  '64gb' {
    $models += @{Dir='qwen3'; File='Qwen3-30B-A3B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3-30B-A3B-GGUF'; Remote='Qwen3-30B-A3B-UD-Q4_K_XL.gguf'; MinMB=18000}
    $models += @{Dir='qwen3'; File='Qwen3-14B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3-14B-GGUF'; Remote='Qwen3-14B-UD-Q4_K_XL.gguf'; MinMB=9000}
    $models += @{Dir='qwen'; File='Qwen3-Coder-Next-MXFP4_MOE.gguf'; Repo='unsloth/Qwen3-Coder-Next-GGUF'; Remote='Qwen3-Coder-Next-MXFP4_MOE.gguf'; MinMB=28000}
  }
  '128gb-qwen122b' {
    $models += @{Dir='qwen3.5'; File='Qwen3.5-122B-A10B-MXFP4_MOE-00001-of-00003.gguf'; Repo='unsloth/Qwen3.5-122B-A10B-GGUF'; Remote='Qwen3.5-122B-A10B-MXFP4_MOE-00001-of-00003.gguf'; MinMB=100}
    $models += @{Dir='qwen3.5'; File='Qwen3.5-122B-A10B-MXFP4_MOE-00002-of-00003.gguf'; Repo='unsloth/Qwen3.5-122B-A10B-GGUF'; Remote='Qwen3.5-122B-A10B-MXFP4_MOE-00002-of-00003.gguf'; MinMB=42000}
    $models += @{Dir='qwen3.5'; File='Qwen3.5-122B-A10B-MXFP4_MOE-00003-of-00003.gguf'; Repo='unsloth/Qwen3.5-122B-A10B-GGUF'; Remote='Qwen3.5-122B-A10B-MXFP4_MOE-00003-of-00003.gguf'; MinMB=15000}
    $models += @{Dir='qwen'; File='Qwen3-Coder-Next-MXFP4_MOE.gguf'; Repo='unsloth/Qwen3-Coder-Next-GGUF'; Remote='Qwen3-Coder-Next-MXFP4_MOE.gguf'; MinMB=28000}
  }
  '128gb-multi' {
    $models += @{Dir='qwen3'; File='Qwen3-30B-A3B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3-30B-A3B-GGUF'; Remote='Qwen3-30B-A3B-UD-Q4_K_XL.gguf'; MinMB=18000}
    $models += @{Dir='qwen3'; File='Qwen3-14B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3-14B-GGUF'; Remote='Qwen3-14B-UD-Q4_K_XL.gguf'; MinMB=9000}
    $models += @{Dir='qwen3'; File='Qwen3-8B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3-8B-GGUF'; Remote='Qwen3-8B-UD-Q4_K_XL.gguf'; MinMB=5000}
    $models += @{Dir='qwen'; File='Qwen3-Coder-Next-MXFP4_MOE.gguf'; Repo='unsloth/Qwen3-Coder-Next-GGUF'; Remote='Qwen3-Coder-Next-MXFP4_MOE.gguf'; MinMB=28000}
  }
  '128gb-minimax' {
    $repo = if ($env:MINIMAX_REPO) { $env:MINIMAX_REPO } else { 'unsloth/MiniMax-M2.7-GGUF' }
    $filesRaw = if ($env:MINIMAX_FILES) { $env:MINIMAX_FILES } else { 'MiniMax-M2.7-UD-IQ4_XS-00001-of-00003.gguf,MiniMax-M2.7-UD-IQ4_XS-00002-of-00003.gguf,MiniMax-M2.7-UD-IQ4_XS-00003-of-00003.gguf' }
    $files = $filesRaw -split ','
    foreach ($file in $files) {
      $minMb = 1000
      if ($file -like '*00001-of-00003.gguf') { $minMb = 5 }
      elseif ($file -like '*00002-of-00003.gguf') { $minMb = 30000 }
      elseif ($file -like '*00003-of-00003.gguf') { $minMb = 30000 }
      $models += @{Dir='minimax'; File=$file; Repo=$repo; Remote=$file; MinMB=$minMb}
    }
    $models += @{Dir='qwen'; File='Qwen3-Coder-Next-MXFP4_MOE.gguf'; Repo='unsloth/Qwen3-Coder-Next-GGUF'; Remote='Qwen3-Coder-Next-MXFP4_MOE.gguf'; MinMB=28000}
  }
  'gemma-16gb' {
    $models += @{Dir='gemma4'; File='gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf'; Repo='unsloth/gemma-4-26B-A4B-IT-GGUF'; Remote='gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf'; MinMB=15000}
    $models += @{Dir='gemma4'; File='gemma-4-E4B-IT-Q8_0.gguf'; Repo='unsloth/gemma-4-E4B-IT-GGUF'; Remote='gemma-4-E4B-IT-Q8_0.gguf'; MinMB=4000}
  }
  'gemma-24gb' {
    $models += @{Dir='gemma4'; File='gemma-4-31B-IT-UD-Q4_K_XL.gguf'; Repo='unsloth/gemma-4-31B-IT-GGUF'; Remote='gemma-4-31B-IT-UD-Q4_K_XL.gguf'; MinMB=16000}
    $models += @{Dir='gemma4'; File='gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf'; Repo='unsloth/gemma-4-26B-A4B-IT-GGUF'; Remote='gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf'; MinMB=15000}
  }
  'gemma-32gb' {
    $models += @{Dir='gemma4'; File='gemma-4-31B-IT-Q8_0.gguf'; Repo='unsloth/gemma-4-31B-IT-GGUF'; Remote='gemma-4-31B-IT-Q8_0.gguf'; MinMB=32000}
    $models += @{Dir='gemma4'; File='gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf'; Repo='unsloth/gemma-4-26B-A4B-IT-GGUF'; Remote='gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf'; MinMB=15000}
  }
  'gemma-64gb' {
    $models += @{Dir='gemma4'; File='gemma-4-31B-IT-BF16.gguf'; Repo='unsloth/gemma-4-31B-IT-GGUF'; Remote='gemma-4-31B-IT-BF16.gguf'; MinMB=60000}
    $models += @{Dir='gemma4'; File='gemma-4-31B-IT-Q8_0.gguf'; Repo='unsloth/gemma-4-31B-IT-GGUF'; Remote='gemma-4-31B-IT-Q8_0.gguf'; MinMB=32000}
    $models += @{Dir='gemma4'; File='gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf'; Repo='unsloth/gemma-4-26B-A4B-IT-GGUF'; Remote='gemma-4-26B-A4B-IT-UD-Q4_K_XL.gguf'; MinMB=15000}
  }
  'openrouter' {
    Write-Host 'Profile: openrouter'
    Write-Host 'No local model downloads are required for the cloud-only openrouter profile.'
    exit 0
  }
  default { throw "Unsupported profile: $Profile" }
}

foreach ($m in $models) {
  $targetDir = Join-Path $ModelsDir $m.Dir
  $targetFile = Join-Path $targetDir $m.File
  New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

  if (Test-Path $targetFile) {
    $mb = [int]([math]::Round((Get-Item $targetFile).Length / 1MB))
    if ($mb -ge $m.MinMB) {
      Write-Host "[skip] $targetFile ($mb MB)"
      continue
    }
    Write-Host "[warn] $targetFile too small ($mb MB < $($m.MinMB) MB), re-downloading"
    Remove-Item $targetFile -Force
  }

  $url = "https://huggingface.co/$($m.Repo)/resolve/main/$($m.Remote)"

  # Fetch expected file size from Hugging Face for validation
  $expectedMB = 0
  try {
    $headResp = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -MaximumRedirection 3
    if ($headResp.Headers.'Content-Length') {
      $expectedBytes = [int64]($headResp.Headers.'Content-Length'[0])
      $expectedMB = [int]([math]::Round($expectedBytes / 1MB))
    }
  } catch {
    # Non-fatal: continue without expected size check
  }

  Write-Host "[get ] $url"
  try {
    Invoke-WebRequest -Uri $url -OutFile $targetFile -UseBasicParsing
  } catch {
    Write-Host "[fail] Download failed: $url"
    if (Test-Path $targetFile) { Remove-Item $targetFile -Force }
    throw
  }

  $newMB = [int]([math]::Round((Get-Item $targetFile).Length / 1MB))
  if ($newMB -lt $m.MinMB) {
    Write-Error "Download too small for $($m.File): $newMB MB (minimum: $($m.MinMB) MB)"
    Remove-Item $targetFile -Force
    throw "Download validation failed"
  }
  if ($expectedMB -gt 0 -and $newMB -lt [int]($expectedMB * 0.95)) {
    Write-Error "Download incomplete for $($m.File): $newMB MB (expected ~$expectedMB MB)"
    Remove-Item $targetFile -Force
    throw "Download validation failed"
  }
  if ($expectedMB -gt 0) {
    Write-Host "[ ok ] $targetFile ($newMB MB of ~$expectedMB MB)"
  } else {
    Write-Host "[ ok ] $targetFile ($newMB MB)"
  }
}

Write-Host "Done."
