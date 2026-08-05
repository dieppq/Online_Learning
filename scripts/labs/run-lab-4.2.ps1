param(
  [switch]$SkipBuild,
  [int]$NamespaceDeleteTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

function Invoke-IngressCurlOutput {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$Namespace,

    [Parameter(Mandatory = $true)]
    [string]$Url,

    [string]$HostHeader = "learnhub.local"
  )

  Invoke-TemporaryCurlOutput -Name $Name -Namespace $Namespace -Url $Url -Headers @("Host: $HostHeader")
}

function Get-IngressControllerUrl {
  $candidates = @(
    @("ingress-nginx", "ingress-nginx-controller"),
    @("ingress-nginx", "controller"),
    @("nginx-ingress", "nginx-ingress-controller")
  )

  foreach ($candidate in $candidates) {
    $namespace = $candidate[0]
    $service = $candidate[1]
    $serviceName = Invoke-KubectlOutputOrEmpty "get" "service" $service "-n" $namespace "-o" "name"
    if (-not [string]::IsNullOrWhiteSpace($serviceName)) {
      return "http://$service.$namespace.svc.cluster.local"
    }
  }

  return ""
}

Write-Host "Lab 4.2 - Ingress Routing for LearnHub frontend and backend"

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

$Namespace = "ingress-lab"
$IngressManifest = "k8s/labs/lab-4.2-ingress-routing.yaml"
$LocalEndpointManifest = "k8s/labs/lab-4.2-local-ingress-endpoint.yaml"

Reset-LabNamespace -Namespace $Namespace -TimeoutSeconds $NamespaceDeleteTimeoutSeconds -LabName "Lab 4.2"

Invoke-Kubectl "apply" "-f" $IngressManifest
Invoke-Kubectl "rollout" "status" "deployment/learnhub-ingress-frontend" "-n" $Namespace "--timeout=120s"
Invoke-Kubectl "rollout" "status" "deployment/learnhub-ingress-backend" "-n" $Namespace "--timeout=120s"
Invoke-Kubectl "get" "ingress,svc,deploy,pod" "-n" $Namespace "-o" "wide"

$controllerUrl = Get-IngressControllerUrl
if ([string]::IsNullOrWhiteSpace($controllerUrl)) {
  Write-Warning "No cluster ingress-nginx controller service was found. Deploying a local NGINX endpoint that mirrors the Ingress rules for Docker Desktop verification."
  Ensure-DockerImage -Image "nginx:1.27-alpine"
  Invoke-Kubectl "apply" "-f" $LocalEndpointManifest
  Invoke-Kubectl "rollout" "status" "deployment/learnhub-local-ingress" "-n" $Namespace "--timeout=120s"
  $controllerUrl = "http://learnhub-local-ingress.$Namespace.svc.cluster.local"
}

Write-Host "Verifying through ingress endpoint: $controllerUrl"
$frontendResponse = Invoke-IngressCurlOutput -Name "ingress-frontend-client" -Namespace $Namespace -Url "$controllerUrl/"
$frontendResponse | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $frontendResponse -Expected "user-service-ingress" -Context "Lab 4.2 frontend ingress route"

$backendResponse = Invoke-IngressCurlOutput -Name "ingress-backend-client" -Namespace $Namespace -Url "$controllerUrl/api/courses"
$backendResponse | ForEach-Object { Write-Host $_ }
Assert-OutputContains -Output $backendResponse -Expected "c-k8s-ckad" -Context "Lab 4.2 backend ingress route"
