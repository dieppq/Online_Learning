param(
  [switch]$SkipBuild,
  [int]$NamespaceDeleteTimeoutSeconds = 90,
  [switch]$CreateLoad,
  [switch]$DeleteLoad,
  [switch]$KeepLoad,
  [switch]$RequireHpaScale,
  [int]$LoadClients = 8,
  [int]$BurnMilliseconds = 750,
  [int]$LoadDurationSeconds = 180
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

$Namespace = "scale-lab"
$Deployment = "learnhub-course-scale"
$LoadDeployment = "learnhub-course-scale-load"
$LoadLabelSelector = "app=learnhub-course-scale-load"
$ScaleTenManifest = "k8s/labs/lab-2.3-scale-deployment-10.yaml"
$ScaleTwoManifest = "k8s/labs/lab-2.3-scale-deployment-2.yaml"
$LoadGeneratorManifest = "k8s/labs/lab-2.3-load-generator.yaml"

function Assert-LoadParameters {
  if ($LoadClients -lt 1 -or $LoadClients -gt 50) {
    throw "-LoadClients must be between 1 and 50."
  }

  if ($BurnMilliseconds -lt 1 -or $BurnMilliseconds -gt 5000) {
    throw "-BurnMilliseconds must be between 1 and 5000."
  }

  if ($LoadDurationSeconds -lt 0) {
    throw "-LoadDurationSeconds must be 0 or greater."
  }
}

function Remove-HpaLoadGenerators {
  if (-not (Test-NamespaceExists -Namespace $Namespace)) {
    Write-Host "Namespace $Namespace does not exist. No load generator Pods to delete."
    return
  }

  Write-Host "Deleting Lab 2.3 load generator Deployment and Pods."
  Invoke-Kubectl "delete" "deployment" $LoadDeployment "-n" $Namespace "--ignore-not-found" "--wait=true"
  Invoke-Kubectl "delete" "pod" "-n" $Namespace "-l" $LoadLabelSelector "--ignore-not-found" "--wait=true"
}

function New-HpaLoadGeneratorManifest {
  param(
    [Parameter(Mandatory = $true)]
    [int]$ClientCount,

    [Parameter(Mandatory = $true)]
    [int]$BurnMs
  )

  if ($ClientCount -eq 8 -and $BurnMs -eq 750) {
    return $LoadGeneratorManifest
  }

  $template = Get-Content -Raw -Path $LoadGeneratorManifest
  $rendered = $template `
    -replace "replicas: 8", "replicas: $ClientCount" `
    -replace 'value: "750"', "value: `"$BurnMs`""

  $tempDir = Join-Path $ProjectRoot ".tmp\lab-2.3"
  $null = New-Item -ItemType Directory -Path $tempDir -Force
  $renderedManifest = Join-Path $tempDir "load-generator.yaml"
  Set-Content -Path $renderedManifest -Value $rendered -Encoding ascii
  return $renderedManifest
}

function Start-HpaLoadGenerators {
  param(
    [Parameter(Mandatory = $true)]
    [int]$ClientCount,

    [Parameter(Mandatory = $true)]
    [int]$BurnMs
  )

  Remove-HpaLoadGenerators

  $manifest = New-HpaLoadGeneratorManifest -ClientCount $ClientCount -BurnMs $BurnMs

  Write-Host "Applying load generator manifest: $manifest"
  Invoke-Kubectl "apply" "-f" $manifest
  Invoke-Kubectl "rollout" "status" "deployment/$LoadDeployment" "-n" $Namespace "--timeout=120s"
  Invoke-Kubectl "wait" "--for=condition=Ready" "pod" "-l" $LoadLabelSelector "-n" $Namespace "--timeout=90s"
  Invoke-Kubectl "get" "pod" "-n" $Namespace "-l" $LoadLabelSelector "-o" "wide"
}

function Get-DeploymentDesiredReplicas {
  $value = Invoke-KubectlOutput "get" "deployment" $Deployment "-n" $Namespace "-o" "jsonpath={.spec.replicas}"
  if ([string]::IsNullOrWhiteSpace($value)) {
    return 0
  }

  return [int]$value
}

function Watch-HpaAndDeployment {
  param(
    [Parameter(Mandatory = $true)]
    [int]$Seconds,

    [Parameter(Mandatory = $true)]
    [int]$InitialReplicas
  )

  $maxReplicas = $InitialReplicas
  $deadline = (Get-Date).AddSeconds($Seconds)

  while ((Get-Date) -lt $deadline) {
    Write-Host ""
    Write-Host "HPA status:"
    $hpaStatus = Invoke-KubectlOutput "get" "hpa" $Deployment "-n" $Namespace
    $hpaStatus | ForEach-Object { Write-Host $_ }

    Write-Host "Deployment status:"
    $deploymentStatus = Invoke-KubectlOutput "get" "deployment" $Deployment "-n" $Namespace
    $deploymentStatus | ForEach-Object { Write-Host $_ }

    $currentReplicas = Get-DeploymentDesiredReplicas
    if ($currentReplicas -gt $maxReplicas) {
      $maxReplicas = $currentReplicas
    }

    $remaining = [int][Math]::Ceiling(($deadline - (Get-Date)).TotalSeconds)
    if ($remaining -le 0) {
      break
    }

    Start-Sleep -Seconds ([Math]::Min(15, $remaining))
  }

  return $maxReplicas
}

Assert-LoadParameters

if ($DeleteLoad -and -not $CreateLoad) {
  Write-Host "Lab 2.3 - delete load generator Pods only"
  Assert-KubernetesReady
  Remove-HpaLoadGenerators
  Invoke-Kubectl "get" "pod" "-n" $Namespace "-l" $LoadLabelSelector "--ignore-not-found"
  return
}

Write-Host "Lab 2.3 - Scale & HPA using learnhub/course-service"

Assert-DockerReady
Assert-KubernetesReady

if (-not $SkipBuild) {
  Build-LearnHubImages -Tags @("0.1.0-cpu") -Services @("course-service")
} else {
  Assert-DockerImages -Images @("learnhub/course-service:0.1.0-cpu")
}

Ensure-DockerImage -Image "curlimages/curl:8.10.1"

$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  $metricsOutput = kubectl top nodes 2>&1
  $metricsExitCode = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $oldErrorActionPreference
}
$metricsReady = ($metricsExitCode -eq 0)
if (-not $metricsReady) {
  Write-Warning "Metrics API is not ready. HPA will be created, but TARGETS may show <unknown> until metrics-server is available."
  $metricsOutput | ForEach-Object { Write-Host $_ }
}

Reset-LabNamespace -Namespace $Namespace -TimeoutSeconds $NamespaceDeleteTimeoutSeconds -LabName "Lab 2.3"

Invoke-Kubectl "apply" "-f" "k8s/labs/lab-2.3-scale-deployment.yaml"
Invoke-Kubectl "rollout" "status" "deployment/$Deployment" "-n" $Namespace "--timeout=120s"

Write-Host "Scaling to 10 replicas."
Invoke-Kubectl "apply" "-f" $ScaleTenManifest
Invoke-Kubectl "rollout" "status" "deployment/$Deployment" "-n" $Namespace "--timeout=120s"
Invoke-Kubectl "get" "deployment" $Deployment "-n" $Namespace
Invoke-Kubectl "get" "pods" "-n" $Namespace "-l" "app=$Deployment"

Write-Host "Creating HPA."
Invoke-Kubectl "apply" "-f" "k8s/labs/lab-2.3-hpa.yaml"
Invoke-Kubectl "get" "hpa" $Deployment "-n" $Namespace
Invoke-Kubectl "describe" "hpa" $Deployment "-n" $Namespace

Write-Host "Calling Service:"
$response = Invoke-TemporaryCurlOutput -Name "hpa-client" -Namespace $Namespace -Url "http://learnhub-course-scale/api/courses"
$response | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $response -Expected "c-k8s-ckad" -Context "Lab 2.3 course-service smoke test"

if ($CreateLoad) {
  Write-Host ""
  Write-Host "Checking CPU burn endpoint before creating load."
  $burnCheck = Invoke-TemporaryCurlOutput -Name "hpa-burn-check" -Namespace $Namespace -Url "http://learnhub-course-scale/cpu-burn?ms=100"
  $burnCheck | ForEach-Object { Write-Host $_ }
  Assert-OutputContains -Output $burnCheck -Expected "burned" -Context "Lab 2.3 cpu-burn endpoint"

  Write-Host "Scaling deployment back to HPA minReplicas=2 before load generation."
  Invoke-Kubectl "apply" "-f" $ScaleTwoManifest
  Invoke-Kubectl "rollout" "status" "deployment/$Deployment" "-n" $Namespace "--timeout=120s"
  $initialReplicas = Get-DeploymentDesiredReplicas
  Write-Host "Initial desired replicas before load: $initialReplicas"

  Start-HpaLoadGenerators -ClientCount $LoadClients -BurnMs $BurnMilliseconds

  if (-not $metricsReady) {
    Write-Warning "Load generator Pods are running, but HPA cannot scale until Metrics API is available."
  }

  $maxReplicas = $initialReplicas
  if ($LoadDurationSeconds -gt 0) {
    Write-Host "Watching HPA and Deployment for $LoadDurationSeconds seconds."
    $maxReplicas = Watch-HpaAndDeployment -Seconds $LoadDurationSeconds -InitialReplicas $initialReplicas
  } else {
    Invoke-Kubectl "get" "hpa" $Deployment "-n" $Namespace
    Invoke-Kubectl "get" "deployment" $Deployment "-n" $Namespace
  }

  if ($RequireHpaScale -and $maxReplicas -le $initialReplicas) {
    throw "HPA did not scale above $initialReplicas replicas. Check Metrics API and generated CPU usage."
  }

  if ($KeepLoad) {
    Write-Host ""
    Write-Host "Load generator Pods were left running."
    Write-Host "Delete them with:"
    Write-Host "powershell -ExecutionPolicy Bypass -File .\scripts\labs\run-lab-2.3.ps1 -DeleteLoad"
  } else {
    Remove-HpaLoadGenerators
  }
}
