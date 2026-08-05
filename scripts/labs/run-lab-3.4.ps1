param(
  [switch]$SkipBuild,
  [int]$NamespaceDeleteTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

Write-Host "Lab 3.4 - Namespace Quotas using LearnHub Pods"

Assert-DockerReady
Assert-KubernetesReady

if (-not $SkipBuild) {
  Build-LearnHubImages -Services @("user-service", "course-service")
} else {
  Assert-DockerImages -Images @(
    "learnhub/user-service:0.1.0",
    "learnhub/course-service:0.1.0"
  )
}

$Namespace = "quota-lab"
$QuotaManifest = "k8s/labs/lab-3.4-quota-limitrange.yaml"
$AllowedPodsManifest = "k8s/labs/lab-3.4-quota-allowed-pods.yaml"
$ExceededPodManifest = "k8s/labs/lab-3.4-quota-exceeded-pod.yaml"

Reset-LabNamespace -Namespace $Namespace -TimeoutSeconds $NamespaceDeleteTimeoutSeconds -LabName "Lab 3.4"

Invoke-Kubectl "apply" "-f" $QuotaManifest
Invoke-Kubectl "get" "resourcequota,limitrange" "-n" $Namespace

Write-Host "Creating two allowed LearnHub Pods. LimitRange should inject default requests and limits."
Invoke-Kubectl "apply" "-f" $AllowedPodsManifest
Invoke-Kubectl "wait" "--for=condition=Ready" "pod/learnhub-quota-user" "-n" $Namespace "--timeout=120s"
Invoke-Kubectl "wait" "--for=condition=Ready" "pod/learnhub-quota-course" "-n" $Namespace "--timeout=120s"
Invoke-Kubectl "get" "pods" "-n" $Namespace "-o" "custom-columns=POD:.metadata.name,IMAGE:.spec.containers[*].image,STATUS:.status.phase"

$defaultResources = Invoke-KubectlOutput "get" "pod" "learnhub-quota-course" "-n" $Namespace "-o" "jsonpath={.spec.containers[0].resources}"
Write-Host "LimitRange-injected resources on learnhub-quota-course:"
Write-Host $defaultResources
Assert-OutputContains -Output $defaultResources -Expected "50m" -Context "Lab 3.4 default cpu request"
Assert-OutputContains -Output $defaultResources -Expected "64Mi" -Context "Lab 3.4 default memory request"
Assert-OutputContains -Output $defaultResources -Expected "200m" -Context "Lab 3.4 default cpu limit"
Assert-OutputContains -Output $defaultResources -Expected "128Mi" -Context "Lab 3.4 default memory limit"

Invoke-Kubectl "describe" "resourcequota" "learnhub-app-quota" "-n" $Namespace

Write-Host "Trying to create a third Pod. This should be rejected by ResourceQuota hard.pods=2."
$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  $rejectionOutput = kubectl apply -f $ExceededPodManifest 2>&1
  $rejectionExitCode = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $oldErrorActionPreference
}
if ($rejectionExitCode -eq 0) {
  throw "Expected quota rejection, but the third Pod was created."
}

$rejectionOutput | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $rejectionOutput -Expected "exceeded quota" -Context "Lab 3.4 quota rejection"

Invoke-Kubectl "get" "pods" "-n" $Namespace
Invoke-Kubectl "describe" "resourcequota" "learnhub-app-quota" "-n" $Namespace
