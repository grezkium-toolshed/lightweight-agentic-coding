param(
  [Parameter(Mandatory=$true)][string]$Profile
)

$ErrorActionPreference = 'Stop'
$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
& (Join-Path $Root 'bin/lac.ps1') profile apply $Profile
$ProfileExitCode = $LASTEXITCODE
if ($ProfileExitCode -ne 0) {
  exit $ProfileExitCode
}

$DcpPlugin = '@tarquinen/opencode-dcp@latest'
$DcpCacheDir = Join-Path $HOME '.cache/opencode/packages/@tarquinen/opencode-dcp@latest'
$DcpPackageJson = Join-Path $DcpCacheDir 'node_modules/@tarquinen/opencode-dcp/package.json'
if (Test-Path $DcpPackageJson) {
  $DcpPackage = Get-Content $DcpPackageJson -Raw | ConvertFrom-Json
  if ($DcpPackage.version -eq '3.1.9') {
    Write-Host '[setup] Removing stale DCP 3.1.9 package cache before reinstall...'
    Remove-Item -LiteralPath $DcpCacheDir -Recurse -Force
  }
}
if ($env:AI_CLUSTER_INSTALL_DCP -eq '0') {
  Write-Host '[setup] DCP plugin install skipped (AI_CLUSTER_INSTALL_DCP=0).'
} elseif (Get-Command opencode -ErrorAction SilentlyContinue) {
  Write-Host "[setup] Installing/updating Dynamic Context Pruning plugin: $DcpPlugin"
  & opencode plugin $DcpPlugin --global --force
  if ($LASTEXITCODE -eq 0) {
    Write-Host '[setup] DCP plugin ready. Restart OpenCode and run /dcp to verify.'
  } else {
    Write-Warning 'DCP plugin install failed.'
    Write-Host "[setup] Retry manually with: opencode plugin $DcpPlugin --global --force"
  }
} else {
  Write-Warning 'opencode is not in PATH; cannot install DCP plugin.'
  Write-Host "[setup] After installing OpenCode, run: opencode plugin $DcpPlugin --global --force"
}

exit 0
