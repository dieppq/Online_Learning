param(
  [ValidateSet("dev", "prod")]
  [string]$Overlay = "dev",
  [switch]$SkipBuild,
  [switch]$SkipSecret,
  [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

$CapstoneRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ProjectRoot = Resolve-Path (Join-Path $CapstoneRoot "..")
. (Join-Path $ProjectRoot "scripts\common.ps1")

$Namespace = "learnhub-capstone-$Overlay"
$OverlayPath = "capstone/k8s/overlays/$Overlay"

Assert-KubernetesReady

Push-Location $ProjectRoot
try {
  if (-not $SkipBuild) {
    & (Join-Path $CapstoneRoot "scripts\build.ps1")
    if ($LASTEXITCODE -ne 0) {
      throw "Capstone image build failed."
    }
  }

  if (-not $SkipSecret) {
    & (Join-Path $CapstoneRoot "scripts\create-secret.ps1") -Namespace $Namespace
    if ($LASTEXITCODE -ne 0) {
      throw "Capstone secret creation failed."
    }
  }

  Invoke-Kubectl "apply" "-k" $OverlayPath

  $migrationJobs = @(
    "user-db-migrate-v001",
    "course-db-migrate-v001",
    "enrollment-db-migrate-v001",
    "payment-db-migrate-v001",
    "notification-db-migrate-v001",
    "user-db-migrate-v002",
    "course-db-migrate-v002",
    "enrollment-db-migrate-v002",
    "payment-db-migrate-v002",
    "notification-db-migrate-v002"
  )

  foreach ($job in $migrationJobs) {
    Invoke-Kubectl "wait" "--for=condition=complete" "job/$job" "-n" $Namespace "--timeout=${TimeoutSeconds}s"
  }

  $deployments = @(
    "user-postgresql",
    "course-postgresql",
    "enrollment-postgresql",
    "payment-postgresql",
    "notification-postgresql",
    "redis",
    "nats",
    "minio",
    "web-ui",
    "user-service",
    "course-service-blue",
    "course-service-green",
    "enrollment-service",
    "payment-service",
    "notification-service"
  )

  foreach ($deployment in $deployments) {
    Invoke-Kubectl "rollout" "status" "deployment/$deployment" "-n" $Namespace "--timeout=${TimeoutSeconds}s"
  }

  Invoke-Kubectl "get" "deploy,pod,svc,endpoints,ingress,hpa,pvc,job,cronjob" "-n" $Namespace

  Write-Host "Capstone overlay '$Overlay' is deployed in namespace $Namespace."
} finally {
  Pop-Location
}
