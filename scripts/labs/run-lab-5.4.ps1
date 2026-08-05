param(
  [switch]$SkipBuild,
  [string]$HelmPath = "",
  [int]$NamespaceDeleteTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

function Resolve-HelmExecutable {
  param(
    [string]$RequestedHelmPath
  )

  if (-not [string]::IsNullOrWhiteSpace($RequestedHelmPath)) {
    if (Test-Path $RequestedHelmPath) {
      return (Resolve-Path $RequestedHelmPath).Path
    }

    return $RequestedHelmPath
  }

  $helmCommand = Get-Command "helm" -ErrorAction SilentlyContinue
  if ($helmCommand) {
    return $helmCommand.Source
  }

  $localHelm = Join-Path $ProjectRoot ".tools\helm\windows-amd64\helm.exe"
  if (Test-Path $localHelm) {
    return $localHelm
  }

  throw "Helm was not found. Install Helm, pass -HelmPath, or place helm.exe at .tools\helm\windows-amd64\helm.exe."
}

function Invoke-Helm {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgumentList
  )

  & $script:ResolvedHelm @ArgumentList
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    throw "$script:ResolvedHelm failed with exit code $exitCode. Args: $($ArgumentList -join ' ')"
  }
}

function Invoke-HelmOutput {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgumentList
  )

  $output = & $script:ResolvedHelm @ArgumentList
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    throw "$script:ResolvedHelm failed with exit code $exitCode. Args: $($ArgumentList -join ' ')"
  }

  return $output
}

Write-Host "Lab 5.4 - Helm Deploy & Rollback"

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

$script:ResolvedHelm = Resolve-HelmExecutable -RequestedHelmPath $HelmPath
Write-Host "Using Helm: $script:ResolvedHelm"
Invoke-Helm "version" "--short"

$Namespace = "helm-lab"
$Release = "learnhub-course"
$ChartPath = "k8s/labs/lab-5.4-helm/learnhub-course"

Reset-LabNamespace -Namespace $Namespace -TimeoutSeconds $NamespaceDeleteTimeoutSeconds -LabName "Lab 5.4"

Invoke-Helm "lint" $ChartPath
$rendered = Invoke-HelmOutput "template" $Release $ChartPath "--namespace" $Namespace "--set" "image.tag=0.1.0" "--set" "replicaCount=2" "--set" "appVersion=0.1.0"
Assert-OutputContains -Output $rendered -Expected "image: `"learnhub/course-service:0.1.0`"" -Context "Lab 5.4 helm template v1 image"

Write-Host "Installing Helm release revision 1."
Invoke-Helm "install" $Release $ChartPath "--namespace" $Namespace "--create-namespace" "--set" "image.tag=0.1.0" "--set" "replicaCount=2" "--set" "appVersion=0.1.0"
Invoke-Kubectl "rollout" "status" "deployment/learnhub-course-helm" "-n" $Namespace "--timeout=120s"
Invoke-Helm "status" $Release "--namespace" $Namespace

$v1Image = Invoke-KubectlOutput "get" "deployment" "learnhub-course-helm" "-n" $Namespace "-o" "jsonpath={.spec.template.spec.containers[0].image}"
Write-Host "Installed image: $v1Image"
Assert-OutputContains -Output $v1Image -Expected "learnhub/course-service:0.1.0" -Context "Lab 5.4 installed image"

$v1Response = Invoke-TemporaryCurlOutput -Name "helm-client-v1" -Namespace $Namespace -Url "http://learnhub-course-helm/api/courses"
$v1Response | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $v1Response -Expected "c-k8s-ckad" -Context "Lab 5.4 v1 smoke test"

Write-Host "Upgrading Helm release to revision 2."
Invoke-Helm "upgrade" $Release $ChartPath "--namespace" $Namespace "--set" "image.tag=0.1.1" "--set" "replicaCount=3" "--set" "appVersion=0.1.1"
Invoke-Kubectl "rollout" "status" "deployment/learnhub-course-helm" "-n" $Namespace "--timeout=120s"
$v2Image = Invoke-KubectlOutput "get" "deployment" "learnhub-course-helm" "-n" $Namespace "-o" "jsonpath={.spec.template.spec.containers[0].image}"
$v2Replicas = Invoke-KubectlOutput "get" "deployment" "learnhub-course-helm" "-n" $Namespace "-o" "jsonpath={.spec.replicas}"
Write-Host "Upgraded image: $v2Image replicas=$v2Replicas"
Assert-OutputContains -Output $v2Image -Expected "learnhub/course-service:0.1.1" -Context "Lab 5.4 upgraded image"
Assert-OutputContains -Output $v2Replicas -Expected "3" -Context "Lab 5.4 upgraded replicas"

Invoke-Helm "history" $Release "--namespace" $Namespace

Write-Host "Rolling back Helm release to revision 1."
Invoke-Helm "rollback" $Release "1" "--namespace" $Namespace
Invoke-Kubectl "rollout" "status" "deployment/learnhub-course-helm" "-n" $Namespace "--timeout=120s"
$rollbackImage = Invoke-KubectlOutput "get" "deployment" "learnhub-course-helm" "-n" $Namespace "-o" "jsonpath={.spec.template.spec.containers[0].image}"
$rollbackReplicas = Invoke-KubectlOutput "get" "deployment" "learnhub-course-helm" "-n" $Namespace "-o" "jsonpath={.spec.replicas}"
Write-Host "Rollback image: $rollbackImage replicas=$rollbackReplicas"
Assert-OutputContains -Output $rollbackImage -Expected "learnhub/course-service:0.1.0" -Context "Lab 5.4 rollback image"
Assert-OutputContains -Output $rollbackReplicas -Expected "2" -Context "Lab 5.4 rollback replicas"

$rollbackResponse = Invoke-TemporaryCurlOutput -Name "helm-client-rollback" -Namespace $Namespace -Url "http://learnhub-course-helm/api/courses"
$rollbackResponse | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $rollbackResponse -Expected "c-k8s-ckad" -Context "Lab 5.4 rollback smoke test"
