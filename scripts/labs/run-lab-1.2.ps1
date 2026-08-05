param(
  [switch]$SkipBuild,
  [switch]$SkipLearnHubDeploy
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

Write-Host "Lab 1.2 - Init + Sidecar Pattern using real LearnHub APIs"

Assert-DockerReady
Assert-KubernetesReady

if (-not $SkipBuild) {
  Build-LearnHubImages
} else {
  Assert-DockerImages -Images @(
    "learnhub/user-service:0.1.0",
    "learnhub/course-service:0.1.0",
    "learnhub/enrollment-service:0.1.0",
    "learnhub/payment-service:0.1.0",
    "learnhub/notification-service:0.1.0"
  )
}

if (-not $SkipLearnHubDeploy) {
  & "$ProjectRoot\scripts\deploy.ps1"
}

Assert-LearnHubServicesReady
Ensure-DockerImage -Image "curlimages/curl:8.10.1"
Ensure-DockerImage -Image "busybox:1.36"

if (Test-NamespaceExists -Namespace "ckad-lab") {
  Invoke-Kubectl "delete" "pod" "learnhub-init-sidecar" "-n" "ckad-lab" "--ignore-not-found"
}
Invoke-Kubectl "apply" "-f" "k8s/labs/lab-2-init-sidecar.yaml"
Invoke-Kubectl "wait" "--for=condition=Ready" "pod/learnhub-init-sidecar" "-n" "ckad-lab" "--timeout=180s"

Invoke-Kubectl "get" "pod" "learnhub-init-sidecar" "-n" "ckad-lab" "-o" "wide"
Write-Host "Init status:"
$initStatus = Invoke-KubectlOutput "get" "pod" "learnhub-init-sidecar" "-n" "ckad-lab" "-o" "jsonpath={.status.initContainerStatuses[0].state.terminated.reason}"
Write-Host $initStatus
Assert-OutputContains -Output $initStatus -Expected "Completed" -Context "Lab 1.2 init container status"
Write-Host ""

Write-Host "Course metadata created by init container:"
$courseMetadata = Invoke-KubectlOutput "exec" "learnhub-init-sidecar" "-n" "ckad-lab" "-c" "app" "--" "cat" "/shared/config/course.json"
$courseMetadata | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $courseMetadata -Expected "c-k8s-ckad" -Context "Lab 1.2 course metadata"
Write-Host ""

Write-Host "Sidecar logs:"
Invoke-Kubectl "logs" "learnhub-init-sidecar" "-n" "ckad-lab" "-c" "log-sidecar" "--tail=30"
