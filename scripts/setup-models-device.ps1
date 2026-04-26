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
$mlxModels = @()

function Should-StageMlx {
  $value = if ($env:AI_INCLUDE_MLX) { $env:AI_INCLUDE_MLX.ToLowerInvariant() } else { 'auto' }
  switch ($value) {
    { $_ -in @('1', 'true', 'yes') } { return $true }
    { $_ -in @('0', 'false', 'no') } { return $false }
    'auto' { return $IsMacOS }
    default { throw "Unsupported AI_INCLUDE_MLX value: $($env:AI_INCLUDE_MLX)" }
  }
}

function Add-MlxModel([string]$Repo) {
  $script:mlxModels += $Repo
}

switch ($Profile) {
  '16gb' {
    $models += @{Dir='qwen3.6'; File='Qwen3.6-27B-UD-Q3_K_XL.gguf'; Repo='unsloth/Qwen3.6-27B-GGUF'; Remote='Qwen3.6-27B-UD-Q3_K_XL.gguf'; MinMB=14000}
    Add-MlxModel 'unsloth/Qwen3.6-27B-UD-MLX-6bit'
  }
  'macos-16gb' {
    $models += @{Dir='qwen3.5'; File='Qwen3.5-9B-Q4_K_M.gguf'; Repo='unsloth/Qwen3.5-9B-GGUF'; Remote='Qwen3.5-9B-Q4_K_M.gguf'; MinMB=5000}
    $models += @{Dir='gemma4'; File='gemma-4-E4B-IT-Q8_0.gguf'; Repo='unsloth/gemma-4-E4B-IT-GGUF'; Remote='gemma-4-E4B-IT-Q8_0.gguf'; MinMB=4000}
    Add-MlxModel 'unsloth/gemma-4-E4B-it-MLX-8bit'
  }
  '24gb' {
    $models += @{Dir='qwen3.6'; File='Qwen3.6-27B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3.6-27B-GGUF'; Remote='Qwen3.6-27B-UD-Q4_K_XL.gguf'; MinMB=17000}
    $models += @{Dir='qwen3.6'; File='Qwen3.6-27B-UD-Q3_K_XL.gguf'; Repo='unsloth/Qwen3.6-27B-GGUF'; Remote='Qwen3.6-27B-UD-Q3_K_XL.gguf'; MinMB=14000}
    Add-MlxModel 'unsloth/Qwen3.6-27B-UD-MLX-6bit'
  }
  '32gb' {
    $models += @{Dir='qwen3.6'; File='Qwen3.6-27B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3.6-27B-GGUF'; Remote='Qwen3.6-27B-UD-Q4_K_XL.gguf'; MinMB=17000}
    $models += @{Dir='qwen'; File='Qwen3-Coder-Next-MXFP4_MOE.gguf'; Repo='unsloth/Qwen3-Coder-Next-GGUF'; Remote='Qwen3-Coder-Next-MXFP4_MOE.gguf'; MinMB=28000}
    Add-MlxModel 'unsloth/Qwen3.6-27B-UD-MLX-6bit'
  }
  '64gb' {
    $models += @{Dir='qwen3.6'; File='Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf'; Repo='unsloth/Qwen3.6-35B-A3B-GGUF'; Remote='Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf'; MinMB=36000}
    $models += @{Dir='qwen3.6'; File='Qwen3.6-27B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3.6-27B-GGUF'; Remote='Qwen3.6-27B-UD-Q4_K_XL.gguf'; MinMB=17000}
    $models += @{Dir='qwen'; File='Qwen3-Coder-Next-MXFP4_MOE.gguf'; Repo='unsloth/Qwen3-Coder-Next-GGUF'; Remote='Qwen3-Coder-Next-MXFP4_MOE.gguf'; MinMB=28000}
    Add-MlxModel 'unsloth/Qwen3.6-35B-A3B-MLX-8bit'
    Add-MlxModel 'unsloth/Qwen3.6-27B-UD-MLX-6bit'
  }
  '128gb-qwen122b' {
    $models += @{Dir='qwen3.5'; File='Qwen3.5-122B-A10B-MXFP4_MOE-00001-of-00003.gguf'; Repo='unsloth/Qwen3.5-122B-A10B-GGUF'; Remote='Qwen3.5-122B-A10B-MXFP4_MOE-00001-of-00003.gguf'; MinMB=100}
    $models += @{Dir='qwen3.5'; File='Qwen3.5-122B-A10B-MXFP4_MOE-00002-of-00003.gguf'; Repo='unsloth/Qwen3.5-122B-A10B-GGUF'; Remote='Qwen3.5-122B-A10B-MXFP4_MOE-00002-of-00003.gguf'; MinMB=42000}
    $models += @{Dir='qwen3.5'; File='Qwen3.5-122B-A10B-MXFP4_MOE-00003-of-00003.gguf'; Repo='unsloth/Qwen3.5-122B-A10B-GGUF'; Remote='Qwen3.5-122B-A10B-MXFP4_MOE-00003-of-00003.gguf'; MinMB=15000}
    $models += @{Dir='qwen'; File='Qwen3-Coder-Next-MXFP4_MOE.gguf'; Repo='unsloth/Qwen3-Coder-Next-GGUF'; Remote='Qwen3-Coder-Next-MXFP4_MOE.gguf'; MinMB=28000}
  }
  '128gb-multi' {
    $models += @{Dir='qwen3.6'; File='Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf'; Repo='unsloth/Qwen3.6-35B-A3B-GGUF'; Remote='Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf'; MinMB=36000}
    $models += @{Dir='qwen3.6'; File='Qwen3.6-27B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3.6-27B-GGUF'; Remote='Qwen3.6-27B-UD-Q4_K_XL.gguf'; MinMB=17000}
    $models += @{Dir='qwen3.6'; File='Qwen3.6-27B-UD-Q3_K_XL.gguf'; Repo='unsloth/Qwen3.6-27B-GGUF'; Remote='Qwen3.6-27B-UD-Q3_K_XL.gguf'; MinMB=14000}
    $models += @{Dir='qwen'; File='Qwen3-Coder-Next-MXFP4_MOE.gguf'; Repo='unsloth/Qwen3-Coder-Next-GGUF'; Remote='Qwen3-Coder-Next-MXFP4_MOE.gguf'; MinMB=28000}
    Add-MlxModel 'unsloth/Qwen3.6-35B-A3B-MLX-8bit'
    Add-MlxModel 'unsloth/Qwen3.6-27B-UD-MLX-6bit'
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
    Add-MlxModel 'unsloth/gemma-4-26b-a4b-it-UD-MLX-8bit'
    Add-MlxModel 'unsloth/gemma-4-E4B-it-MLX-8bit'
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
  'opencode-go' {
    Write-Host 'Profile: opencode-go'
    Write-Host 'No local model downloads are required for the cloud-only opencode-go profile.'
    exit 0
  }
  default { throw "Unsupported profile: $Profile" }
}

function Get-ExpectedBytes([string]$Url) {
  try {
    $headResp = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -MaximumRedirection 5
    if ($headResp.Headers.'Content-Length') {
      return [int64]($headResp.Headers.'Content-Length'[0])
    }
  } catch {
    return 0
  }
  return 0
}

function Download-One($m) {
  $targetDir = Join-Path $ModelsDir $m.Dir
  $targetFile = Join-Path $targetDir $m.File
  $tmpFile = "$targetFile.downloading"
  $url = "https://huggingface.co/$($m.Repo)/resolve/main/$($m.Remote)"
  New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

  $expectedBytes = Get-ExpectedBytes $url
  $expectedMB = if ($expectedBytes -gt 0) { [int]([math]::Floor($expectedBytes / 1MB)) } else { 0 }

  if (Test-Path $targetFile) {
    $bytes = (Get-Item $targetFile).Length
    $mb = [int]([math]::Floor($bytes / 1MB))
    if ($expectedBytes -gt 0 -and $bytes -ge $expectedBytes) {
      Write-Host "[skip] $targetFile ($mb MB of ~$expectedMB MB)"
      return $true
    }
    if ($expectedBytes -eq 0 -and $mb -ge $m.MinMB) {
      Write-Host "[skip] $targetFile ($mb MB)"
      return $true
    }
    $expectedLabel = if ($expectedMB -gt 0) { " of ~$expectedMB MB" } else { "" }
    Write-Host "[warn] $targetFile incomplete ($mb MB$expectedLabel); preserving for resume"
    Move-Item -Force $targetFile $tmpFile
  }

  if ((-not (Test-Path $targetFile)) -and (Test-Path $tmpFile)) {
    $tmpBytes = (Get-Item $tmpFile).Length
    $tmpMB = [int]([math]::Floor($tmpBytes / 1MB))
    if (($expectedBytes -gt 0 -and $tmpBytes -ge $expectedBytes) -or ($expectedBytes -eq 0 -and $tmpMB -ge $m.MinMB)) {
      Write-Host "[resume] Promoting completed partial file: $tmpFile"
      Move-Item -Force $tmpFile $targetFile
    }
  }
  if (Test-Path $targetFile) {
    $promotedBytes = (Get-Item $targetFile).Length
    $promotedMB = [int]([math]::Floor($promotedBytes / 1MB))
    if ($expectedBytes -gt 0 -and $promotedBytes -ge $expectedBytes) {
      Write-Host "[skip] $targetFile ($promotedMB MB of ~$expectedMB MB)"
      return $true
    } elseif ($expectedBytes -eq 0 -and $promotedMB -ge $m.MinMB) {
      Write-Host "[skip] $targetFile ($promotedMB MB)"
      return $true
    }
  }

  $hf = Get-Command hf -ErrorAction SilentlyContinue
  $huggingFaceCli = Get-Command huggingface-cli -ErrorAction SilentlyContinue
  if ($hf) {
    Write-Host "[hf  ] $($m.Repo)/$($m.Remote) -> $targetDir"
    & $hf.Source download $m.Repo $m.Remote --local-dir $targetDir
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "Hugging Face CLI download failed: $($m.Repo)/$($m.Remote)"
      return $false
    }
  } elseif ($huggingFaceCli) {
    Write-Host "[hf  ] $($m.Repo)/$($m.Remote) -> $targetDir"
    & $huggingFaceCli.Source download $m.Repo $m.Remote --local-dir $targetDir
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "Hugging Face CLI download failed: $($m.Repo)/$($m.Remote)"
      return $false
    }
  } else {
    $curl = Get-Command curl -CommandType Application -ErrorAction SilentlyContinue
    if ($curl) {
      Write-Host "[get ] $url"
      & $curl.Source -fL --retry 3 --retry-delay 3 --retry-max-time 300 -C - -o $tmpFile $url
      if ($LASTEXITCODE -ne 0) {
        Write-Warning "Download failed, partial file preserved for resume: $tmpFile"
        return $false
      }
    } else {
      Write-Host "[get ] $url"
      try {
        Invoke-WebRequest -Uri $url -OutFile $tmpFile -UseBasicParsing
      } catch {
        Write-Warning "Download failed, partial file preserved for inspection: $tmpFile"
        return $false
      }
    }
    Move-Item -Force $tmpFile $targetFile
  }

  if (-not (Test-Path $targetFile)) {
    Write-Warning "Expected downloaded file missing: $targetFile"
    return $false
  }

  $newBytes = (Get-Item $targetFile).Length
  $newMB = [int]([math]::Floor($newBytes / 1MB))
  if ($expectedBytes -gt 0) {
    if ($newBytes -lt $expectedBytes) {
      Write-Warning "Download incomplete for $($m.File): $newMB MB (expected ~$expectedMB MB); keeping file for resume"
      Move-Item -Force $targetFile $tmpFile
      return $false
    }
  } elseif ($newMB -lt $m.MinMB) {
    Write-Warning "Download too small for $($m.File): $newMB MB (minimum: $($m.MinMB) MB); keeping file for inspection/resume"
    return $false
  }

  if ($expectedMB -gt 0) {
    Write-Host "[ ok ] $targetFile ($newMB MB of ~$expectedMB MB)"
  } else {
    Write-Host "[ ok ] $targetFile ($newMB MB)"
  }
  return $true
}

