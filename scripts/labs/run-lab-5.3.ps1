param(
  [switch]$SkipBuild,
  [int]$NamespaceDeleteTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

function Invoke-KubectlAllowFailure {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgumentList
  )

  $oldErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = kubectl @ArgumentList 2>&1
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $oldErrorActionPreference
  }

  return @{
    ExitCode = $exitCode
    Output = $output
  }
}

function Wait-ContainerWaitingReason {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Namespace,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedReason,

    [int]$TimeoutSeconds = 90
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $reason = Invoke-KubectlOutputOrEmpty "get" "pod" "-n" $Namespace "-l" "app=learnhub-triage-api" "-o" "jsonpath={.items[0].status.containerStatuses[0].state.waiting.reason}"
    if ($reason -eq $ExpectedReason) {
      Write-Host "Container waiting reason: $reason"
      return
    }

    Start-Sleep -Seconds 2
  }

  Invoke-Kubectl "get" "pod" "-n" $Namespace "-o" "wide"
  Invoke-Kubectl "describe" "pod" "-n" $Namespace "-l" "app=learnhub-triage-api"
  throw "Did not observe waiting reason $ExpectedReason within $TimeoutSeconds seconds."
}

function Invoke-TriageClient {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Namespace,

    [Parameter(Mandatory = $true)]
    [string]$Manifest,

    [int]$TimeoutSeconds = 60
  )

  $name = "triage-client"
  Remove-PodIfExists -Name $name -Namespace $Namespace
  Invoke-Kubectl "apply" "-f" $Manifest

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $phase = ""

  while ((Get-Date) -lt $deadline) {
    $phase = Invoke-KubectlOutputOrEmpty "get" "pod" $name "-n" $Namespace "-o" "jsonpath={.status.phase}"
    if ($phase -eq "Succeeded" -or $phase -eq "Failed") {
      break
    }

    Start-Sleep -Seconds 2
  }

  $output = Invoke-KubectlOutputOrEmpty "logs" $name "-n" $Namespace "-c" "curl"
  if ($phase -ne "Succeeded" -and $phase -ne "Failed") {
    Invoke-Kubectl "describe" "pod" $name "-n" $Namespace
    Remove-PodIfExists -Name $name -Namespace $Namespace
    throw "Triage client Pod did not finish within $TimeoutSeconds seconds."
  }

  Remove-PodIfExists -Name $name -Namespace $Namespace

  return @{
    ExitCode = $(if ($phase -eq "Succeeded") { 0 } else { 1 })
    Output = $output
  }
}

Write-Host "Lab 5.3 - Broken YAML Triage"

Assert-DockerReady
Assert-KubernetesReady

if (-not $SkipBuild) {
  Build-LearnHubImages -Services @("course-service")
} else {
  Assert-DockerImages -Images @("learnhub/course-service:0.1.0")
}

Ensure-DockerImage -Image "curlimages/curl:8.10.1"

$Namespace = "triage-lab"
$BrokenSelectorManifest = "k8s/labs/lab-5.3-broken-selector.yaml"
$BrokenRuntimeManifest = "k8s/labs/lab-5.3-broken-runtime.yaml"
$FixImageManifest = "k8s/labs/lab-5.3-fix-image.yaml"
$FixServiceManifest = "k8s/labs/lab-5.3-fix-service-targetport.yaml"
$TriageClientManifest = "k8s/labs/lab-5.3-triage-client.yaml"

Reset-LabNamespace -Namespace $Namespace -TimeoutSeconds $NamespaceDeleteTimeoutSeconds -LabName "Lab 5.3"

Write-Host "Applying Deployment with selector mismatch. This should fail validation."
$selectorFailure = Invoke-KubectlAllowFailure "apply" "-f" $BrokenSelectorManifest
$selectorFailure.Output | ForEach-Object { Write-Host $_ }
if ($selectorFailure.ExitCode -eq 0) {
  throw "Expected selector mismatch manifest to fail, but kubectl apply succeeded."
}
Assert-OutputContains -Output $selectorFailure.Output -Expected "does not match template" -Context "Lab 5.3 selector mismatch"

Write-Host "Applying runtime-broken manifest with invalid image name and Service targetPort mismatch."
Invoke-Kubectl "apply" "-f" $BrokenRuntimeManifest
Wait-ContainerWaitingReason -Namespace $Namespace -ExpectedReason "InvalidImageName" -TimeoutSeconds 90
Invoke-Kubectl "describe" "pod" "-n" $Namespace "-l" "app=learnhub-triage-api"

Write-Host "Fixing invalid image name by applying corrected Deployment YAML."
Invoke-Kubectl "apply" "-f" $FixImageManifest
Invoke-Kubectl "rollout" "status" "deployment/learnhub-triage-api" "-n" $Namespace "--timeout=120s"

Write-Host "Service targetPort is still wrong, so calling through Service should fail."
$serviceFailure = Invoke-TriageClient -Namespace $Namespace -Manifest $TriageClientManifest
$serviceFailure.Output | ForEach-Object { Write-Host $_ }
if ($serviceFailure.ExitCode -eq 0) {
  throw "Expected Service call to fail before targetPort fix, but it succeeded."
}

Write-Host "Fixing Service targetPort by applying corrected Service YAML."
Invoke-Kubectl "apply" "-f" $FixServiceManifest
Invoke-Kubectl "get" "svc,endpoints" "-n" $Namespace

Write-Host "Calling Service after all fixes:"
$serviceSuccess = Invoke-TriageClient -Namespace $Namespace -Manifest $TriageClientManifest
$response = $serviceSuccess.Output
$response | ForEach-Object { Write-Host $_ }
if ($serviceSuccess.ExitCode -ne 0) {
  throw "Expected Service call to succeed after targetPort fix, but it failed."
}
Assert-OutputContains -Output $response -Expected "c-k8s-ckad" -Context "Lab 5.3 fixed service smoke test"
