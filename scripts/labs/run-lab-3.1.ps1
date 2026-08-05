param(
  [switch]$SkipBuild,
  [int]$NamespaceDeleteTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

Write-Host "Lab 3.1 - ConfigMap & Secret Injection using learnhub/course-service"

Assert-DockerReady
Assert-KubernetesReady

if (-not $SkipBuild) {
  Build-LearnHubImages -Services @("course-service")
} else {
  Assert-DockerImages -Images @("learnhub/course-service:0.1.0")
}

Ensure-DockerImage -Image "busybox:1.36"
Ensure-DockerImage -Image "curlimages/curl:8.10.1"

$Namespace = "config-lab"
$Manifest = "k8s/labs/lab-3.1-configmap-secret-injection"

Reset-LabNamespace -Namespace $Namespace -TimeoutSeconds $NamespaceDeleteTimeoutSeconds -LabName "Lab 3.1"

Write-Host "Applying Kustomize YAML. It generates ConfigMap from literals and Secret from jwt-secret.txt."
Invoke-Kubectl "apply" "-k" $Manifest
Invoke-Kubectl "wait" "--for=condition=Ready" "pod/learnhub-configured-course" "-n" $Namespace "--timeout=120s"

Invoke-Kubectl "get" "configmap" "learnhub-course-runtime" "-n" $Namespace "-o" "yaml"
Invoke-Kubectl "describe" "secret" "learnhub-jwt-secret" "-n" $Namespace
Invoke-Kubectl "get" "pod" "learnhub-configured-course" "-n" $Namespace "-o" "custom-columns=POD:.metadata.name,READY:.status.containerStatuses[*].ready,IMAGE:.spec.containers[*].image,STATUS:.status.phase"

Write-Host "Inspecting injected config and secret without printing the secret value."
$inspectionCommand = 'set -eu; printf "COURSE_ID="; cat /etc/learnhub-config/COURSE_ID; echo; printf "LOG_LEVEL="; cat /etc/learnhub-config/LOG_LEVEL; echo; if [ -n "$JWT_SECRET" ]; then echo "JWT_SECRET=present"; else echo "JWT_SECRET=missing"; exit 1; fi'
$inspection = Invoke-KubectlOutput "exec" "pod/learnhub-configured-course" "-n" $Namespace "-c" "config-reader" "--" "sh" "-c" $inspectionCommand
$inspection | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $inspection -Expected "COURSE_ID=c-k8s-ckad" -Context "Lab 3.1 ConfigMap mount"
Assert-OutputContains -Output $inspection -Expected "LOG_LEVEL=debug" -Context "Lab 3.1 ConfigMap mount"
Assert-OutputContains -Output $inspection -Expected "JWT_SECRET=present" -Context "Lab 3.1 Secret env injection"

Write-Host "Smoke test course-service API through Service:"
$response = Invoke-TemporaryCurlOutput -Name "config-client" -Namespace $Namespace -Url "http://learnhub-configured-course/api/courses"
$response | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $response -Expected "c-k8s-ckad" -Context "Lab 3.1 course-service smoke test"