$failures = 0
foreach ($m in $models) {
  if (-not (Download-One $m)) {
    $failures += 1
  }
}

function Download-MlxRepo([string]$Repo) {
  $repoName = ($Repo -split '/', 2)[1]
  $targetDir = Join-Path (Join-Path $ModelsDir 'mlx') $repoName

  if (Test-Path $targetDir) {
    Write-Host "[skip] $targetDir"
    return
  }

  $hf = Get-Command hf -ErrorAction SilentlyContinue
  if ($hf) {
    Write-Host "[mlx ] $Repo -> $targetDir"
    & $hf.Source download $Repo --local-dir $targetDir
    if ($LASTEXITCODE -ne 0) { throw "MLX download failed: $Repo" }
    return
  }

  $huggingFaceCli = Get-Command huggingface-cli -ErrorAction SilentlyContinue
  if ($huggingFaceCli) {
    Write-Host "[mlx ] $Repo -> $targetDir"
    & $huggingFaceCli.Source download $Repo --local-dir $targetDir
    if ($LASTEXITCODE -ne 0) { throw "MLX download failed: $Repo" }
    return
  }

  Write-Warning "Skipping MLX repo ${Repo}: install the Hugging Face CLI ('hf' or 'huggingface-cli') to stage macOS MLX weights."
}

if ((Should-StageMlx) -and $mlxModels.Count -gt 0) {
  Write-Host 'MLX staging: enabled for macOS'
  foreach ($repo in $mlxModels) {
    try {
      Download-MlxRepo $repo
    } catch {
      Write-Warning $_
      $failures += 1
    }
  }
}

if ($failures -gt 0) {
  throw "Done with $failures failed download(s). Re-run the same command to resume."
}

Write-Host "Done."
