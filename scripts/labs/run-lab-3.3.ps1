param(
  [switch]$SkipBuild,
  [int]$NamespaceDeleteTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

Write-Host "Lab 3.3 - ServiceAccount & RBAC using Kubernetes API from a Pod"

Assert-DockerReady
Assert-KubernetesReady

if (-not $SkipBuild) {
  Build-LearnHubImages -Services @("course-service")
} else {
  Assert-DockerImages -Images @("learnhub/course-service:0.1.0")
}

Ensure-DockerImage -Image "curlimages/curl:8.10.1"

$Namespace = "rbac-lab"
$Manifest = "k8s/labs/lab-3.3-serviceaccount-rbac.yaml"

Reset-LabNamespace -Namespace $Namespace -TimeoutSeconds $NamespaceDeleteTimeoutSeconds -LabName "Lab 3.3"

Invoke-Kubectl "apply" "-f" $Manifest
Invoke-Kubectl "wait" "--for=condition=Ready" "pod/learnhub-rbac-api" "-n" $Namespace "--timeout=120s"
Invoke-Kubectl "wait" "--for=condition=Ready" "pod/learnhub-rbac-client" "-n" $Namespace "--timeout=120s"

Invoke-Kubectl "get" "serviceaccount,role,rolebinding,pod" "-n" $Namespace

Write-Host "Listing Pods through the Kubernetes API using the mounted ServiceAccount token."
$podsJson = Invoke-KubectlOutput "exec" "pod/learnhub-rbac-client" "-n" $Namespace "-c" "api-client" "--" "sh" "/scripts/list-pods.sh"
Assert-OutputContains -Output $podsJson -Expected "learnhub-rbac-api" -Context "Lab 3.3 pod list"
Assert-OutputContains -Output $podsJson -Expected "learnhub-rbac-client" -Context "Lab 3.3 pod list"
Write-Host "Kubernetes API PodList contains learnhub-rbac-api and learnhub-rbac-client."

Write-Host "Checking least privilege: the same ServiceAccount must not list Secrets."
$denyOutput = Invoke-KubectlOutput "exec" "pod/learnhub-rbac-client" "-n" $Namespace "-c" "api-client" "--" "sh" "/scripts/deny-secrets.sh"
$denyOutput | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $denyOutput -Expected "HTTP_CODE=403" -Context "Lab 3.3 least privilege check"
