param(
  [switch]$SkipInfra
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\common.ps1"

Assert-KubernetesReady

if (-not $SkipInfra) {
  Write-Host "Applying lab infrastructure"
  Invoke-Kubectl "apply" "-k" "k8s/infra"
}

Write-Host "Applying LearnHub services"
Invoke-Kubectl "apply" "-k" "k8s/base"

$deployments = @(
  "user-service",
  "course-service",
  "enrollment-service",
  "payment-service",
  "notification-service"
)

foreach ($deployment in $deployments) {
  Invoke-Kubectl "rollout" "status" "deployment/$deployment" "-n" "learnhub-lab" "--timeout=120s"
}

Invoke-Kubectl "get" "deploy,rs,pod,svc" "-n" "learnhub-lab"
