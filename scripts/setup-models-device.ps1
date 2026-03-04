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
  '16gb' { $models += @{Dir='qwen3.5'; File='Qwen3.5-9B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3.5-9B-GGUF'; Remote='Qwen3.5-9B-UD-Q4_K_XL.gguf'; MinMB=5000} }
  '24gb' {
    $models += @{Dir='qwen3.5'; File='Qwen3.5-27B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3.5-27B-GGUF'; Remote='Qwen3.5-27B-UD-Q4_K_XL.gguf'; MinMB=12000}
    $models += @{Dir='qwen3.5'; File='Qwen3.5-9B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3.5-9B-GGUF'; Remote='Qwen3.5-9B-UD-Q4_K_XL.gguf'; MinMB=5000}
  }
  '32gb' {
    $models += @{Dir='qwen3.5'; File='Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3.5-35B-A3B-GGUF'; Remote='Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf'; MinMB=15000}
    $models += @{Dir='qwen3.5'; File='Qwen3.5-27B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3.5-27B-GGUF'; Remote='Qwen3.5-27B-UD-Q4_K_XL.gguf'; MinMB=12000}
    $models += @{Dir='qwen'; File='Qwen3-Coder-Next-MXFP4_MOE.gguf'; Repo='unsloth/Qwen3-Coder-Next-GGUF'; Remote='Qwen3-Coder-Next-MXFP4_MOE.gguf'; MinMB=28000}
  }
  '64gb' {
    $models += @{Dir='qwen3.5'; File='Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3.5-35B-A3B-GGUF'; Remote='Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf'; MinMB=15000}
    $models += @{Dir='qwen3.5'; File='Qwen3.5-27B-UD-Q4_K_XL.gguf'; Repo='unsloth/Qwen3.5-27B-GGUF'; Remote='Qwen3.5-27B-UD-Q4_K_XL.gguf'; MinMB=12000}
    $models += @{Dir='qwen'; File='Qwen3-Coder-Next-MXFP4_MOE.gguf'; Repo='unsloth/Qwen3-Coder-Next-GGUF'; Remote='Qwen3-Coder-Next-MXFP4_MOE.gguf'; MinMB=28000}
  }
  '128gb-qwen122b' {
    $models += @{Dir='qwen3.5'; File='Qwen3.5-122B-A10B-MXFP4_MOE-00001-of-00003.gguf'; Repo='unsloth/Qwen3.5-122B-A10B-GGUF'; Remote='Qwen3.5-122B-A10B-MXFP4_MOE-00001-of-00003.gguf'; MinMB=100}
    $models += @{Dir='qwen3.5'; File='Qwen3.5-122B-A10B-MXFP4_MOE-00002-of-00003.gguf'; Repo='unsloth/Qwen3.5-122B-A10B-GGUF'; Remote='Qwen3.5-122B-A10B-MXFP4_MOE-00002-of-00003.gguf'; MinMB=42000}
    $models += @{Dir='qwen3.5'; File='Qwen3.5-122B-A10B-MXFP4_MOE-00003-of-00003.gguf'; Repo='unsloth/Qwen3.5-122B-A10B-GGUF'; Remote='Qwen3.5-122B-A10B-MXFP4_MOE-00003-of-00003.gguf'; MinMB=15000}
    $models += @{Dir='qwen'; File='Qwen3-Coder-Next-MXFP4_MOE.gguf'; Repo='unsloth/Qwen3-Coder-Next-GGUF'; Remote='Qwen3-Coder-Next-MXFP4_MOE.gguf'; MinMB=28000}
  }
  '128gb-minimax' {
    $repo = if ($env:MINIMAX_REPO) { $env:MINIMAX_REPO } else { 'unsloth/MiniMax-M2.5-GGUF' }
    $file = if ($env:MINIMAX_FILE) { $env:MINIMAX_FILE } else { 'MiniMax-M2.5-UD-Q3_K_XL-00001-of-00004.gguf' }
    $models += @{Dir='minimax'; File=$file; Repo=$repo; Remote=$file; MinMB=20000}
    $models += @{Dir='qwen'; File='Qwen3-Coder-Next-MXFP4_MOE.gguf'; Repo='unsloth/Qwen3-Coder-Next-GGUF'; Remote='Qwen3-Coder-Next-MXFP4_MOE.gguf'; MinMB=28000}
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
    Remove-Item $targetFile -Force
  }

  $url = "https://huggingface.co/$($m.Repo)/resolve/main/$($m.Remote)"
  Write-Host "[get ] $url"
  Invoke-WebRequest -Uri $url -OutFile $targetFile

  $newMB = [int]([math]::Round((Get-Item $targetFile).Length / 1MB))
  if ($newMB -lt $m.MinMB) {
    throw "Download too small for $($m.File): $newMB MB"
  }
  Write-Host "[ ok ] $targetFile ($newMB MB)"
}

Write-Host "Done."
