param(
  [switch]$SkipBuild,
  [int]$NamespaceDeleteTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

Write-Host "Lab 2.4 - Kustomize Overlay using learnhub/course-service"

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

Write-Host "Rendered dev image/replicas:"
$devRender = Invoke-KubectlOutput "kustomize" "k8s/labs/lab-2.4-kustomize/overlays/dev"
$devRender | Select-String "namespace:|image:|replicas:|env:"
Assert-OutputContains -Output $devRender -Expected "namespace: kustomize-dev" -Context "Lab 2.4 dev render namespace"
Assert-OutputContains -Output $devRender -Expected "replicas: 1" -Context "Lab 2.4 dev render replicas"
Assert-OutputContains -Output $devRender -Expected "image: learnhub/course-service:0.1.0" -Context "Lab 2.4 dev render image"
Assert-OutputContains -Output $devRender -Expected "value: 0.1.0" -Context "Lab 2.4 dev APP_VERSION"

Write-Host "Rendered prod image/replicas:"
$prodRender = Invoke-KubectlOutput "kustomize" "k8s/labs/lab-2.4-kustomize/overlays/prod"
$prodRender | Select-String "namespace:|image:|replicas:|env:"
Assert-OutputContains -Output $prodRender -Expected "namespace: kustomize-prod" -Context "Lab 2.4 prod render namespace"
Assert-OutputContains -Output $prodRender -Expected "replicas: 4" -Context "Lab 2.4 prod render replicas"
Assert-OutputContains -Output $prodRender -Expected "image: learnhub/course-service:0.1.1" -Context "Lab 2.4 prod render image"
Assert-OutputContains -Output $prodRender -Expected "value: 0.1.1" -Context "Lab 2.4 prod APP_VERSION"

Reset-LabNamespace -Namespace "kustomize-prod" -TimeoutSeconds $NamespaceDeleteTimeoutSeconds -LabName "Lab 2.4"
Reset-LabNamespace -Namespace "kustomize-dev" -TimeoutSeconds $NamespaceDeleteTimeoutSeconds -LabName "Lab 2.4"

Invoke-Kubectl "apply" "-k" "k8s/labs/lab-2.4-kustomize/overlays/prod"
Invoke-Kubectl "rollout" "status" "deployment/learnhub-course-kustomize" "-n" "kustomize-prod" "--timeout=120s"
Invoke-Kubectl "get" "deployment" "learnhub-course-kustomize" "-n" "kustomize-prod" "-o" "custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[*].image,READY:.status.readyReplicas,DESIRED:.spec.replicas"

Invoke-Kubectl "apply" "-k" "k8s/labs/lab-2.4-kustomize/overlays/dev"
Invoke-Kubectl "rollout" "status" "deployment/learnhub-course-kustomize" "-n" "kustomize-dev" "--timeout=120s"
Invoke-Kubectl "get" "deployment" "learnhub-course-kustomize" "-n" "kustomize-dev" "-o" "custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[*].image,READY:.status.readyReplicas,DESIRED:.spec.replicas"

Write-Host "Calling prod Service:"
$response = Invoke-TemporaryCurlOutput -Name "kustomize-client" -Namespace "kustomize-prod" -Url "http://learnhub-course-kustomize/api/courses"
$response | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $response -Expected "c-k8s-ckad" -Context "Lab 2.4 course-service smoke test"
