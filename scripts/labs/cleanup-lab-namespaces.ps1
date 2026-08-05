param(
  [switch]$IncludeLearnHub,
  [switch]$Wait,
  [switch]$DryRun,
  [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

$LabNamespaces = @(
  "ckad-lab",
  "label-lab",
  "rollout-lab",
  "bluegreen-lab",
  "scale-lab",
  "kustomize-dev",
  "kustomize-prod",
  "config-lab",
  "security-lab",
  "rbac-lab",
  "quota-lab",
  "service-lab",
  "ingress-lab",
  "networkpolicy-lab",
  "storage-lab",
  "probe-lab",
  "observability-lab",
  "triage-lab",
  "helm-lab"
)

if ($IncludeLearnHub) {
  $LabNamespaces += "learnhub-lab"
}

Assert-KubernetesReady

foreach ($namespace in $LabNamespaces) {
  if (Test-NamespaceExists -Namespace $namespace) {
    if ($DryRun) {
      Write-Host "Would delete namespace: $namespace"
    } else {
      Write-Host "Deleting namespace: $namespace"
      Invoke-Kubectl "delete" "namespace" $namespace "--ignore-not-found" "--wait=false"
    }
  } else {
    Write-Host "Namespace not found: $namespace"
  }
}

if (-not $DryRun -and $Wait) {
  foreach ($namespace in $LabNamespaces) {
    Wait-NamespaceDeleted -Namespace $namespace -TimeoutSeconds $TimeoutSeconds
  }
}

if ($DryRun) {
  Write-Host "Dry run only. No namespace was deleted."
} else {
  Write-Host "Cleanup request submitted."
}

