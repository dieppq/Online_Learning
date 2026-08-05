param(
  [switch]$SkipBuild,
  [switch]$RequireNetworkPolicyEnforcement,
  [int]$NamespaceDeleteTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common.ps1"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $ProjectRoot

function Invoke-ClientCurl {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Pod,

    [Parameter(Mandatory = $true)]
    [string]$Namespace,

    [Parameter(Mandatory = $true)]
    [string]$Url
  )

  $oldErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = kubectl exec "pod/$Pod" "-n" $Namespace "-c" "curl" "--" "curl" "--fail" "--silent" "--show-error" "--connect-timeout" "5" "--max-time" "8" $Url 2>&1
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $oldErrorActionPreference
  }

  return @{
    ExitCode = $exitCode
    Output = $output
  }
}

Write-Host "Lab 4.3 - NetworkPolicy Isolation for LearnHub backend"

Assert-DockerReady
Assert-KubernetesReady

if (-not $SkipBuild) {
  Build-LearnHubImages -Services @("course-service")
} else {
  Assert-DockerImages -Images @("learnhub/course-service:0.1.0")
}

Ensure-DockerImage -Image "curlimages/curl:8.10.1"

$Namespace = "networkpolicy-lab"
$Manifest = "k8s/labs/lab-4.3-networkpolicy-isolation.yaml"

Reset-LabNamespace -Namespace $Namespace -TimeoutSeconds $NamespaceDeleteTimeoutSeconds -LabName "Lab 4.3"

Invoke-Kubectl "apply" "-f" $Manifest
Invoke-Kubectl "rollout" "status" "deployment/learnhub-network-backend" "-n" $Namespace "--timeout=120s"
Invoke-Kubectl "wait" "--for=condition=Ready" "pod/learnhub-network-frontend" "-n" $Namespace "--timeout=120s"
Invoke-Kubectl "wait" "--for=condition=Ready" "pod/learnhub-network-intruder" "-n" $Namespace "--timeout=120s"
Invoke-Kubectl "wait" "--for=condition=Ready" "pod/learnhub-network-backend-debug" "-n" $Namespace "--timeout=120s"
Invoke-Kubectl "get" "networkpolicy,pod,svc" "-n" $Namespace "-o" "wide"

Write-Host "Allowed path: frontend -> backend Service."
$frontendToBackend = Invoke-ClientCurl -Pod "learnhub-network-frontend" -Namespace $Namespace -Url "http://learnhub-network-backend/api/courses"
$frontendToBackend.Output | ForEach-Object { Write-Host $_ }
if ($frontendToBackend.ExitCode -ne 0) {
  throw "Expected frontend to reach backend, but curl failed."
}
Assert-OutputContains -Output $frontendToBackend.Output -Expected "c-k8s-ckad" -Context "Lab 4.3 frontend to backend"

Write-Host "Denied path: intruder -> backend Service."
$backendPodIp = Invoke-KubectlOutput "get" "pod" "-n" $Namespace "-l" "app=learnhub-network-backend" "-o" "jsonpath={.items[0].status.podIP}"
Write-Host "Testing intruder directly against backend Pod IP: http://${backendPodIp}:8080/api/courses"
$intruderToBackend = Invoke-ClientCurl -Pod "learnhub-network-intruder" -Namespace $Namespace -Url "http://${backendPodIp}:8080/api/courses"
if ($intruderToBackend.ExitCode -eq 0) {
  $message = "NetworkPolicy ingress isolation was not enforced: intruder reached backend. Docker Desktop default CNI commonly accepts NetworkPolicy objects but does not enforce them."
  if ($RequireNetworkPolicyEnforcement) {
    throw $message
  }
  Write-Warning $message
} else {
  Write-Host "Intruder could not reach backend, as expected."
  $intruderToBackend.Output | ForEach-Object { Write-Host $_ }
}

Write-Host "Denied path: backend-role debug Pod -> internet."
$backendEgress = Invoke-ClientCurl -Pod "learnhub-network-backend-debug" -Namespace $Namespace -Url "http://1.1.1.1"
if ($backendEgress.ExitCode -eq 0) {
  $message = "NetworkPolicy backend egress deny was not enforced: backend-role Pod reached 1.1.1.1."
  if ($RequireNetworkPolicyEnforcement) {
    throw $message
  }
  Write-Warning $message
} else {
  Write-Host "Backend-role debug Pod could not reach internet endpoint, as expected when policy is enforced."
  $backendEgress.Output | ForEach-Object { Write-Host $_ }
}

Write-Host "Use -RequireNetworkPolicyEnforcement if this lab must fail on clusters whose CNI does not enforce NetworkPolicy."
