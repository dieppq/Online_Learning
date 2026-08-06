param(
  [string]$Tag = "0.1.0",
  [string[]]$Services = @(
    "user-service",
    "course-service",
    "enrollment-service",
    "payment-service",
    "notification-service"
  )
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\common.ps1"

$repositoryPath = (Resolve-Path ".").Path.Replace("\", "/")
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$gitCommit = (& git -c "safe.directory=$repositoryPath" rev-parse --verify HEAD 2>$null)
$gitExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
if ($gitExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($gitCommit)) {
  $gitCommit = "unknown"
}
$buildDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$ValidServices = @(
  "user-service",
  "course-service",
  "enrollment-service",
  "payment-service",
  "notification-service"
)

Assert-DockerReady

foreach ($service in $Services) {
  if ($service -notin $ValidServices) {
    throw "Unknown LearnHub service '$service'. Valid services: $($ValidServices -join ', ')"
  }

  $image = "learnhub/${service}:$Tag"
  Write-Host "Building $image"
  Invoke-Docker "build" `
    "--build-arg" "APP_VERSION=$Tag" `
    "--build-arg" "GIT_COMMIT=$gitCommit" `
    "--build-arg" "BUILD_DATE=$buildDate" `
    "-t" $image `
    "-f" "services/$service/Dockerfile" `
    "."
}

Write-Host "Done. Built $($Services.Count) LearnHub images with tag $Tag."
