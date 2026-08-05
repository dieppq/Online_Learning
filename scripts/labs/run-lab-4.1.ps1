param(
  [switch]$SkipBuild,
  [int]$NamespaceDeleteTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

function Wait-ServiceEndpoint {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Service,

    [Parameter(Mandatory = $true)]
    [string]$Namespace,

    [int]$TimeoutSeconds = 60
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $endpointIps = Invoke-KubectlOutputOrEmpty "get" "endpoints" $Service "-n" $Namespace "-o" "jsonpath={.subsets[*].addresses[*].ip}"
    if (-not [string]::IsNullOrWhiteSpace($endpointIps)) {
      return $endpointIps
    }

    Start-Sleep -Seconds 2
  }

  throw "Service $Service in namespace $Namespace did not get endpoints within $TimeoutSeconds seconds."
}

Write-Host "Lab 4.1 - ClusterIP & NodePort with selector mismatch debug"

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

Ensure-DockerImage -Image "curlimages/curl:8.10.1"

$Namespace = "service-lab"
$Manifest = "k8s/labs/lab-4.1-clusterip-nodeport.yaml"
$FixedBackendServiceManifest = "k8s/labs/lab-4.1-backend-service-fixed.yaml"

Reset-LabNamespace -Namespace $Namespace -TimeoutSeconds $NamespaceDeleteTimeoutSeconds -LabName "Lab 4.1"

Invoke-Kubectl "apply" "-f" $Manifest
Invoke-Kubectl "rollout" "status" "deployment/learnhub-course-backend" "-n" $Namespace "--timeout=120s"
Invoke-Kubectl "rollout" "status" "deployment/learnhub-user-frontend" "-n" $Namespace "--timeout=120s"

Invoke-Kubectl "get" "deploy,svc,pod" "-n" $Namespace "-o" "wide"

Write-Host "Diagnosing backend ClusterIP Service selector mismatch."
$initialEndpointIps = Invoke-KubectlOutputOrEmpty "get" "endpoints" "learnhub-course-backend" "-n" $Namespace "-o" "jsonpath={.subsets[*].addresses[*].ip}"
if (-not [string]::IsNullOrWhiteSpace($initialEndpointIps)) {
  throw "Expected learnhub-course-backend to have no endpoints before selector fix, but got: $initialEndpointIps"
}
Write-Host "As expected, learnhub-course-backend has no endpoints before selector fix."
Invoke-Kubectl "describe" "service" "learnhub-course-backend" "-n" $Namespace

Write-Host "Applying fixed Service YAML so selector matches backend Pod labels."
Invoke-Kubectl "apply" "-f" $FixedBackendServiceManifest
$fixedEndpointIps = Wait-ServiceEndpoint -Service "learnhub-course-backend" -Namespace $Namespace -TimeoutSeconds 60
Write-Host "Backend endpoint IPs after fix: $fixedEndpointIps"
Invoke-Kubectl "get" "endpoints" "learnhub-course-backend" "learnhub-user-frontend" "-n" $Namespace

Write-Host "Calling backend ClusterIP Service:"
$backendResponse = Invoke-TemporaryCurlOutput -Name "service-backend-client" -Namespace $Namespace -Url "http://learnhub-course-backend/api/courses"
$backendResponse | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $backendResponse -Expected "c-k8s-ckad" -Context "Lab 4.1 backend ClusterIP smoke test"

$nodePort = Invoke-KubectlOutput "get" "service" "learnhub-user-frontend" "-n" $Namespace "-o" "jsonpath={.spec.ports[0].nodePort}"
$nodeIp = Invoke-KubectlOutput "get" "nodes" "-o" "jsonpath={.items[0].status.addresses[?(@.type=='InternalIP')].address}"
Write-Host "NodePort frontend endpoint from inside cluster: http://${nodeIp}:${nodePort}/api/users"
$frontendResponse = Invoke-TemporaryCurlOutput -Name "service-nodeport-client" -Namespace $Namespace -Url "http://${nodeIp}:${nodePort}/api/users"
$frontendResponse | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $frontendResponse -Expected "u-1001" -Context "Lab 4.1 frontend NodePort smoke test"
