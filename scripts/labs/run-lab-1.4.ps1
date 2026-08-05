param(
  [switch]$SkipBuild,
  [int]$NamespaceDeleteTimeoutSeconds = 60
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

Write-Host "Lab 1.4 - Label & Annotation Drill using real LearnHub images"

Assert-DockerReady
Assert-KubernetesReady

if (-not $SkipBuild) {
  Build-LearnHubImages -Services @("user-service", "course-service", "payment-service", "notification-service")
} else {
  Assert-DockerImages -Images @(
    "learnhub/user-service:0.1.0",
    "learnhub/course-service:0.1.0",
    "learnhub/payment-service:0.1.0",
    "learnhub/notification-service:0.1.0"
  )
}

$Namespace = "label-lab"
$Manifest = "k8s/labs/lab-1.4-label-annotation-drill.yaml"

Reset-LabNamespace -Namespace $Namespace -TimeoutSeconds $NamespaceDeleteTimeoutSeconds -LabName "Lab 1.4"

Invoke-Kubectl "apply" "-f" $Manifest
Invoke-Kubectl "wait" "--for=condition=Ready" "pod" "-l" "app=learnhub" "-n" $Namespace "--timeout=180s"

Write-Host "Initial pods:"
Invoke-Kubectl "get" "pods" "-n" $Namespace "--show-labels"
$podImages = Invoke-KubectlOutput "get" "pods" "-n" $Namespace "-o" "custom-columns=POD:.metadata.name,IMAGE:.spec.containers[*].image,STATUS:.status.phase"
$podImages | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $podImages -Expected "learnhub/user-service:0.1.0" -Context "Lab 1.4 user-service image check"
Assert-OutputContains -Output $podImages -Expected "learnhub/course-service:0.1.0" -Context "Lab 1.4 course-service image check"
Assert-OutputContains -Output $podImages -Expected "learnhub/payment-service:0.1.0" -Context "Lab 1.4 payment-service image check"
Assert-OutputContains -Output $podImages -Expected "learnhub/notification-service:0.1.0" -Context "Lab 1.4 notification-service image check"

Invoke-Kubectl "label" "pods" "-n" $Namespace "-l" "app=learnhub" "managed-by=kubectl-drill"
Invoke-Kubectl "label" "pods" "-n" $Namespace "-l" "tier=api" "exposure=internal"
Invoke-Kubectl "label" "pods" "-n" $Namespace "-l" "tier=worker" "queue=batch"
Invoke-Kubectl "label" "pod" "user-api-1" "-n" $Namespace "track=stable" "--overwrite"
Invoke-Kubectl "label" "pod" "user-api-2" "-n" $Namespace "env=staging" "--overwrite"
Invoke-Kubectl "annotate" "pods" "-n" $Namespace "-l" "app=learnhub" "learnhub.io/reviewed-by=quang"
Invoke-Kubectl "annotate" "pods" "-n" $Namespace "-l" "tier=worker" "learnhub.io/runbook=worker-runbook"
Invoke-Kubectl "annotate" "pod" "user-api-1" "-n" $Namespace "learnhub.io/note=updated-by-lab-1.4" "--overwrite"

Write-Host "Verification queries:"
Invoke-Kubectl "get" "pods" "-n" $Namespace "--show-labels"
Invoke-Kubectl "get" "pods" "-n" $Namespace "-l" "tier=api,exposure=internal"
Invoke-Kubectl "get" "pods" "-n" $Namespace "-l" "tier=worker,queue=batch"
Invoke-Kubectl "get" "pods" "-n" $Namespace "-l" "component=user,track=stable"
