param(
  [switch]$SkipBuild,
  [int]$NamespaceDeleteTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

Write-Host "Lab 2.2 - Blue/Green Switch using learnhub/course-service"

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

$Namespace = "bluegreen-lab"
$Manifest = "k8s/labs/lab-2.2-blue-green-switch.yaml"
$BlueServiceManifest = "k8s/labs/lab-2.2-service-blue.yaml"
$GreenServiceManifest = "k8s/labs/lab-2.2-service-green.yaml"

Reset-LabNamespace -Namespace $Namespace -TimeoutSeconds $NamespaceDeleteTimeoutSeconds -LabName "Lab 2.2"

Invoke-Kubectl "apply" "-f" $Manifest
Invoke-Kubectl "rollout" "status" "deployment/learnhub-course-blue" "-n" $Namespace "--timeout=120s"
Invoke-Kubectl "rollout" "status" "deployment/learnhub-course-green" "-n" $Namespace "--timeout=120s"

Write-Host "Initial selector:"
Invoke-Kubectl "get" "svc" "learnhub-course-api" "-n" $Namespace "-o" "jsonpath={.spec.selector}"
Write-Host ""

Write-Host "Calling blue through Service:"
$blueResponse = Invoke-TemporaryCurlOutput -Name "bluegreen-client" -Namespace $Namespace -Url "http://learnhub-course-api/healthz"
$blueResponse | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $blueResponse -Expected "course-service-blue" -Context "Lab 2.2 blue Service response"

Write-Host "Switching to green."
Invoke-Kubectl "apply" "-f" $GreenServiceManifest
Invoke-Kubectl "get" "svc" "learnhub-course-api" "-n" $Namespace "-o" "jsonpath={.spec.selector}"
Write-Host ""
Invoke-Kubectl "get" "endpoints" "learnhub-course-api" "-n" $Namespace

Write-Host "Calling green through Service:"
$greenResponse = Invoke-TemporaryCurlOutput -Name "bluegreen-client" -Namespace $Namespace -Url "http://learnhub-course-api/healthz"
$greenResponse | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $greenResponse -Expected "course-service-green" -Context "Lab 2.2 green Service response"

Write-Host "Switching back to blue."
Invoke-Kubectl "apply" "-f" $BlueServiceManifest
Invoke-Kubectl "get" "svc" "learnhub-course-api" "-n" $Namespace "-o" "jsonpath={.spec.selector}"
Write-Host ""
$blueAgainResponse = Invoke-TemporaryCurlOutput -Name "bluegreen-client" -Namespace $Namespace -Url "http://learnhub-course-api/healthz"
$blueAgainResponse | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $blueAgainResponse -Expected "course-service-blue" -Context "Lab 2.2 blue rollback Service response"
