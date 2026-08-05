param(
  [string]$Namespace = "learnhub-capstone-dev",
  [ValidateSet("blue", "green")]
  [string]$Track = "green"
)

$ErrorActionPreference = "Stop"

$CapstoneRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ProjectRoot = Resolve-Path (Join-Path $CapstoneRoot "..")
. (Join-Path $ProjectRoot "scripts\common.ps1")

$PatchFile = Join-Path $CapstoneRoot "k8s\blue-green\switch-to-$Track-patch.json"

Invoke-Kubectl "patch" "service" "course-service" "-n" $Namespace "--type=json" "--patch-file" $PatchFile
Invoke-Kubectl "get" "service" "course-service" "-n" $Namespace "-o" "wide"
Invoke-Kubectl "get" "endpoints" "course-service" "-n" $Namespace

Write-Host "course-service now points to track=$Track."
