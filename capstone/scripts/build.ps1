param(
  [string]$Tag = "0.3.0",
  [string]$CourseTag = "0.4.0",
  [string]$WebTag = "0.2.0",
  [string]$GreenTag = "0.4.1",
  [switch]$SkipGreen
)

$ErrorActionPreference = "Stop"

$CapstoneRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ProjectRoot = Resolve-Path (Join-Path $CapstoneRoot "..")
. (Join-Path $ProjectRoot "scripts\common.ps1")

Build-LearnHubImages -Tags @($Tag) -Services @(
  "user-service",
  "enrollment-service",
  "payment-service",
  "notification-service"
)
Build-LearnHubImages -Tags @($CourseTag) -Services @("course-service")

$webImage = "learnhub/web-ui:$WebTag"
$repositoryPath = $ProjectRoot.Path.Replace("\", "/")
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$gitCommit = (& git -c "safe.directory=$repositoryPath" rev-parse --verify HEAD 2>$null)
$gitExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
if ($gitExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($gitCommit)) {
  $gitCommit = "unknown"
}
$buildDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
Write-Host "Building $webImage"
Invoke-Docker "build" `
  "--build-arg" "APP_VERSION=$WebTag" `
  "--build-arg" "GIT_COMMIT=$gitCommit" `
  "--build-arg" "BUILD_DATE=$buildDate" `
  "-t" $webImage `
  "-f" "capstone/web/Dockerfile" `
  "capstone/web"

if (-not $SkipGreen) {
  Build-LearnHubImages -Tags @($GreenTag) -Services @("course-service")
}

Write-Host "Capstone images are ready."
