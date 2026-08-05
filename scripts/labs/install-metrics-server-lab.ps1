param(
  [switch]$Uninstall,
  [switch]$ForceApply,
  [switch]$SkipTopCheck,
  [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

$ManifestUrl = "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
$PatchFile = Join-Path $ProjectRoot "k8s\labs\metrics-server-docker-desktop-patch.json"
$DeploymentName = "metrics-server"
$Namespace = "kube-system"
$ApiServiceName = "v1beta1.metrics.k8s.io"
$LabPatchArg = "--kubelet-insecure-tls"

function Test-KubernetesResourceExists {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$KubectlArgs
  )

  $output = Invoke-KubectlOutputOrEmpty @KubectlArgs
  return (-not [string]::IsNullOrWhiteSpace($output))
}

function Test-MetricsServerInstalled {
  $deploymentExists = Test-KubernetesResourceExists -KubectlArgs @(
    "get", "deployment", $DeploymentName, "-n", $Namespace, "-o", "name", "--ignore-not-found"
  )
  $apiServiceExists = Test-KubernetesResourceExists -KubectlArgs @(
    "get", "apiservice", $ApiServiceName, "-o", "name", "--ignore-not-found"
  )

  return ($deploymentExists -and $apiServiceExists)
}

function Test-MetricsServerHasLabPatch {
  $argsText = Invoke-KubectlOutputOrEmpty "get" "deployment" $DeploymentName "-n" $Namespace "-o" "jsonpath={.spec.template.spec.containers[0].args[*]}"
  return $argsText.Contains($LabPatchArg)
}

function Invoke-KubectlTopNodesWithRetry {
  param(
    [Parameter(Mandatory = $true)]
    [int]$TimeoutSeconds
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $lastOutput = @()

  while ((Get-Date) -lt $deadline) {
    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
      $lastOutput = kubectl top nodes 2>&1
      $exitCode = $LASTEXITCODE
    } finally {
      $ErrorActionPreference = $oldErrorActionPreference
    }

    if ($exitCode -eq 0) {
      Write-Host "kubectl top nodes:"
      $lastOutput | ForEach-Object { Write-Host $_ }
      return
    }

    Write-Host "Waiting for Metrics API data..."
    Start-Sleep -Seconds 5
  }

  $lastOutput | ForEach-Object { Write-Host $_ }
  throw "kubectl top nodes did not return metrics within $TimeoutSeconds seconds."
}

function Uninstall-MetricsServerForLab {
  Write-Host "Uninstalling Metrics Server lab resources."

  Invoke-Kubectl "delete" "apiservice" $ApiServiceName "--ignore-not-found"
  Invoke-Kubectl "delete" "deployment" $DeploymentName "-n" $Namespace "--ignore-not-found"
  Invoke-Kubectl "delete" "service" $DeploymentName "-n" $Namespace "--ignore-not-found"
  Invoke-Kubectl "delete" "serviceaccount" $DeploymentName "-n" $Namespace "--ignore-not-found"
  Invoke-Kubectl "delete" "rolebinding" "metrics-server-auth-reader" "-n" $Namespace "--ignore-not-found"
  Invoke-Kubectl "delete" "clusterrolebinding" "metrics-server:system:auth-delegator" "system:metrics-server" "--ignore-not-found"
  Invoke-Kubectl "delete" "clusterrole" "system:aggregated-metrics-reader" "system:metrics-server" "--ignore-not-found"

  Write-Host "Metrics Server lab resources removed."
}

Write-Host "Metrics Server lab setup for Docker Desktop Kubernetes"
Write-Host "This script is for local CKAD labs only. It adds $LabPatchArg for Docker Desktop kubelet TLS."

Assert-KubernetesReady

if ($Uninstall) {
  Uninstall-MetricsServerForLab
  return
}

if (-not (Test-Path -LiteralPath $PatchFile)) {
  throw "Patch file not found: $PatchFile"
}

if ($ForceApply -or -not (Test-MetricsServerInstalled)) {
  Write-Host "Applying official Metrics Server manifest."
  Invoke-Kubectl "apply" "-f" $ManifestUrl
} else {
  Write-Host "Metrics Server already has deployment and APIService. Skipping manifest apply."
}

if (Test-MetricsServerHasLabPatch) {
  Write-Host "Metrics Server already has $LabPatchArg."
} else {
  Write-Host "Patching Metrics Server for Docker Desktop kubelet TLS."
  Invoke-Kubectl "patch" "deployment" $DeploymentName "-n" $Namespace "--type" "json" "--patch-file" $PatchFile
}

Invoke-Kubectl "rollout" "status" "deployment/$DeploymentName" "-n" $Namespace "--timeout=$($TimeoutSeconds)s"
Invoke-Kubectl "wait" "--for=condition=Available" "apiservice/$ApiServiceName" "--timeout=$($TimeoutSeconds)s"

Invoke-Kubectl "get" "deployment" $DeploymentName "-n" $Namespace
Invoke-Kubectl "get" "apiservice" $ApiServiceName

if (-not $SkipTopCheck) {
  Invoke-KubectlTopNodesWithRetry -TimeoutSeconds $TimeoutSeconds
}

Write-Host "Metrics API is ready for Lab 2.3 HPA and Lab 5.2 kubectl top."
