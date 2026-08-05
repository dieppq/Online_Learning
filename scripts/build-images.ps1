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
  Invoke-Docker "build" "-t" $image "-f" "services/$service/Dockerfile" "."
}

Write-Host "Done. Built $($Services.Count) LearnHub images with tag $Tag."
