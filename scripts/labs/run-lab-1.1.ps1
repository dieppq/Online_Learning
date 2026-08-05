param(
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

Write-Host "Lab 1.1 - The 60 Second Pod using learnhub/course-service:0.1.0"

Assert-DockerReady
Assert-KubernetesReady

if (-not $SkipBuild) {
  Build-LearnHubImages -Services @("course-service")
} else {
  Assert-DockerImages -Images @("learnhub/course-service:0.1.0")
}

Ensure-DockerImage -Image "curlimages/curl:8.10.1"

$existingNamespace = Invoke-KubectlOutput "get" "namespace" "ckad-lab" "-o" "name" "--ignore-not-found"
if ([string]::IsNullOrWhiteSpace($existingNamespace)) {
  Invoke-Kubectl "create" "namespace" "ckad-lab"
}

Remove-PodIfExists -Name "learnhub-60s" -Namespace "ckad-lab"

Invoke-Kubectl "apply" "-f" "k8s/labs/lab-1.1-60-second-pod.yaml"
Invoke-Kubectl "wait" "--for=condition=Ready" "pod/learnhub-60s" "-n" "ckad-lab" "--timeout=120s"

Invoke-Kubectl "get" "pod" "learnhub-60s" "-n" "ckad-lab" "--show-labels"
Invoke-Kubectl "get" "pod" "learnhub-60s" "-n" "ckad-lab" "-o" "custom-columns=POD:.metadata.name,IMAGE:.spec.containers[*].image,STATUS:.status.phase"
Invoke-Kubectl "get" "pod" "learnhub-60s" "-n" "ckad-lab" "-o" "jsonpath={.spec.containers[0].resources}"
Write-Host ""
Invoke-Kubectl "logs" "learnhub-60s" "-n" "ckad-lab" "--tail=20"

Write-Host ""
Write-Host "Smoke test course-service API from a temporary Pod:"
$podIP = Invoke-KubectlOutput "get" "pod" "learnhub-60s" "-n" "ckad-lab" "-o" "jsonpath={.status.podIP}"
$response = Invoke-TemporaryCurlOutput -Name "learnhub-60s-client" -Namespace "ckad-lab" -Url "http://${podIP}:8080/api/courses"
$response | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $response -Expected "c-k8s-ckad" -Context "Lab 1.1 course-service smoke test"

Write-Host ""
Write-Host "Optional access test:"
Write-Host "kubectl port-forward pod/learnhub-60s 8082:8080 -n ckad-lab"
Write-Host "curl http://localhost:8082/api/courses"
