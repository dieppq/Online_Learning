param(
  [string]$Tag = "0.1.0",
  [string]$WebTag = "0.1.2",
  [string]$GreenTag = "0.2.0",
  [switch]$SkipGreen
)

$ErrorActionPreference = "Stop"

$CapstoneRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ProjectRoot = Resolve-Path (Join-Path $CapstoneRoot "..")
. (Join-Path $ProjectRoot "scripts\common.ps1")

Build-LearnHubImages -Tags @($Tag)

$webImage = "learnhub/web-ui:$WebTag"
Write-Host "Building $webImage"
Invoke-Docker "build" "-t" $webImage "-f" "capstone/web/Dockerfile" "capstone/web"

if (-not $SkipGreen) {
  Build-LearnHubImages -Tags @($GreenTag) -Services @("course-service")
}

Write-Host "Capstone images are ready."
