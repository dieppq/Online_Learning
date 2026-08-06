param(
  [switch]$SkipGoTest
)

$ErrorActionPreference = "Stop"

$CapstoneRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ProjectRoot = Resolve-Path (Join-Path $CapstoneRoot "..")
. (Join-Path $ProjectRoot "scripts\common.ps1")

function Assert-FileContains {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Pattern
  )

  if (-not (Select-String -Path $Path -Pattern $Pattern -Quiet)) {
    throw "$Path does not satisfy required pattern: $Pattern"
  }
}

Push-Location $ProjectRoot
try {
  $services = @(
    "user-service",
    "course-service",
    "enrollment-service",
    "payment-service",
    "notification-service"
  )

  foreach ($service in $services) {
    Assert-FileContains -Path "services/$service/Dockerfile" -Pattern "ARG APP_VERSION"
    Assert-FileContains -Path "services/$service/Dockerfile" -Pattern "USER 10001:10001"
    Assert-FileContains -Path "services/$service/main.go" -Pattern "platform.ServeHTTP"
  }

  $workloadManifests = @(
    "user-service.yaml",
    "course-service-blue.yaml",
    "course-service-green.yaml",
    "enrollment-service.yaml",
    "payment-service.yaml",
    "notification-service.yaml"
  )
  foreach ($manifest in $workloadManifests) {
    Assert-FileContains -Path "capstone/k8s/base/$manifest" -Pattern "terminationGracePeriodSeconds: 30"
  }

  Assert-FileContains -Path "internal/platform/http.go" -Pattern "slog.NewJSONHandler"
  Assert-FileContains -Path "internal/platform/http.go" -Pattern "server.Shutdown"
  Assert-FileContains -Path "internal/platform/http.go" -Pattern 'HandleFunc\("/metrics"'
  Assert-FileContains -Path "internal/platform/http.go" -Pattern "ReadinessCheck"
  Assert-FileContains -Path "internal/platform/backing.go" -Pattern "sql.Open"
  Assert-FileContains -Path "internal/platform/cache.go" -Pattern "redis.NewClient"
  Assert-FileContains -Path "internal/platform/objectstore.go" -Pattern "minio.New"
  Assert-FileContains -Path "internal/platform/events.go" -Pattern "ConnectJetStream"
  Assert-FileContains -Path "internal/platform/events.go" -Pattern "SubscribeDurable"
  Assert-FileContains -Path "services/payment-service/main.go" -Pattern "outbox_events"
  Assert-FileContains -Path "services/enrollment-service/main.go" -Pattern "progressCacheKey"
  Assert-FileContains -Path "services/notification-service/main.go" -Pattern "SubscribeDurable"
  Assert-FileContains -Path "services/course-service/main.go" -Pattern "PutObject"
  Assert-FileContains -Path "capstone/k8s/base/configmap.yaml" -Pattern 'LOG_FORMAT: "json"'
  Assert-FileContains -Path "capstone/k8s/base/database-migrations.yaml" -Pattern "schema_migrations"
  Assert-FileContains -Path "capstone/k8s/base/database-business-migrations.yaml" -Pattern "CREATE TABLE IF NOT EXISTS payments"
  Assert-FileContains -Path "capstone/k8s/base/database-reliability-migrations.yaml" -Pattern "outbox_events"
  Assert-FileContains -Path "capstone/k8s/base/nats.yaml" -Pattern "-js"

  $shellScripts = @("build.sh", "create-secret.sh", "deploy.sh", "smoke-test.sh", "blue-green-switch.sh", "install-ingress-nginx.sh", "cleanup.sh", "promote-images.sh")
  foreach ($script in $shellScripts) {
    Assert-FileContains -Path "capstone/scripts/$script" -Pattern '^#!/usr/bin/env sh'
  }

  $forbiddenSecretFiles = @(
    "k8s/base/secret.yaml",
    "k8s/infra/secret.yaml",
    "k8s/labs/lab-3.1-configmap-secret-injection/jwt-secret.txt"
  )
  foreach ($secretFile in $forbiddenSecretFiles) {
    if (Test-Path $secretFile) {
      throw "Plaintext Secret file must not be tracked: $secretFile"
    }
  }

  Invoke-Kubectl "kustomize" "capstone/k8s/overlays/dev" *> $null
  Invoke-Kubectl "kustomize" "capstone/k8s/overlays/prod" *> $null
  Invoke-Kubectl "kustomize" "capstone/k8s/observability" *> $null
  Invoke-Docker "compose" "--env-file" "configs/env/local.env.example" "config" "--quiet"

  $helm = Join-Path $ProjectRoot ".tools\helm\windows-amd64\helm.exe"
  if (-not (Test-Path $helm)) {
    throw "Helm binary not found at $helm"
  }

  $charts = @(
    "learnhub-common",
    "user-service",
    "course-service",
    "enrollment-service",
    "payment-service",
    "notification-service",
    "web-ui"
  )
  foreach ($chart in $charts) {
    Invoke-External $helm "lint" "capstone/helm/$chart"
  }

  if (-not $SkipGoTest) {
    Invoke-Docker "run" "--rm" "-v" "${ProjectRoot}:/src" "-v" "learnhub-go-mod:/go/pkg/mod" "-v" "learnhub-go-build:/root/.cache/go-build" "-w" "/src" "golang:1.22-alpine" "go" "test" "./..."
  }

  Write-Host "12-factor checks passed: code, dependencies, config, backing services, release metadata, stateless processes, port binding, concurrency, disposability, parity, stdout logs and admin jobs."
} finally {
  Pop-Location
}
