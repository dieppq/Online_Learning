param(
  [string]$Namespace = "learnhub-capstone-dev",
  [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"

$CapstoneRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ProjectRoot = Resolve-Path (Join-Path $CapstoneRoot "..")
. (Join-Path $ProjectRoot "scripts\common.ps1")

Invoke-Kubectl "delete" "namespace" $Namespace "--ignore-not-found" "--wait=false"
Wait-NamespaceDeleted -Namespace $Namespace -TimeoutSeconds $TimeoutSeconds

Write-Host "Namespace $Namespace is deleted."

