param(
  [switch]$SkipBuild,
  [int]$NamespaceDeleteTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

Write-Host "Lab 2.1 - Rolling Update & Rollback using learnhub/course-service"

Assert-DockerReady
Assert-KubernetesReady

if (-not $SkipBuild) {
  Build-LearnHubImages -Tags @("0.1.0", "0.1.1") -Services @("course-service")
} else {
  Assert-DockerImages -Images @(
    "learnhub/course-service:0.1.0",
    "learnhub/course-service:0.1.1"
  )
}

Ensure-DockerImage -Image "curlimages/curl:8.10.1"

$Namespace = "rollout-lab"
$Manifest = "k8s/labs/lab-2.1-rolling-update-rollback.yaml"
$UpdateManifest = "k8s/labs/lab-2.1-rolling-update-v1.1.yaml"
$BadManifest = "k8s/labs/lab-2.1-rolling-update-bad.yaml"

Reset-LabNamespace -Namespace $Namespace -TimeoutSeconds $NamespaceDeleteTimeoutSeconds -LabName "Lab 2.1"

Invoke-Kubectl "apply" "-f" $Manifest
Invoke-Kubectl "rollout" "status" "deployment/learnhub-course-api" "-n" $Namespace "--timeout=120s"

Write-Host "Initial image:"
$initialImage = Invoke-KubectlOutput "get" "deploy" "learnhub-course-api" "-n" $Namespace "-o" "jsonpath={.spec.template.spec.containers[0].image}"
Write-Host $initialImage
Assert-OutputContains -Output $initialImage -Expected "learnhub/course-service:0.1.0" -Context "Lab 2.1 initial image"
Write-Host ""

Write-Host "Rolling update to learnhub/course-service:0.1.1"
Invoke-Kubectl "apply" "-f" $UpdateManifest
Invoke-Kubectl "rollout" "status" "deployment/learnhub-course-api" "-n" $Namespace "--timeout=180s"
$updatedImage = Invoke-KubectlOutput "get" "deploy" "learnhub-course-api" "-n" $Namespace "-o" "jsonpath={.spec.template.spec.containers[0].image}"
Write-Host $updatedImage
Assert-OutputContains -Output $updatedImage -Expected "learnhub/course-service:0.1.1" -Context "Lab 2.1 updated image"
Write-Host ""

Write-Host "Simulating bad deployment."
Invoke-Kubectl "apply" "-f" $BadManifest
$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  $badRolloutOutput = kubectl rollout status deployment/learnhub-course-api -n $Namespace --timeout=30s 2>&1
  $badRolloutExitCode = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $oldErrorActionPreference
}
if ($badRolloutExitCode -eq 0) {
  throw "Expected rollout to fail, but it completed."
}
Write-Host "Bad rollout failed as expected because the image tag does not exist."
$badRolloutOutput | ForEach-Object { Write-Host $_ }

Invoke-Kubectl "get" "pod" "-n" $Namespace
Invoke-Kubectl "describe" "pod" "-n" $Namespace "-l" "app=learnhub-course-api"

Write-Host "Rolling back."
Invoke-Kubectl "rollout" "undo" "deployment/learnhub-course-api" "-n" $Namespace
Invoke-Kubectl "rollout" "status" "deployment/learnhub-course-api" "-n" $Namespace "--timeout=180s"
$rollbackImage = Invoke-KubectlOutput "get" "deploy" "learnhub-course-api" "-n" $Namespace "-o" "jsonpath={.spec.template.spec.containers[0].image}"
Write-Host "Image after rollback: $rollbackImage"
Assert-OutputContains -Output $rollbackImage -Expected "learnhub/course-service:0.1.1" -Context "Lab 2.1 rollback image"
Invoke-Kubectl "rollout" "history" "deployment/learnhub-course-api" "-n" $Namespace

Write-Host "Smoke test course-service API after rollback:"
$response = Invoke-TemporaryCurlOutput -Name "rollout-client" -Namespace $Namespace -Url "http://learnhub-course-api/api/courses"
$response | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $response -Expected "c-k8s-ckad" -Context "Lab 2.1 course-service smoke test"
